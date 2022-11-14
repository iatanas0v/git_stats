module Storage
  class Storage
    private attr_reader :key, :root

    def initialize(root, key)
      @root = root
      @key = key

      create_dir
    end

    def store(filename, content)
      File.open(path(filename), 'w') do |f|
        f.write(content)
      end
    end

    def read(filename)
      File.read(path(filename))
    end

    def exists?(filename)
      File.file?(path(filename))
    end

    def path(file = '')
      "#{root}/#{key}/#{file}"
    end

    private

    def create_dir
      Dir.mkdir(path) unless File.directory?(path)
    end
  end
end
