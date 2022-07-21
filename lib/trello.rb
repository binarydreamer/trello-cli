class Trello
  HOST = 'https://api.trello.com/1/'

  class << self
    def me
      get 'members/me'
    end

    def boards
      get 'members/me/boards'
    end

    def members(board)
      get "boards/#{board}/members"
    end

    def lists(board)
      get "boards/#{board}/lists"
    end

    def labels(board)
      get "boards/#{board}/labels"
    end

    def cards(list)
      get "lists/#{list}/cards?pluginData=true"
    end

    def create_card(options)
      query = URI.encode_www_form(options)
      post "cards?#{query}"
    end

    def update_card(id, options)
      query = URI.encode_www_form(options)
      query.gsub! "EMPTY", ""
      update "cards/#{id}?#{query}"
    end

    def delete_card(id)
      delete "cards/#{id}"
    end

    private

    def update(url)
      request :put, request_uri(url)
    end

    def get(url)
      request :get, request_uri(url)
    end

    def post(url)
      request :post, request_uri(url)
    end

    def delete(url)
      request :delete, request_uri(url)
    end

    def request_uri(url)
      URI(HOST + url)
    end

    def request(method, uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        req = case method
              when :get
                Net::HTTP::Get.new uri
              when :put
                Net::HTTP::Put.new uri
              when :post
                Net::HTTP::Post.new uri
              when :delete
                Net::HTTP::Delete.new uri
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
