require 'git-fyncy/utils'

module GitFyncy
  module Repo
    extend Utils
    GIT_CONFIG = {
      remote_name: "fyncy.remote".freeze,
      url: "fyncy.url".freeze
    }.freeze
    DEFAULT_REMOTE = "origin".freeze

    def self.get_stdout_str(cmd)
      out = `#{cmd}`.chomp
      out.empty? ? nil : out
    end

    module ClassMethods
      GIT_CONFIG.each do |name, key|
        define_method("#{name}_from_config") do
          get_stdout_str "git config --get #{key}"
        end

        define_method("configure_fyncy_#{name}") do |val|
          system "git config --add #{key} '#{val}'"
        end
      end
    end
    extend ClassMethods

    def self.lookup_remote_url(remote_name)
      get_stdout_str "git config --get remote.#{remote_name}.url"
    end

    def self.remote_defined?(remote_name)
      system "git config --get remote.#{remote_name}.url"
    end

    TRAILING_GIT_REGEX = %r{^(.*)(\.git/?$)}.freeze
    def self.remove_trailing_git(str)
      md = TRAILING_GIT_REGEX.match str
      md ? md[1] : str
    end

    SSH_URL_REGEX = %r{ssh://(\w+@)?([-_\w\.]+)(:\d+)?([/\w\.]*)$}.freeze
    SCP_REGEX = /^(\w+@)?([-_\.\w]+):(.*)$/.freeze

    def self.host_and_path_from_url(url)
      md = SSH_URL_REGEX.match url
      user = nil
      host = nil
      remote = nil
      path = url

      if md
        user = md[1]
        host = md[2]
        port = md[3]
        if port && port[1..-1].to_i != 22
          STDERR.puts "WARNING: git-fyncy does not currently support port numbers in remote names. Yeah, it is lame. Sorry. Please contribute to fix this!"
        end
        path = md[4]
      else
        md = SCP_REGEX.match url
        if md
          user = md[1]
          host = md[2]
          path = slashify remove_trailing_git md[3]
        end
      end

      remote = "#{user}#{host}" if host
      [remote, path]
    end

    def self.host_and_path_for_remote(remote_name)
      url = lookup_remote_url remote_name
      return unless url
      host_and_path_from_url url
    end

    def self.prompt_user_for_remote_name
      prompt = <<-EOS
No remote configured. git fyncy looks under the fyncy section of your git
config for a remote name or a url (i.e. at fyncy.remote and fyncy.url). If a
remote name is specified, that remote's url will be used with the ".git" suffix
removed if it exists.

Enter a remote name to use (or press return to use #{DEFAULT_REMOTE}): 
EOS
      print prompt.chomp

      remote_name = STDIN.gets.chomp
      remote_name = DEFAULT_REMOTE if remote_name.empty?
      if remote_defined?(remote_name)
        puts
      else
        pexit "A remote by the name of \"#{remote_name}\" is not defined in this repo."
      end

      if configure_fyncy_remote_name remote_name
        remote_name
      else
        pexit "Failed to set #{GIT_CONFIG.fetch(:remote_name)} to #{remote_name}."
      end
    end

    def self.host_and_path_from_current_repo
      # Determine remote fyncy should use
      url = url_from_config
      return host_and_path_from_url url if url

      remote_name = remote_name_from_config
      remote_name = prompt_user_for_remote_name if STDIN.tty? && !remote_name
      res = nil
      res = host_and_path_for_remote remote_name if remote_name
      res = host_and_path_for_remote DEFAULT_REMOTE unless res
      res
    end

    def self.git_aware_files
      `git ls-files -cmo --exclude-standard`.split("\n")
    end
  end
end
