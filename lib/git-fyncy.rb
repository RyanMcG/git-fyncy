require "git-fyncy/version"
require "git-fyncy/synchronizer"
require 'listen'

module GitFyncy
  extend Utils

  def self.main(*extra_rsync_args)
    working_dir = `git rev-parse --show-toplevel`.chomp

    if working_dir.empty?
      pexit "Must be in a git repository"
    end

    Dir.chdir working_dir

    synchronizer = Synchronizer.new extra_rsync_args
    unless synchronizer.sync
      pexit "\nGIT FYNCY: First remote command failed, exiting"
    end
    synchronizer.listen
  end
end
