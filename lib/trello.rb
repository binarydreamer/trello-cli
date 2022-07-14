class Trello
  class << self
    def me
      get 'https://api.trello.com/1/members/me'
    end

    def boards
      get 'https://api.trello.com/1/members/me/boards'
    end

    def members(board)
      get "https://api.trello.com/1/boards/#{board}/members"
    end

    def lists(board)
      get "https://api.trello.com/1/boards/#{board}/lists"
    end

    def cards(list)
      get "https://api.trello.com/1/lists/#{list}/cards?pluginData=true"
    end

    def update_card_name(id, name)
      query = URI.encode_www_form(name: name)
      update "https://api.trello.com/1/cards/#{id}?#{query}"
    end

    def update_card_desc(id, desc)
      query = URI.encode_www_form(desc: desc)
      update "https://api.trello.com/1/cards/#{id}?#{query}"
    end

    def update_card_list(id, list)
      query = URI.encode_www_form(idList: list)
      update "https://api.trello.com/1/cards/#{id}?#{query}"
    end

    private

    def update(url)
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Put.new uri
        request['Authorization'] = "OAuth oauth_consumer_key=\"#{Config.key}\", oauth_token=\"#{Config.token}\""
        response = http.request request
        JSON.parse(response.body)
      end
    end

    def get(url)
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new uri
        request['Authorization'] = "OAuth oauth_consumer_key=\"#{Config.key}\", oauth_token=\"#{Config.token}\""
        response = http.request request
        JSON.parse(response.body)
      end
    end
  end
end
