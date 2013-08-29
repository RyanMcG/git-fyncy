require "git-fyncy/version"
require 'listen'

module GitFyncy
  def self.slashify(path)
    path[-1] == '/' ? path : path + '/'
  end

  class Remote
    def initialize(remote, path)
      @remote = remote
      @path = GitFyncy.slashify path
    end

    def command(cmd)
      puts cmd.length < 80 ? cmd : cmd[0...77] + '...'
      system cmd
    end

    def scp(paths)
      return if paths.empty?
      command "rsync -zpR #{paths.to_a.join ' '} #{@remote}:#{@path}"
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
    puts error
    exit 1
  end

  def self.main(remote, path, working_dir=nil)
    working_dir ||= Dir.pwd
    Dir.chdir working_dir
    pexit 'A remote and path must be specified' unless remote && path
    remote = Remote.new remote, path
    remote.scp git_aware_files
    relpath = method :relative_path

    puts "GIT FYNCY #{Time.now.ctime}"
    files_to_remove = Set.new
    begin
      pid = nil
      Listen.to!('.') do |modified, added, removed|
        if pid != Process.id
          pid = Process.id
          puts "pid: #{pid}"
        end

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
