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
  ['.mmdb', '.wav', '.mp3', '.mp4', '.jpg', '.jpeg', '.png', '.gif', '.woff', '.woff2', '.ttf', '.eot', '.svg', '.ico'].any? { file.end_with?(_1) } ||
  # Ignore lock files
  file.end_with?('.lock') ||
  # Ignore vendor files
  file.include?('/vendor/') || file.start_with?('vendor/')
end

uniq_extensions = {}

# Filter files that need processing
files_to_process = files.reject do |file|
  skip_file?(file) || processed_files.key?(file)
end

# Update progress bar to reflect skipped files
progress = ProgressBar.new(files_to_process.size)

# Process files in parallel with a thread pool
require 'concurrent'

thread_count = [Concurrent.processor_count, 8].min
pool = Concurrent::FixedThreadPool.new(thread_count)
mutex = Mutex.new

files_to_process.each_slice(100) do |files_slice|
  # Track extensions for all files (not just processed ones)
  files_slice.each do |file|
    unless (extension = File.extname(file)).empty?
      mutex.synchronize do
        uniq_extensions[extension] ||= 0
        uniq_extensions[extension] += 1
      end
    end
  end

  # Process files in parallel
  promises = files_slice.map do |file|
    Concurrent::Promise.execute(executor: pool) do
      begin
        blame_data = repository.per_author_blame(file)
        [file, blame_data]
      rescue => error
        mutex.synchronize do
          puts error
          puts "File: #{file}"
        end
        nil
      end
    end
  end

  # Wait for all files in this slice to complete
  results = promises.map(&:value)

  # Update stats with the results
  mutex.synchronize do
    results.compact.each do |file, blame_data|
      blame_data.each do |author, lines_count|
        stats.bump_author(author, file, increase: lines_count)
      end
      processed_files[file] = file
      progress.increment!
    end

    # Save progress after each slice
    storage.store('parsed_files.txt', processed_files.keys.join("\n"))
    storage.store('stats.json', stats.to_json)
    storage.store('table.txt', Table::Table.new(stats))
  end
end

pool.shutdown
pool.wait_for_termination

Table::Table.new(stats).print

puts "\n--------------------"
puts "Extensions:"
uniq_extensions.sort_by { |extension, count| -count }.each do |extension, count|
  puts "> #{extension}: #{count}"
end
