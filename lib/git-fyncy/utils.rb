module GitFyncy
  module Utils
    def slashify(path)
      path[-1] == '/' ? path : path + '/'
    end

    def pexit(error)
      STDERR.puts error
      exit 1
    end
  end
end
