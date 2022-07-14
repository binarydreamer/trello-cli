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
          @labels = Trello.labels(board['id'])
          yield board
        end
      end
    end

    def boards
      @boards ||= begin
                    boards = { "\033[1;31mExit\033[0m" => 'exit' }
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
      lists = { "\033[1;31mBack\033[0m" => 'back' }
      lists.merge!(Trello.lists(board).map do |list|
        [list['name'], list]
      end.to_h)
      lists
    end

    def cards_loop(list, name)
      loop do
        system("clear")
        _name = "#{name} >> #{list["name"]}"
        puts breadcrumbs(_name)

        card = @prompt.select("Which card do you want to work with?",
                              cards(list['id']),
                              per_page: TTY::Screen.rows - 3)
        case card
        when 'back'
          break
        when 'new'
          new_card(list)
        else
          yield card, _name
        end
      end
    end

    def cards(list)
      cards = {
        "\033[1;31mBack\033[0m" => 'back',
        "\033[1;32mNew\033[0m" => 'new'
      }
      cards.merge!(Trello.cards(list).map do |card|
        [card_name(card), card]
      end.to_h)
      cards
    end

    def new_card(list)
      system("clear")

      name = @prompt.ask("Name:", required: true)

      labels = @labels.map{|label| [label["name"], label["id"]]}.to_h
      idLabels = @prompt.multi_select("Labels:", labels)

      Trello.create_card name, list["id"], idLabels
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

        case @prompt.select("What do you want to do with the card?",
                            %w(Back Change\ Name Notes Labels Assigned\ To Move))
        when "Change Name"
          name = @prompt.ask("What is the new name?", value: card["name"])

          if name != card["name"]
            Trello.update_card(card["id"], name: name)
            card["name"] = name
          end
        when "Notes"
          path = File.join(File.expand_path("~"), ".trello_desc.tmp")
          delete_file(path)

          status = TTY::Editor.open(path, text: card["desc"])
          desc = File.read(path)
          delete_file(path)

          if desc != card["desc"]
            Trello.update_card(card["id"], desc: desc)
            card["desc"] = desc
          end
        when "Labels"
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
        when "Assigned To"
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
        when "Move"
          list = @prompt.select("Which list do you want to move the card to?", lists(card['idBoard']))
          unless list == 'back'
            Trello.update_card(card["id"], idList: list)
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

    def delete_file(path)
      File.delete(path) if File.exist?(path)
    end
  end
end
