require 'git-fyncy/utils'
require 'git-fyncy/repo'
require 'git-fyncy/remote'
require 'listen'

module GitFyncy
  class Synchronizer
    include Utils

    def initialize(extra_rsync_args)
      remote, path = Repo.host_and_path_from_current_repo
      pexit 'A remote and path must be specified' unless remote && path
      @remote = Remote.new remote, path, extra_rsync_args
    end

    def sync
      @remote.scp Repo.git_aware_files
    end

    def listen
      puts "GIT FYNCY: Listening @ #{Time.now.ctime}"
      relpath = method :relative_path
      files_to_remove = Set.new
      begin
        Listen.to!('.') do |modified, added, removed|
          begin
            self.sync
            rel_removed = removed.map(&relpath)
            files_to_remove.merge rel_removed
            files_to_remove.clear if @remote.ssh_rm files_to_remove
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

    private

    def relative_path(path)
      path.slice! slashify(Dir.pwd)
      path
    end
  end
end
