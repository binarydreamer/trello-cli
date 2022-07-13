class App
  class << self
    def run
      Config.load
      puts Config.me
    end
  end
end
