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

  def test_list_datasets_success
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/list?page=1&size=20")
      .to_return(status: 200, body: '{"datasets": []}')

    result = @client.list_datasets
    assert_equal({ 'datasets' => [] }, result)
  end

  def test_list_datasets_with_options
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/list?page=2&search=housing&size=10")
      .to_return(status: 200, body: '{"datasets": []}')

    @client.list_datasets(page: 2, search: 'housing', page_size: 10)
  end

  def test_list_datasets_failure
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/list?page=1&size=20")
      .to_return(status: 404, body: 'Not found')

    assert_raises(Kaggle::Error) do
      @client.list_datasets
    end
  end

  def test_dataset_files_success
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/data/owner/dataset")
      .to_return(status: 200, body: '{"files": []}')

    result = @client.dataset_files('owner', 'dataset')
    assert_equal({ 'files' => [] }, result)
  end

  def test_dataset_files_not_found
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/data/owner/dataset")
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
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/download/owner/dataset")
      .with(
        headers: {
          'Accept' => 'application/json',
          'User-Agent' => 'Kaggle Ruby Client/0.0.1'
        }
      )
      .to_return(
        status: 200,
        body: 'fake zip file content',
        headers: { 'Content-Type' => 'application/zip' }
      )

    result = @client.download_dataset('owner', 'dataset')
    
    assert_kind_of String, result
    assert_includes result, 'downloads'
    assert_includes result, '.zip'
  end

  def test_download_dataset_failure_with_webmock
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/download/owner/dataset")
      .to_return(status: 404, body: 'Dataset not found')

    assert_raises(Kaggle::DownloadError) do
      @client.download_dataset('owner', 'dataset')
    end
  end

  def test_list_datasets_with_json_parse_error
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/list?page=1&size=20")
      .to_return(status: 200, body: 'invalid json')

    assert_raises(Kaggle::ParseError) do
      @client.list_datasets
    end
  end

  def test_dataset_files_with_json_parse_error
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/data/owner/dataset")
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
end