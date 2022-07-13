class Trello
  class << self
    def me
      get 'https://api.trello.com/1/members/me'
    end

    private

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
