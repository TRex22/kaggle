require 'test_helper'

class Kaggle::ConfigurationTest < Minitest::Test
  def teardown
    # Clean up environment variables
    ENV.delete('KAGGLE_USERNAME')
    ENV.delete('KAGGLE_KEY')
  end

  def test_initialization_with_all_custom_parameters
    temp_download_dir = Dir.mktmpdir
    temp_cache_dir = Dir.mktmpdir

    custom_config = {
      username: 'custom_user',
      api_key: 'custom_key',
      download_path: temp_download_dir,
      cache_path: temp_cache_dir,
      timeout: 60
    }

    client = Kaggle::Client.new(**custom_config)

    assert_equal 'custom_user', client.username
    assert_equal 'custom_key', client.api_key
    assert_equal temp_download_dir, client.download_path
    assert_equal temp_cache_dir, client.cache_path
    assert_equal 60, client.timeout
  ensure
    FileUtils.rm_rf(temp_download_dir) if temp_download_dir && Dir.exist?(temp_download_dir)
    FileUtils.rm_rf(temp_cache_dir) if temp_cache_dir && Dir.exist?(temp_cache_dir)
  end

  def test_initialization_mixed_explicit_and_env_variables
    ENV['KAGGLE_USERNAME'] = 'env_username'
    ENV['KAGGLE_KEY'] = 'env_key'

    temp_dir = Dir.mktmpdir

    # Explicit parameters should override environment variables
    client = Kaggle::Client.new(
      username: 'explicit_user',
      download_path: temp_dir
    )

    assert_equal 'explicit_user', client.username
    assert_equal 'env_key', client.api_key # From environment
    assert_equal temp_dir, client.download_path
    assert_equal './cache', client.cache_path # Default
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
  end

  def test_initialization_validates_required_credentials_with_nil_values
    error = assert_raises(Kaggle::AuthenticationError) do
      Kaggle::Client.new(username: nil, api_key: nil)
    end

    assert_equal 'Username and API key are required', error.message
  end

  def test_initialization_validates_required_credentials_with_empty_strings
    error = assert_raises(Kaggle::AuthenticationError) do
      Kaggle::Client.new(username: '', api_key: '')
    end

    assert_equal 'Username and API key are required', error.message
  end

  def test_initialization_validates_partial_credentials
    error = assert_raises(Kaggle::AuthenticationError) do
      Kaggle::Client.new(username: 'user_only')
    end

    assert_equal 'Username and API key are required', error.message

    error2 = assert_raises(Kaggle::AuthenticationError) do
      Kaggle::Client.new(api_key: 'key_only')
    end

    assert_equal 'Username and API key are required', error2.message
  end

  def test_default_values_are_applied_correctly
    client = Kaggle::Client.new(username: 'test', api_key: 'test')

    assert_equal Kaggle::Constants::DEFAULT_DOWNLOAD_PATH, client.download_path
    assert_equal Kaggle::Constants::DEFAULT_CACHE_PATH, client.cache_path
    assert_equal Kaggle::Constants::DEFAULT_TIMEOUT, client.timeout
  end

  def test_custom_paths_with_relative_directories
    client = Kaggle::Client.new(
      username: 'test',
      api_key: 'test',
      download_path: './my_downloads',
      cache_path: '../shared_cache'
    )

    assert_equal './my_downloads', client.download_path
    assert_equal '../shared_cache', client.cache_path
  end

  def test_directory_creation_is_called_during_initialization
    temp_download_dir = File.join(Dir.tmpdir, 'test_download')
    temp_cache_dir = File.join(Dir.tmpdir, 'test_cache')

    # Ensure directories don't exist
    FileUtils.rm_rf([temp_download_dir, temp_cache_dir])

    FileUtils.expects(:mkdir_p).with(temp_download_dir).once
    FileUtils.expects(:mkdir_p).with(temp_cache_dir).once

    client = Kaggle::Client.new(
      username: 'test',
      api_key: 'test',
      download_path: temp_download_dir,
      cache_path: temp_cache_dir
    )

    assert_equal temp_download_dir, client.download_path
    assert_equal temp_cache_dir, client.cache_path
  end

  def test_timeout_accepts_various_numeric_types
    [30, 30.5, '45'].each do |timeout_value|
      client = Kaggle::Client.new(
        username: 'test',
        api_key: 'test',
        timeout: timeout_value
      )

      assert_equal timeout_value, client.timeout
    end
  end

  def test_environment_variable_precedence
    # Environment variables should be used when explicit params not provided
    ENV['KAGGLE_USERNAME'] = 'env_user'
    ENV['KAGGLE_KEY'] = 'env_key'

    client = Kaggle::Client.new

    assert_equal 'env_user', client.username
    assert_equal 'env_key', client.api_key
  end

  def test_empty_environment_variables_treated_as_missing
    ENV['KAGGLE_USERNAME'] = ''
    ENV['KAGGLE_KEY'] = ''

    error = assert_raises(Kaggle::AuthenticationError) do
      Kaggle::Client.new
    end

    assert_equal 'Username and API key are required', error.message
  end
end
