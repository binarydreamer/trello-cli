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
      request :put, URI(url)
    end

    def get(url)
      request :get, URI(url)
    end

    def request(method, uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        req = case method
              when :get
                Net::HTTP::Get.new uri
              when :put
                Net::HTTP::Put.new uri
              else
                raise "Unknown method for trello api"
              end
        req['Authorization'] = authorization
        response = http.request req
        JSON.parse(response.body)
      end
    end

    def authorization
      @authorization ||= "OAuth oauth_consumer_key=\"#{Config.key}\", oauth_token=\"#{Config.token}\""
    end
  end
end
