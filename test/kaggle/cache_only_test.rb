require 'test_helper'

class Kaggle::CacheOnlyTest < Minitest::Test
  def setup
    @temp_cache = Dir.mktmpdir
    @temp_download = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@temp_cache) if @temp_cache && Dir.exist?(@temp_cache)
    FileUtils.rm_rf(@temp_download) if @temp_download && Dir.exist?(@temp_download)
  end

  def test_cache_only_initialization_without_credentials
    client = Kaggle::Client.new(
      cache_only: true,
      cache_path: @temp_cache,
      download_path: @temp_download
    )

    assert client.cache_only
    assert_nil client.username
    assert_nil client.api_key
  end

  def test_cache_only_initialization_with_invalid_credentials
    client = Kaggle::Client.new(
      username: 'invalid',
      api_key: 'invalid',
      cache_only: true,
      cache_path: @temp_cache,
      download_path: @temp_download
    )

    assert client.cache_only
    assert_equal 'invalid', client.username
    assert_equal 'invalid', client.api_key
  end

  def test_cache_only_download_returns_nil_when_no_cache
    client = Kaggle::Client.new(
      cache_only: true,
      cache_path: @temp_cache,
      download_path: @temp_download
    )

    result = client.download_dataset('test', 'dataset', use_cache: true)
    assert_nil result
  end

  def test_cache_only_download_raises_when_force_cache
    client = Kaggle::Client.new(
      cache_only: true,
      cache_path: @temp_cache,
      download_path: @temp_download
    )

    error = assert_raises(Kaggle::CacheNotFoundError) do
      client.download_dataset('test', 'dataset', use_cache: true, force_cache: true)
    end

    assert_match(/Dataset 'test\/dataset' not found in cache and force_cache is enabled/, error.message)
  end

  def test_cache_only_download_uses_cached_parsed_data
    client = Kaggle::Client.new(
      cache_only: true,
      cache_path: @temp_cache,
      download_path: @temp_download
    )

    # Create fake cached data
    cache_key = 'test_dataset_parsed.json'
    cache_file = File.join(@temp_cache, cache_key)
    cached_data = [{'url' => 'test.com', 'category' => 'test'}]
    File.write(cache_file, Oj.dump(cached_data))

    result = client.download_dataset('test', 'dataset', use_cache: true, parse_csv: true)
    assert_equal cached_data, result
  end

  def test_cache_only_download_uses_extracted_files
    client = Kaggle::Client.new(
      cache_only: true,
      cache_path: @temp_cache,
      download_path: @temp_download
    )

    # Create fake extracted directory with CSV
    extracted_dir = File.join(@temp_download, 'test_dataset')
    FileUtils.mkdir_p(extracted_dir)
    csv_file = File.join(extracted_dir, 'data.csv')
    File.write(csv_file, "url,category\ntest.com,test\nexample.com,sample")

    result = client.download_dataset('test', 'dataset', use_cache: true, parse_csv: true)
    expected = [
      {'url' => 'test.com', 'category' => 'test'},
      {'url' => 'example.com', 'category' => 'sample'}
    ]
    assert_equal expected, result
  end
end