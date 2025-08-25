require 'test_helper'

class Kaggle::ClientTest < Minitest::Test
  def setup
    @username = 'test_user'
    @api_key = 'test_key'
    @client = Kaggle::Client.new(username: @username, api_key: @api_key)
  end

  def test_initialization_with_credentials
    client = Kaggle::Client.new(username: 'user', api_key: 'key')
    assert_equal 'user', client.username
    assert_equal 'key', client.api_key
  end

  def test_initialization_with_environment_variables
    ENV['KAGGLE_USERNAME'] = 'env_user'
    ENV['KAGGLE_KEY'] = 'env_key'

    client = Kaggle::Client.new
    assert_equal 'env_user', client.username
    assert_equal 'env_key', client.api_key
  ensure
    ENV.delete('KAGGLE_USERNAME')
    ENV.delete('KAGGLE_KEY')
  end

  def test_initialization_without_credentials_raises_error
    assert_raises(Kaggle::AuthenticationError) do
      Kaggle::Client.new
    end
  end

  def test_initialization_with_credentials_file
    credentials_file = create_temp_credentials_file('file_user', 'file_key')

    client = Kaggle::Client.new(credentials_file: credentials_file.path)
    assert_equal 'file_user', client.username
    assert_equal 'file_key', client.api_key
  ensure
    credentials_file&.close
    credentials_file&.unlink
  end

  def test_initialization_with_credentials_file_priority
    # Explicit credentials should override file credentials
    credentials_file = create_temp_credentials_file('file_user', 'file_key')

    client = Kaggle::Client.new(
      username: 'explicit_user',
      api_key: 'explicit_key',
      credentials_file: credentials_file.path
    )
    assert_equal 'explicit_user', client.username
    assert_equal 'explicit_key', client.api_key
  ensure
    credentials_file&.close
    credentials_file&.unlink
  end

  def test_initialization_with_default_kaggle_json
    # Create temporary kaggle.json in current directory
    original_dir = Dir.pwd
    temp_dir = Dir.mktmpdir
    Dir.chdir(temp_dir)

    kaggle_json_path = File.join(temp_dir, 'kaggle.json')
    File.write(kaggle_json_path, { username: 'default_user', key: 'default_key' }.to_json)

    client = Kaggle::Client.new
    assert_equal 'default_user', client.username
    assert_equal 'default_key', client.api_key
  ensure
    Dir.chdir(original_dir) if original_dir
    FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
  end

  def test_initialization_with_invalid_credentials_file
    invalid_file = create_temp_file('invalid json content', '.json')

    assert_raises(Kaggle::AuthenticationError) do
      Kaggle::Client.new(credentials_file: invalid_file.path)
    end
  ensure
    invalid_file&.close
    invalid_file&.unlink
  end

  def test_initialization_with_nonexistent_credentials_file
    assert_raises(Kaggle::AuthenticationError) do
      Kaggle::Client.new(credentials_file: '/nonexistent/file.json')
    end
  end

  def test_initialization_sets_default_paths
    assert_equal './downloads', @client.download_path
    assert_equal './cache', @client.cache_path
    assert_equal 30, @client.timeout
  end

  def test_initialization_with_custom_paths
    temp_download = Dir.mktmpdir
    temp_cache = Dir.mktmpdir

    client = Kaggle::Client.new(
      username: 'user',
      api_key: 'key',
      download_path: temp_download,
      cache_path: temp_cache,
      timeout: 60
    )

    assert_equal temp_download, client.download_path
    assert_equal temp_cache, client.cache_path
    assert_equal 60, client.timeout
  ensure
    FileUtils.rm_rf(temp_download) if temp_download && Dir.exist?(temp_download)
    FileUtils.rm_rf(temp_cache) if temp_cache && Dir.exist?(temp_cache)
  end

  def test_dataset_files_success
    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/data/owner/dataset')
      .to_return(status: 200, body: '{"files": []}')

    result = @client.dataset_files('owner', 'dataset')
    assert_equal({ 'files' => [] }, result)
  end

  def test_dataset_files_not_found
    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/data/owner/dataset')
      .to_return(status: 404, body: 'Not found')

    assert_raises(Kaggle::DatasetNotFoundError) do
      @client.dataset_files('owner', 'dataset')
    end
  end

  def test_parse_csv_to_json_with_valid_file
    csv_content = "name,age\nJohn,30\nJane,25"
    csv_file = create_temp_csv(csv_content)

    result = @client.parse_csv_to_json(csv_file.path)
    expected = [
      { 'name' => 'John', 'age' => '30' },
      { 'name' => 'Jane', 'age' => '25' }
    ]

    assert_equal expected, result
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_parse_csv_to_json_with_nonexistent_file
    assert_raises(Kaggle::Error) do
      @client.parse_csv_to_json('/nonexistent/file.csv')
    end
  end

  def test_parse_csv_to_json_with_non_csv_file
    txt_file = Tempfile.new(['test', '.txt'])
    txt_file.write('Not a CSV')
    txt_file.close

    assert_raises(Kaggle::Error) do
      @client.parse_csv_to_json(txt_file.path)
    end
  ensure
    txt_file.unlink
  end

  def test_parse_csv_to_json_with_malformed_csv
    malformed_csv = create_temp_csv("name,age\nJohn,\"unclosed quote\nJane,25")

    assert_raises(Kaggle::ParseError) do
      @client.parse_csv_to_json(malformed_csv.path)
    end
  ensure
    malformed_csv&.close
    malformed_csv&.unlink
  end

  def test_download_dataset_creates_directories
    FileUtils.expects(:mkdir_p).with('./downloads').once
    FileUtils.expects(:mkdir_p).with('./cache').once
    Dir.expects(:exist?).with('./downloads').returns(false).once
    Dir.expects(:exist?).with('./cache').returns(false).once

    Kaggle::Client.new(username: @username, api_key: @api_key)
  end

  def test_download_dataset_success_with_webmock
    # Create a real zip file content for testing
    zip_content = create_test_zip_with_csv

    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/download/owner/dataset')
      .with(
        headers: {
          'Accept' => 'application/json',
          'User-Agent' => 'Kaggle Ruby Client/0.0.1'
        }
      )
      .to_return(
        status: 200,
        body: zip_content,
        headers: { 'Content-Type' => 'application/zip' }
      )

    result = @client.download_dataset('owner', 'dataset')

    # Should return extracted directory path
    assert_kind_of String, result
    assert_includes result, 'downloads'
    assert Dir.exist?(result)
  end

  def test_download_dataset_failure_with_webmock
    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/download/owner/dataset')
      .to_return(status: 404, body: 'Dataset not found')

    assert_raises(Kaggle::DownloadError) do
      @client.download_dataset('owner', 'dataset')
    end
  end

  def test_dataset_files_with_json_parse_error
    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/data/owner/dataset')
      .to_return(status: 200, body: 'invalid json')

    assert_raises(Kaggle::ParseError) do
      @client.dataset_files('owner', 'dataset')
    end
  end

  private

  def create_temp_csv(content)
    file = Tempfile.new(['test', '.csv'])
    file.write(content)
    file.rewind
    file
  end

  def create_temp_credentials_file(username, key)
    file = Tempfile.new(['credentials', '.json'])
    credentials = { username: username, key: key }
    file.write(credentials.to_json)
    file.close
    file
  end

  def create_temp_file(content, extension)
    file = Tempfile.new(['test', extension])
    file.write(content)
    file.close
    file
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
