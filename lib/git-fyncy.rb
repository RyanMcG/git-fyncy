require "git-fyncy/version"
require 'git-fyncy/synchronizer'
require 'listen'

module GitFyncy
  extend Utils
  PID_FNAME = ".git/fyncy-pid".freeze

  def self.old_pid
    @_old_pid ||= File.read(PID_FNAME).to_i
  end

  def self.already_running?
    return false unless File.exists? PID_FNAME
    begin
      Process.kill 0, old_pid
      true
    rescue Errno::ESRCH
      false
    end
  end

  def self.kill
    if already_running?
      if Process.kill "TERM", old_pid
        File.delete PID_FNAME
      else
        pexit "Failed to kill process with id #{old_pid}"
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

    File.write PID_FNAME, Process.pid
    trap("INT") do
      File.delete PID_FNAME
      pexit "Exiting happily!"
    end
    synchronizer.listen
  end
end
