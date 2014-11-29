require "git-fyncy/version"
require 'listen'

module GitFyncy
  GIT_CONFIG_NAME = "fyncy.remote"
  DEFAULT_REMOTE = "origin".freeze

  def self.slashify(path)
    path[-1] == '/' ? path : path + '/'
  end

  class Remote
    def initialize(remote, path, rsync_args)
      @remote = remote
      @path = GitFyncy.slashify path
      @rsync_flags = rsync_args.join(" ")
    end


    def command(cmd)
      puts cmd.length < 80 ? cmd : cmd[0...77] + '...'
      system cmd
    end

    def scp(paths, rsync_args=[])
      return if paths.empty?
      command "rsync -zpR --checksum #{@rsync_flags} #{paths.to_a.join ' '} #{@remote}:#{@path}"
    end

    def ssh_rm(paths)
      return if paths.empty?
      command "ssh #{@remote} 'cd #{@path}; rm -f #{paths.to_a.join ' '}'"
    end
  end

  def self.relative_path(path)
    path.slice! GitFyncy.slashify(Dir.pwd)
    path
  end

  def self.git_aware_files
    `git ls-files -cmo --exclude-standard`.split("\n")
  end

  def self.pexit(error)
    STDERR.puts error
    exit 1
  end
  private_class_method :pexit

  def self.get_stdout_str(cmd)
    out = `#{cmd}`.chomp
    out.empty? ? nil : out
  end
  private_class_method :get_stdout_str

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

  TRAILING_GIT_REGEX = %r{^(.*)(s\.git/?$)}.freeze
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

  def self.main(*extra_rsync_args)
    working_dir ||= Dir.pwd
    Dir.chdir working_dir
    remote, path = host_and_path_from_current_repo
    pexit 'A remote and path must be specified' unless remote && path
    remote = Remote.new remote, path, extra_rsync_args
    unless remote.scp git_aware_files
      pexit "\nGIT FYNCY: First remote command failed, exiting"
    end
    puts "GIT FYNCY: Listening @ #{Time.now.ctime}"
    listen(remote)
  end

  def self.listen(remote)
    relpath = method :relative_path
    files_to_remove = Set.new
    begin
      Listen.to!('.') do |modified, added, removed|
        begin
          remote.scp git_aware_files
          rel_removed = removed.map(&relpath)
          files_to_remove.merge rel_removed
          files_to_remove.clear if remote.ssh_rm files_to_remove
        rescue => e
          puts e.inspect
        end
      end
    rescue SignalException
      exit 42
    ensure
      puts "\n"
    end
  end
end
