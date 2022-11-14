require 'json'

class Stats
  attr_reader :data
  private attr_writer :data

  def initialize(initial_data = {})
    @data = initial_data
  end

  def bump_author(author, file, increase: 1)
    data[author] = empty_author_object unless data.key?(author)

    data[author]['totalLines'] += increase

    data[author]['files'][file] = 0 unless data[author]['files'].key?(file)
    data[author]['files'][file] += increase
  end

  def to_json
    data.to_json
  end

  private

  def empty_author_object
    {
      'totalLines' => 0,
      'files' => {}
    }
  end
end
