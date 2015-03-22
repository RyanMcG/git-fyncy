module GitFyncy
  class Logger
    def initialize(background)
      @log = !(STDOUT.tty? && background)
    end

    def log(thing)
      puts thing if @log
    end
  end
end
