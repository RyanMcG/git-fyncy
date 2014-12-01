require 'git-fyncy/utils'

module GitFyncy
  module Repo
    extend Utils
    GIT_CONFIG_NAME = "fyncy.remote"
    DEFAULT_REMOTE = "origin".freeze


    def self.get_stdout_str(cmd)
      out = `#{cmd}`.chomp
      out.empty? ? nil : out
    end

    def self.fyncy_remote_name_from_config
      get_stdout_str "git config --get #{GIT_CONFIG_NAME}"
    end

    def self.configure_fyncy_remote(remote_name)
      system "git config --add #{GIT_CONFIG_NAME} '#{remote_name}'"
    end

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

    SSH_URL_REGEX = %r{ssh://(\w+@)?([\w\.]+)(:\d+)?([/\w\.]*)$}.freeze
    SCP_REGEX = /^(\w+@)?([\.\w]+):(.*)$/.freeze

    def self.host_and_path_for_remote(remote_name)
      url = lookup_remote_url remote_name
      return unless url

      md = SSH_URL_REGEX.match url
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
        unless md
          pexit "Could not determine host and path from url (#{url}). To work with git-fyncy, the remote's url should be an ssh (i.e. start with \"ssh://\") or scp (i.e. USER@HOST:PATH) style url."
        end
        user = md[1]
        host = md[2]
        path = slashify remove_trailing_git md[3]
      end

      ["#{user}#{host}", path]
    end

    def self.prompt_user_for_remote_name
      print "No remote specified for git fyncy. Enter the name of the remote to use (or press return to use the default, #{DEFAULT_REMOTE}):"
      remote_name = gets.chomp
      remote_name = DEFAULT_REMOTE if remote_name.empty?
      if remote_defined?(remote_name)
        puts
      else
        pexit "A remote by the name of #{remote_name} is not defined in this repo."
      end

      if configure_fyncy_remote remote_name
        remote_name
      else
        pexit "Failed to set #{GIT_CONFIG_NAME} to #{remote_name}. Perhaps there was a permissions error?"
      end
    end

    def self.host_and_path_from_current_repo
      # Determine remote fyncy should use
      remote_name = fyncy_remote_name_from_config
      remote_name = prompt_user_for_remote_name unless remote_name
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
