require 'digest'
require 'progress_bar'
require_relative './src/Stats'
require_relative './src/git/Repository'
require_relative './src/storage/Storage'
require_relative './src/table/Table'

repository = Git::Repository.new(ARGV[0])
storage = Storage::Storage.new("#{Dir.getwd}/tmp", Digest::MD5.hexdigest("#{repository.path}#{repository.hash}"))
stats = Stats.new

puts "Storing all data in '#{storage.path}'"

files = repository.tracked_files.slice(0, 10)
progress = ProgressBar.new(files.size)

files.each do |file|
  repository
    .per_author_blame(file)
    .each do |author, lines_count|
      stats.bump_author(author, file, increase: lines_count)
    end

  progress.increment!
end

# Save the results in JSON
storage.store('output.json', stats.to_json)

Table::Table.new(stats).print
