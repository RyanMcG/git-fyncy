require "git-fyncy/version"
require 'listen'

module GitFyncy
  def self.slashify(path)
    path[-1] == '/' ? path : path + '/'
  end

  RELATIVE_PATH = slashify `pwd`.rstrip

  class Remote
    def initialize(remote, path)
      @remote = remote
      @path = GitFyncy.slashify path
    end

    def command(cmd)
      puts cmd
      system cmd
    end

    def scp(paths)
      return if paths.empty?
      command "rsync -zR #{paths.to_a.join ' '} #{@remote}:#{@path}"
    end

    def ssh_rm(paths)
      return if paths.empty?
      command "ssh #{@remote} 'cd #{@path}; rm -f #{paths.to_a.join ' '}'"
    end
  end

  def self.relative_path(path)
    path.slice! RELATIVE_PATH
    path
  end

  def self.git_aware_files
    `git ls-files -mo --exclude-standard`.split("\n")
  end

  def self.git_aware_of_path?(path)
    self.git_aware_files.include? path
  end

  def self.pexit(error)
    puts error
    exit 1
  end

  def self.main(remote, path)
    pexit 'A remote and path must be specified' unless remote && path
    remote = Remote.new remote, path
    remote.scp git_aware_files
    relpath = method :relative_path

    files_to_remove = Set.new
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
  end
end
