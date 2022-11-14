require 'terminal-table'

module Table
  class Table
    attr_reader :stats
    private attr_accessor :table

    HEADER = ['Author', 'Total Lines Owned', 'Across X Files', 'Most Popular File'].freeze

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
    end

    def row(author, stats)
      most_popular_file = stats['files'].sort_by { |_, c| c }.last.first

      [
        author,
        stats['totalLines'],
        stats['files'].size,
        most_popular_file
      ]
    end
  end
end
