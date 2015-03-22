require 'git-fyncy/utils'
require 'git-fyncy/repo'
require 'git-fyncy/remote'
require 'git-fyncy/logger'
require 'listen'

module GitFyncy
  class Synchronizer
    include Utils

    def initialize(background, extra_rsync_args)
      remote, path = Repo.host_and_path_from_current_repo
      pexit 'A remote and path must be specified' unless path
      @background = background
      @logger = Logger.new background
      @remote = Remote.new @logger, remote, path, extra_rsync_args
    end

    def sync
      @remote.rsync Repo.git_aware_files
    end

    # Listen to file changes, forking to the background first if background is
    # true.
    def listen
      daemonize if @background
      @logger.log "GIT FYNCY: Listening @ #{Time.now.ctime}"
      relpath = method :relative_path
      files_to_remove = Set.new
      begin
        Listen.to!('.') do |modified, added, removed|
          begin
            self.sync
            rel_removed = removed.map(&relpath)
            files_to_remove.merge rel_removed
            files_to_remove.clear if @remote.rm files_to_remove
          rescue => e
            @logger.log e.inspect
          end
        end
      rescue SignalException
        exit 42
      ensure
        @logger.log "\n"
      end
    end

    private

    def daemonize
      pid = fork
      if pid # parent
        File.write ".git-fyncy-pid", pid
        Process.detach pid
        exit 0
      end
    end

    def relative_path(path)
      path.slice! slashify(Dir.pwd)
      path
    end
  end
end
