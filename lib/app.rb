class App
  class << self
    def run
      Config.load

      @prompt = TTY::Prompt.new
      @prompt.on(:keypress) do |event|
        if event.value == "j"
          @prompt.trigger(:keydown)
        end

        if event.value == "k"
          @prompt.trigger(:keyup)
        end
      end


      boards_loop do |board|
        lists_loop(board) do |list, name|
          cards_loop(list, name) do |card, name|
            card_actions_loop(card, name)
          end
        end
      end
    rescue TTY::Reader::InputInterrupt
    end

    private

    def boards_loop
      loop do
        system("clear")
        board  = @prompt.select("Which board do you want to work with?", boards)
        if board == 'exit'
          system("clear")
          break
        else
          @members = Trello.members(board['id'])
          @labels = Trello.labels(board['id']).select{ |label| !label["name"].empty? }
          yield board
        end
      end
    end

    def boards
      @boards ||= begin
                    boards = { "\033[1;36mExit\033[0m" => 'exit' }
                    boards.merge!(Trello.boards.map do |board|
                      [board['name'], board]
                    end.to_h)
                    boards
                  end
    end

    def lists_loop(board)
      loop do
        system("clear")
        name = board["name"]
        puts breadcrumbs(name)

        list = @prompt.select("Which list do you want to work with?", lists(board['id']))
        if list == 'back'
          break
        else
          yield list, name
        end
      end
    end

    def lists(board)
      lists = { "\033[1;36mBack\033[0m" => 'back' }
      lists.merge!(Trello.lists(board).map do |list|
        [list['name'], list]
      end.to_h)
      lists
    end

    def cards_prompt
      @cards_prompt ||= begin
                          prompt = TTY::Prompt.new
                          prompt.on(:keypress) do |event|
                            if event.value == "j"
                              prompt.trigger(:keydown)
                            end

                            if event.value == "k"
                              prompt.trigger(:keyup)
                            end

                            if event.value == "u"
                              @moved_direction = :up
                              prompt.trigger(:keyenter)
                            end

                            if event.value == "d"
                              @moved_direction = :down
                              prompt.trigger(:keyenter)
                            end
                          end
                          prompt
                        end
    end

    def cards_options(moved)
      disabled = moved ? nil : "(order not changed)"
      [
        { name: "\033[1;36mBack\033[0m", value: 'back' },
        { name: "\033[1;32mNew\033[0m", value: 'new' },
        { name: "\033[1;37mSave Card Order\033[0m", value: 'save_order', disabled: disabled }
      ]
    end

    def cards_loop(list, name)
      @moved_direction = nil
      moved_name       = nil
      moved_changed    = false
      _cards           = []

      loop do
        system("clear")
        _name = "#{name} >> #{list["name"]}"
        puts breadcrumbs(_name)

        unless moved_changed
          _cards = cards(list['id'])
        end
        card_choices = cards_options(moved_changed).concat(_cards)
        card = cards_prompt.select("Which card do you want to work with?",
                              card_choices,
                              per_page: TTY::Screen.rows - 3,
                              default: moved_name)

        case
        when @moved_direction == :up || @moved_direction == :down
          next if %w(back new save_order).include?(card)
          moved_name = card_name(card)
          card_index = _cards.index{|_card| _card[:value]['id'] == card['id']}

          pos = if @moved_direction == :up
                  next if card_index == 0
                  if card_index == 1
                    'top'
                  else
                    (_cards[card_index - 1][:value]["pos"].to_f + _cards[card_index - 2][:value]["pos"].to_f) / 2.0
                  end
                else
                  next if card_index == _cards.size - 1
                  if card_index == _cards.size - 2
                    'bottom'
                  else
                    (_cards[card_index + 1][:value]["pos"].to_f + _cards[card_index + 2][:value]["pos"].to_f) / 2.0
                  end
                end
          _cards[card_index][:value]["pos"] = pos
          _cards[card_index][:value]["pos_changed"] = true
          _cards = _cards.sort_by{|_card| _card[:value]["pos"].to_f}

          @moved_direction = nil
          moved_changed = true
        when card == 'back'
          break
        when card == 'save_order'
          _cards.each do |_card|
            if _card[:value]["pos_changed"]
              Trello.update_card(_card[:value]['id'], pos: _card[:value]['pos'])
            end
          end
          moved_name = nil
          moved_changed = false
        when card == 'new'
          moved_name = nil
          moved_changed = false
          new_card(list)
        else
          moved_name = nil
          moved_changed = false
          yield card, _name
        end
      end
    end

    def cards(list)
      Trello.cards(list).map do |card|
        { name: card_name(card), value: card }
      end
    end

    def new_card(list)
      system("clear")

      name = @prompt.ask("Name:", required: true)

      labels = @labels.map{|label| [label["name"], label["id"]]}.to_h
      idLabels =  if labels.empty?
                    []
                  else
                    @prompt.multi_select("Labels:", labels)
                  end


      desc = nil
      if @prompt.yes?("Add a note?")
        desc = edit_note("")
      end

      Trello.create_card name: name, idList: list["id"], idLabels: idLabels, desc: desc, pos: "top"
    end

    def card_name(card)
      suffix = card_name_suffix(card)
      names = card["idMembers"].map{|mid| @members.find{|member| member["id"] == mid}["fullName"]}.join(", ")
      notes = if card['desc'].strip.empty?
                ""
              else
                "📝 "
              end
      "#{suffix}#{card['name']} #{notes}#{"- #{names}" unless names.empty?}"
    end

    def card_name_suffix(card)
      return "" if Config.story_point_plugin_id.nil?

      data = card["pluginData"].find{|pd| pd["idPlugin"] == Config.story_point_plugin_id}&.dig("value")
      sufix = if data
                data = JSON.parse(data)
                "[#{data["points"]}sp] "
              else
                "[---] "
              end

      if card["idLabels"].instance_of?(Array) && card["idLabels"].any?
        sufix << "[#{card["idLabels"].map{|id| @labels.find{|label| label["id"] == id}["name"]}.join(", ")}] "
      end
    end

    def card_actions_loop(card, name)
      loop do
        system("clear")
        _name = "#{name} >> #{card_name(card)}"
        puts breadcrumbs(_name)

        card_actions = {
          "\033[1;36mBack\033[0m" => 'back',
          'Rename' => 'rename',
          'Notes' => 'notes'
        }
        unless @labels.empty?
          card_actions['Labels'] = 'labels'
        end
        if @members.count > 1
          card_actions['Assigned To'] = 'assigned'
        end
        card_actions.merge!({
          'Move' => 'move',
          "\033[1;31mDelete\033[0m" => 'delete'
        })

        case @prompt.select("What do you want to do with the card?", card_actions, per_page: 7)
        when "rename"
          name = @prompt.ask("What is the new name?", value: card["name"])

          if name != card["name"]
            Trello.update_card(card["id"], name: name)
            card["name"] = name
          end
        when "notes"
          desc = edit_note(card["desc"])
          if desc != card["desc"]
            Trello.update_card(card["id"], desc: desc)
            card["desc"] = desc
          end
        when "labels"
          labels = @labels.map{|label| [label["name"], label["id"]]}.to_h
          defaultLabels = card["idLabels"].map{|id| @labels.find{|label| label["id"] == id}["name"]}
          idLabels = @prompt.multi_select("Set labels for card:", labels, default: defaultLabels)

          unless idLabels.sort == card["idLabels"].sort
            if idLabels.empty?
              Trello.update_card(card["id"], idLabels: "EMPTY")
            else
              Trello.update_card(card["id"], idLabels: idLabels)
            end
            card["idLabels"] = idLabels
          end
        when "assigned"
          members = @members.map{|member| [member["fullName"], member["id"]]}.to_h
          defaultMembers = card["idMembers"].map{|id| @members.find{|member| member["id"] == id}["fullName"]}
          idMembers = @prompt.multi_select("Set members assigned to this card:", members, default: defaultMembers)

          unless idMembers.sort == card["idMembers"].sort
            if idMembers.empty?
              Trello.update_card(card["id"], idMembers: "EMPTY")
            else
              Trello.update_card(card["id"], idMembers: idMembers)
            end
            card["idMembers"] = idMembers
          end
        when "move"
          list = @prompt.select("Which list do you want to move the card to?", lists(card['idBoard']))
          unless list == 'back'
            Trello.update_card(card["id"], idList: list)
            break
          end
        when "delete"
          if @prompt.yes?("Do you want to delete this card?")
            Trello.delete_card(card["id"])
            break
          end
        else
          break
        end
      end
    end

    def breadcrumbs(text)
      "\033[1;34m#{text}\033[0m"
    end

    def edit_note(text)
      path = File.join(File.expand_path("~"), ".trello_desc.tmp")
      delete_file(path)

      status = TTY::Editor.open(path, text: text)
      desc = File.read(path)
      delete_file(path)
      desc
    end

    def delete_file(path)
      File.delete(path) if File.exist?(path)
    end
  end
end
