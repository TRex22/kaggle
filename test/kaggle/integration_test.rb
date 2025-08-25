require 'test_helper'

class Kaggle::IntegrationTest < Minitest::Test
  def setup
    @username = 'test_user'
    @api_key = 'test_key'
    @temp_download_dir = Dir.mktmpdir
    @temp_cache_dir = Dir.mktmpdir

    @client = Kaggle::Client.new(
      username: @username,
      api_key: @api_key,
      download_path: @temp_download_dir,
      cache_path: @temp_cache_dir
    )
  end

  def teardown
    FileUtils.rm_rf(@temp_download_dir) if @temp_download_dir && Dir.exist?(@temp_download_dir)
    FileUtils.rm_rf(@temp_cache_dir) if @temp_cache_dir && Dir.exist?(@temp_cache_dir)
  end

  def test_complete_dataset_workflow_with_caching
    dataset_owner = 'test-owner'
    dataset_name = 'test-dataset'
    zip_content = create_test_zip_with_csv

    expected_data = [
      { 'name' => 'John', 'age' => '30', 'city' => 'NYC' },
      { 'name' => 'Jane', 'age' => '25', 'city' => 'LA' }
    ]

    # Mock the download request
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/download/#{dataset_owner}/#{dataset_name}")
      .to_return(status: 200, body: zip_content, headers: { 'Content-Type' => 'application/zip' })

    # First download - should make HTTP request and cache the result
    result1 = @client.download_dataset(dataset_owner, dataset_name, use_cache: true, parse_csv: true)
    assert_equal expected_data, result1

    # Second download - should use cache (no HTTP request needed)
    WebMock.reset! # Clear stubs to ensure no HTTP request is made
    result2 = @client.download_dataset(dataset_owner, dataset_name, use_cache: true, parse_csv: true)
    assert_equal expected_data, result2

    # Verify both results are identical
    assert_equal result1, result2
  end

  def test_dataset_file_inspection_workflow
    # Mock dataset files API
    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/data/realestate/housing-data')
      .to_return(
        status: 200,
        body: '{"files":[{"name":"train.csv","size":1048576},{"name":"test.csv","size":524288},{"name":"README.md","size":2048}]}'
      )

    # Inspect files for a dataset
    files = @client.dataset_files('realestate', 'housing-data')
    assert_equal 3, files['files'].length
    assert_equal 'train.csv', files['files'][0]['name']
    assert_equal 1_048_576, files['files'][0]['size']
  end

  def test_error_recovery_and_handling_workflow
    dataset_owner = 'nonexistent'
    dataset_name = 'dataset'

    # Test dataset not found error
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/data/#{dataset_owner}/#{dataset_name}")
      .to_return(status: 404, body: 'Dataset not found')

    error = assert_raises(Kaggle::DatasetNotFoundError) do
      @client.dataset_files(dataset_owner, dataset_name)
    end

    assert_includes error.message, 'Dataset not found or accessible'

    # Test download error
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/download/#{dataset_owner}/#{dataset_name}")
      .to_return(status: 403, body: 'Access denied')

    download_error = assert_raises(Kaggle::DownloadError) do
      @client.download_dataset(dataset_owner, dataset_name)
    end

    assert_includes download_error.message, 'Failed to download dataset'
  end

  def test_file_format_detection_and_parsing_workflow
    # Create various file types to test detection
    csv_file = create_test_file('test.csv', "name,age\nJohn,30")
    txt_file = create_test_file('test.txt', 'Just plain text')
    json_file = create_test_file('data.json', '{"key": "value"}')

    # Test CSV file detection and parsing
    assert @client.send(:csv_file?, csv_file)
    parsed_data = @client.parse_csv_to_json(csv_file)
    assert_equal [{ 'name' => 'John', 'age' => '30' }], parsed_data

    # Test non-CSV file rejection
    refute @client.send(:csv_file?, txt_file)
    refute @client.send(:csv_file?, json_file)

    # Test error when trying to parse non-CSV as CSV
    assert_raises(Kaggle::Error) do
      @client.parse_csv_to_json(txt_file)
    end

    assert_raises(Kaggle::Error) do
      @client.parse_csv_to_json(json_file)
    end
  end

  def test_cache_invalidation_and_refresh_workflow
    dataset_path = 'owner/dataset'
    cache_key = @client.send(:generate_cache_key, dataset_path)

    # Create initial cached data
    initial_data = [{ 'name' => 'John', 'age' => '30' }]
    @client.send(:cache_parsed_data, cache_key, initial_data)

    # Verify cache hit
    assert @client.send(:cached_file_exists?, cache_key)
    cached_data = @client.send(:load_from_cache, cache_key)
    assert_equal initial_data, cached_data

    # Simulate cache invalidation by modifying cache file
    cache_file_path = File.join(@temp_cache_dir, cache_key)
    File.write(cache_file_path, 'invalid json content')

    # Should raise error when trying to load corrupted cache
    assert_raises(Kaggle::ParseError) do
      @client.send(:load_from_cache, cache_key)
    end
  end

  private

  def create_test_file(filename, content)
    file_path = File.join(@temp_download_dir, filename)
    File.write(file_path, content)
    file_path
  end

  def create_test_zip_with_csv
    # Create a temporary zip file with CSV content
    csv_content = "name,age,city\nJohn,30,NYC\nJane,25,LA"

    # Create a temporary file to write zip content to
    temp_file = Tempfile.new(['test', '.zip'])
    temp_file.binmode

    begin
      Zip::OutputStream.open(temp_file) do |zos|
        zos.put_next_entry('test_data.csv')
        zos.write csv_content
      end

      temp_file.rewind
      content = temp_file.read
    ensure
      temp_file.close
      temp_file.unlink
    end

    content
  end
end
