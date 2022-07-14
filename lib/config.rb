class Config
  class << self
    def load
      @config = YAML.safe_load(File.read(
                                File.expand_path(
                                  File.join("~", ".trello.yaml")
                                )
                             ))

      unless @config.instance_of?(Hash)
        raise "Config must be of type hash"
      end
    end

    ["key", "token"].each do |property|
      define_method(property) do
        unless @config[property].instance_of?(String)
          raise "Config '#{property}' is not set"
        end
        @config[property]
      end
    end

    def me
      @config["me"] ||= Trello.me["id"]
    end

    def story_point_plugin_id
      @config["story_point_plugin_id"]
    end
  end
end

