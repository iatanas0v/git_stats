module Git
  class Repository
    attr_reader :path

    PER_AUTHOR_BLAME_REGEX = %r{^author (.+)\s*}

    def initialize(path)
      @path = path

      raise 'No path given' unless path
      raise 'Not a real path' unless File.directory?(path)
      raise 'Not a git repository' unless File.directory?("#{path}/.git")
    end

    def tracked_files
      git('ls-files').split("\n")
    end

    def per_author_blame(file)
      git('blame', '--no-progress', '--line-porcelain', file)
        .encode!('UTF-8', 'UTF-8', invalid: :replace)
        .scan(PER_AUTHOR_BLAME_REGEX)
        .flatten
        .map(&:strip)
        .tally
    end

    def hash
      git('rev-parse', 'HEAD')
    end

    private

    def git(cmd, *args)
      Dir.chdir(path) do
        return `git #{cmd} #{args.join(' ')}`
      end
    end
  end
end
