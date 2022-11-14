require 'json'
require 'progress_bar'
require 'terminal-table'

raise 'No path given' unless ARGV[0]

repository_path = ARGV[0]

raise 'Not a real path' unless File.directory?(repository_path)
raise 'Not a git repository' unless File.directory?("#{repository_path}/.git")

REGEX = %r{\((.+?)\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}}.freeze

$stats = {}

def bump_author_stats(author, file)
  $stats[author] = { totalLines: 0, files: {} } unless $stats.key?(author)

  $stats[author][:totalLines] += 1

  $stats[author][:files][file] = 0 unless $stats[author][:files].key?(file)
  $stats[author][:files][file] += 1
end

Dir.chdir(repository_path) do
  files = `git ls-files`.split("\n")
  progress = ProgressBar.new(files.size)

  files.each do |file|
    lines = `git blame --no-progress #{file}`.split("\n")

    lines.each do |line|
      matches = REGEX.match(line)

      raise "REGEX matched nothing. File: #{file}. Line: `#{line}`" unless matches

      author = matches[1].strip

      bump_author_stats(author, file)
    end

    progress.increment!
  end
end

# Save the results in JSON
File.open('output.json', 'w') do |f|
  f.write($stats.to_json)
end

def author_table_row(author, stats)
  most_popular_file = stats[:files].sort_by { |_, c| c }.last.first

  [
    author,
    stats[:totalLines],
    stats[:files].size,
    most_popular_file
  ]
end

table_heading = ['Author', 'Total Lines Owned', 'Across X Files', 'Most Popular File']
table_rows = $stats
  .sort_by { |_, stats| stats[:totalLines] }
  .map { |author, stats| author_table_row(author, stats) }
  .reverse

table = Terminal::Table.new :headings => table_heading, :rows => table_rows

puts table
