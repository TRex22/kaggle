require 'test_helper'

class Kaggle::ClientCachingTest < Minitest::Test
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

  def test_cache_parsed_data_creates_file
    data = [{ 'name' => 'John', 'age' => '30' }]
    cache_key = 'test_cache.json'

    @client.send(:cache_parsed_data, cache_key, data)

    cache_file_path = File.join(@temp_cache_dir, cache_key)
    assert File.exist?(cache_file_path)

    cached_content = Oj.load(File.read(cache_file_path))
    assert_equal data, cached_content
  end

  def test_load_from_cache_returns_data
    data = [{ 'name' => 'John', 'age' => '30' }]
    cache_key = 'test_cache.json'

    # First cache the data
    @client.send(:cache_parsed_data, cache_key, data)

    # Then load it back
    result = @client.send(:load_from_cache, cache_key)
    assert_equal data, result
  end

  def test_cached_file_exists_returns_true_when_file_exists
    cache_key = 'test_cache.json'
    cache_file_path = File.join(@temp_cache_dir, cache_key)
    File.write(cache_file_path, '{}')

    assert @client.send(:cached_file_exists?, cache_key)
  end

  def test_cached_file_exists_returns_false_when_file_missing
    cache_key = 'nonexistent_cache.json'

    refute @client.send(:cached_file_exists?, cache_key)
  end

  def test_generate_cache_key_formats_correctly
    dataset_path = 'owner/dataset'
    expected_key = 'owner_dataset_parsed.json'

    result = @client.send(:generate_cache_key, dataset_path)
    assert_equal expected_key, result
  end

  def test_load_from_cache_handles_invalid_json
    cache_key = 'invalid_cache.json'
    cache_file_path = File.join(@temp_cache_dir, cache_key)
    File.write(cache_file_path, 'invalid json content')

    assert_raises(Kaggle::ParseError) do
      @client.send(:load_from_cache, cache_key)
    end
  end

  def test_download_with_caching_uses_cache_on_second_call
    dataset_owner = 'owner'
    dataset_name = 'dataset'
    zip_content = create_test_zip_with_csv

    # Mock the download request
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/download/#{dataset_owner}/#{dataset_name}")
      .to_return(status: 200, body: zip_content, headers: { 'Content-Type' => 'application/zip' })

    # First download should make HTTP request
    result1 = @client.download_dataset(dataset_owner, dataset_name, use_cache: true, parse_csv: true)

    # Second download should use cache (no HTTP request)
    WebMock.reset!
    result2 = @client.download_dataset(dataset_owner, dataset_name, use_cache: true, parse_csv: true)

    assert_equal result1, result2
  end

  def test_download_without_caching_always_downloads
    dataset_owner = 'owner'
    dataset_name = 'dataset'
    zip_content = create_test_zip_with_csv

    # Mock the download request to be called twice
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/download/#{dataset_owner}/#{dataset_name}")
      .to_return(status: 200, body: zip_content, headers: { 'Content-Type' => 'application/zip' })
      .times(2)

    # Both downloads should make HTTP requests
    result1 = @client.download_dataset(dataset_owner, dataset_name, use_cache: false, parse_csv: true)
    result2 = @client.download_dataset(dataset_owner, dataset_name, use_cache: false, parse_csv: true)

    # Results should be the same but both requests were made
    assert_equal result1, result2
    assert_requested :get, "https://www.kaggle.com/api/v1/datasets/download/#{dataset_owner}/#{dataset_name}", times: 2
  end

  private

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
