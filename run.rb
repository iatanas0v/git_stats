require 'digest'
require 'progress_bar'
require_relative './src/Stats'
require_relative './src/git/Repository'
require_relative './src/storage/Storage'
require_relative './src/table/Table'

repository = Git::Repository.new(ARGV[0])
storage = Storage::Storage.new("#{Dir.getwd}/tmp", Digest::MD5.hexdigest("#{repository.path}#{repository.hash}"))
stats = Stats.new(JSON.parse(storage.safe_read('stats.json', '{}')))

puts "Storing all data in '#{storage.path}'"

files = repository.tracked_files
processed_files = storage.safe_read('parsed_files.txt', '').split("\n").to_h { |file| [file, file] }

progress = ProgressBar.new(files.size)

files.each_slice(100) do |files_slice|
  files_slice.each do |file|
    progress.increment!

    if processed_files.key?(file)
      progress = ProgressBar.new(progress.max - 1)
      next
    end

    begin
      repository
        .per_author_blame(file)
        .each do |author, lines_count|
          stats.bump_author(author, file, increase: lines_count)
        end
    rescue => error
      puts error
      puts "File: #{file}"
      exit
    end

    processed_files[file] = file
  end

  storage.store('parsed_files.txt', processed_files.keys.join("\n"))
  storage.store('stats.json', stats.to_json)
  storage.store('table.txt', Table::Table.new(stats))
end

Table::Table.new(stats).print
