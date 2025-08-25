require 'test_helper'
require 'securerandom'

class Kaggle::CsvParsingTest < Minitest::Test
  def setup
    @username = 'test_user'
    @api_key = 'test_key'
    @client = Kaggle::Client.new(username: @username, api_key: @api_key)
    @temp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def test_parse_csv_with_headers
    csv_content = "name,age,email\nJohn Doe,30,john@example.com\nJane Smith,25,jane@example.com"
    csv_file = create_temp_csv_file(csv_content)

    result = @client.parse_csv_to_json(csv_file)

    expected = [
      { 'name' => 'John Doe', 'age' => '30', 'email' => 'john@example.com' },
      { 'name' => 'Jane Smith', 'age' => '25', 'email' => 'jane@example.com' }
    ]

    assert_equal expected, result
  end

  def test_parse_csv_with_empty_file
    csv_file = create_temp_csv_file('')

    result = @client.parse_csv_to_json(csv_file)
    assert_equal [], result
  end

  def test_parse_csv_with_only_headers
    csv_content = 'name,age,email'
    csv_file = create_temp_csv_file(csv_content)

    result = @client.parse_csv_to_json(csv_file)
    assert_equal [], result
  end

  def test_parse_csv_with_quotes_and_commas
    csv_content = "name,description\n\"Smith, John\",\"A person with a comma in name\"\n\"Doe, Jane\",\"Another person\""
    csv_file = create_temp_csv_file(csv_content)

    result = @client.parse_csv_to_json(csv_file)

    expected = [
      { 'name' => 'Smith, John', 'description' => 'A person with a comma in name' },
      { 'name' => 'Doe, Jane', 'description' => 'Another person' }
    ]

    assert_equal expected, result
  end

  def test_parse_csv_with_special_characters
    csv_content = "name,symbol\nAlpha,α\nBeta,β\nGamma,γ"
    csv_file = create_temp_csv_file(csv_content)

    result = @client.parse_csv_to_json(csv_file)

    expected = [
      { 'name' => 'Alpha', 'symbol' => 'α' },
      { 'name' => 'Beta', 'symbol' => 'β' },
      { 'name' => 'Gamma', 'symbol' => 'γ' }
    ]

    assert_equal expected, result
  end

  def test_parse_csv_with_large_dataset
    # Generate a larger CSV to test performance
    rows = 1000
    csv_content = "id,name,value\n"

    (1..rows).each do |i|
      csv_content += "#{i},Item #{i},#{i * 10}\n"
    end

    csv_file = create_temp_csv_file(csv_content)

    result = @client.parse_csv_to_json(csv_file)

    assert_equal rows, result.length
    assert_equal({ 'id' => '1', 'name' => 'Item 1', 'value' => '10' }, result.first)
    assert_equal({ 'id' => rows.to_s, 'name' => "Item #{rows}", 'value' => (rows * 10).to_s }, result.last)
  end

  def test_parse_csv_with_missing_values
    csv_content = "name,age,city\nJohn,30,NYC\nJane,,LA\nBob,35,"
    csv_file = create_temp_csv_file(csv_content)

    result = @client.parse_csv_to_json(csv_file)

    expected = [
      { 'name' => 'John', 'age' => '30', 'city' => 'NYC' },
      { 'name' => 'Jane', 'age' => nil, 'city' => 'LA' },
      { 'name' => 'Bob', 'age' => '35', 'city' => nil }
    ]

    assert_equal expected, result
  end

  def test_parse_csv_with_different_line_endings
    # Test with different line ending styles
    csv_content_unix = "name,age\nJohn,30\nJane,25"
    csv_content_windows = "name,age\r\nJohn,30\r\nJane,25"
    csv_content_mac = "name,age\rJohn,30\rJane,25"

    [csv_content_unix, csv_content_windows, csv_content_mac].each do |content|
      csv_file = create_temp_csv_file(content)
      result = @client.parse_csv_to_json(csv_file)

      expected = [
        { 'name' => 'John', 'age' => '30' },
        { 'name' => 'Jane', 'age' => '25' }
      ]

      assert_equal expected, result
    end
  end

  def test_csv_file_detection_with_various_extensions
    ['.csv', '.CSV', '.Csv', '.cSv'].each do |ext|
      assert @client.send(:csv_file?, "test#{ext}")
    end

    ['.txt', '.json', '.xml', '.data', ''].each do |ext|
      refute @client.send(:csv_file?, "test#{ext}")
    end
  end

  private

  def create_temp_csv_file(content)
    file = File.join(@temp_dir, "test_#{SecureRandom.hex(8)}.csv")
    File.write(file, content)
    file
  end
end
