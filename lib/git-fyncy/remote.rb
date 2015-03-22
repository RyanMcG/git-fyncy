require 'git-fyncy/utils'

module GitFyncy
  class Remote
    include Utils

    def initialize(logger, remote, path, rsync_args)
      @logger = logger
      @remote = remote
      @path = slashify path
      @rsync_flags = rsync_args.join(" ")

      # COMMANDS
      @rm_cmd = "cd #{@path}; rm -f %{paths}"
      @rm_cmd = "ssh #{@remote} '#{@rm_cmd}'" if @remote
      path = @remote ? "#{@remote}:#{@path}" : @path
      @rsync_cmd = "rsync -zpR --checksum #{@rsync_flags} %{paths} #{path}"
    end

    def command(cmd, paths)
      return if paths.empty?
      cmd = cmd % {paths: paths.to_a.join(' ')}
      @logger.log cmd
      system cmd
    end

    def rsync(paths)
      command @rsync_cmd, paths
    end

    def rm(paths)
      command @rm_cmd, paths
    end
  end
end
