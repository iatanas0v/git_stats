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

def skip_file?(file)
  # Ignore media files
  ['.mmdb', '.wav', '.mp3', '.mp4', '.jpg', '.jpeg', '.png', '.gif', '.woff', '.woff2', '.ttf', '.eot', '.svg', '.ico'].any? { |ext| file.end_with?(ext) } ||
  # Ignore vendor files
  file.include?('/vendor/') || file.start_with?('vendor/')
end

uniq_extensions = {}

files.each_slice(100) do |files_slice|
  files_slice.each do |file|
    progress.increment!

    if skip_file?(file)
      completed = [progress.count - 1, 0].max
      progress = ProgressBar.new(progress.max - 1)
      progress.increment!(completed) if completed > 0
      next
    end

    unless (extension = File.extname(file)).empty?
      uniq_extensions[extension] ||= 0
      uniq_extensions[extension] += 1
    end

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

puts "\n--------------------"
puts "Extensions:"
uniq_extensions.sort_by { |extension, count| -count }.each do |extension, count|
  puts "> #{extension}: #{count}"
end
