require "gitfyncy/version"
require 'listen'

module Gitfyncy
  PREFIX = 'git-fyncy'

  def self.slashify(path)
    path[-1] == '/' ? path : path + '/'
  end

  RELATIVE_PATH = slashify `pwd`.rstrip

  class Remote
    def initialize(remote, path)
      @remote = remote
      @path = Gitfyncy.slashify path
    end

    def command(cmd)
      puts "#{Gitfyncy::PREFIX}: #{cmd}"
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
    controlled_paths = Set.new git_aware_files
    remote.scp controlled_paths
    relpath = method :relative_path
    Listen.to!('.') do |modified, added, removed|
      begin
        changed_paths = (modified + added).map(&relpath).
          select(&method(:git_aware_of_path?))
        remote.scp changed_paths

        controlled_removed = controlled_paths.intersection removed.map(&relpath)
        controlled_paths.merge changed_paths

        if remote.ssh_rm controlled_removed
          controlled_paths.subtract controlled_removed
        end
      rescue => e
        puts e.inspect
      end
    end
  end
end
