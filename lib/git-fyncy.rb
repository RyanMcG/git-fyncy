require "git-fyncy/version"
require 'git-fyncy/synchronizer'
require 'listen'

module GitFyncy
  extend Utils
  PID_FNAME = ".git-fyncy-pid".freeze

  def self.already_running?
    File.exists? PID_FNAME
  end

  def self.kill
    if already_running?
      pid = File.read(PID_FNAME).to_i
      if Process.kill "TERM", pid
        File.delete PID_FNAME
      else
        pexit "Failed to kill process with id #{pid}"
      end
    else
      pexit "No process to kill. No #{PID_FNAME} file."
    end
  end

  FLAGS = %w(--fork --kill).to_set.freeze
  def self.main(args)
    working_dir = `git rev-parse --show-toplevel`.chomp

    pexit 'Must be in a git repository' if working_dir.empty?

    Dir.chdir working_dir
    return kill if args.include? "--kill"
    if already_running?
      pexit "#{PID_FNAME} exists. Is git fyncy already running?"
    end

    rsync_args = args.reject { |arg| FLAGS.include? arg }
    # Listen in the background if one of the args was '--fork'.
    background = args.include? "--fork"

    synchronizer = Synchronizer.new background, rsync_args
    unless synchronizer.sync
      pexit "\nGIT FYNCY: First remote command failed, exiting"
    end

    synchronizer.listen
  end
end
