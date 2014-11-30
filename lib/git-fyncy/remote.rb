require 'git-fyncy/utils'

module GitFyncy
  class Remote
    include Utils

    def initialize(remote, path, rsync_args)
      @remote = remote
      @path = slashify path
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
end
