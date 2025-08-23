require 'test_helper'

class Kaggle::ClientCachingTest < Minitest::Test
  def setup
    @username = 'test_user'
    @api_key = 'test_key'
    @temp_cache_dir = Dir.mktmpdir
    @temp_download_dir = Dir.mktmpdir
    
    @client = Kaggle::Client.new(
      username: @username, 
      api_key: @api_key,
      cache_path: @temp_cache_dir,
      download_path: @temp_download_dir
    )
  end

  def teardown
    FileUtils.rm_rf(@temp_cache_dir) if @temp_cache_dir && Dir.exist?(@temp_cache_dir)
    FileUtils.rm_rf(@temp_download_dir) if @temp_download_dir && Dir.exist?(@temp_download_dir)
  end

  def test_cache_parsed_data_creates_file
    test_data = [{ 'name' => 'John', 'age' => '30' }]
    cache_key = 'test_dataset_parsed.json'
    
    @client.send(:cache_parsed_data, cache_key, test_data)
    
    cache_file = File.join(@temp_cache_dir, cache_key)
    assert File.exist?(cache_file), "Cache file should be created"
    
    cached_content = File.read(cache_file)
    assert_includes cached_content, 'John'
  end

  def test_load_from_cache_returns_data
    test_data = [{ 'name' => 'Jane', 'age' => '25' }]
    cache_key = 'test_dataset_parsed.json'
    
    # First cache the data
    @client.send(:cache_parsed_data, cache_key, test_data)
    
    # Then load it back
    result = @client.send(:load_from_cache, cache_key)
    assert_equal test_data, result
  end

  def test_cached_file_exists_returns_true_when_file_exists
    cache_key = 'existing_cache.json'
    cache_file = File.join(@temp_cache_dir, cache_key)
    
    File.write(cache_file, '{}')
    
    assert @client.send(:cached_file_exists?, cache_key)
  end

  def test_cached_file_exists_returns_false_when_file_missing
    cache_key = 'nonexistent_cache.json'
    
    refute @client.send(:cached_file_exists?, cache_key)
  end

  def test_generate_cache_key_formats_correctly
    dataset_path = 'owner/dataset-name'
    expected_key = 'owner_dataset-name_parsed.json'
    
    result = @client.send(:generate_cache_key, dataset_path)
    assert_equal expected_key, result
  end

  def test_load_from_cache_handles_invalid_json
    cache_key = 'invalid_cache.json'
    cache_file = File.join(@temp_cache_dir, cache_key)
    
    File.write(cache_file, 'invalid json content')
    
    assert_raises(Kaggle::ParseError) do
      @client.send(:load_from_cache, cache_key)
    end
  end

  def test_save_downloaded_file_creates_file_with_timestamp
    dataset_path = 'test/dataset'
    content = 'test file content'
    
    Timecop.freeze(Time.at(1234567890)) do
      result = @client.send(:save_downloaded_file, dataset_path, content)
      
      expected_filename = 'test_dataset_1234567890.zip'
      expected_path = File.join(@temp_download_dir, expected_filename)
      
      assert_equal expected_path, result
      assert File.exist?(result), "Downloaded file should exist"
      assert_equal content, File.read(result)
    end
  end
end