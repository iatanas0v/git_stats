require 'terminal-table'

module Table
  class Table
    attr_reader :stats
    private attr_accessor :table

    HEADER = ['Position', 'Author', 'Total Lines Owned', 'Percentage', 'Across X Files', 'Most Popular File'].freeze

    def initialize(stats)
      @stats = stats
      @table = Terminal::Table.new headings: HEADER, rows: rows
    end

    def to_s
      table.to_s
    end

    def print
      puts table
    end

    private

    def rows
      table_rows = stats.data
        .sort_by { |_, stats| stats['totalLines'] }
        .map { |author, stats| row(author, stats) }
        .reverse
        .each_with_index.map { |row, index| [index + 1, *row] }
    end

    def row(author, stats)
      most_popular_file = stats['files'].sort_by { |_, c| c }.last.first

      [
        author,
        stats['totalLines'],
        "#{(total_lines.zero? ? 0 : (stats['totalLines'] * 100.0 / total_lines).round(2))}%",
        stats['files'].size,
        most_popular_file
      ]
    end

    def total_lines
      @total_lines ||= stats.data.values.map { |stats| stats['totalLines'] }.sum
    end
  end
end
