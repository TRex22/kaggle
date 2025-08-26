require 'test_helper'

class Kaggle::ClientErrorHandlingTest < Minitest::Test
  def setup
    @username = 'test_user'
    @api_key = 'test_key'
    @client = Kaggle::Client.new(username: @username, api_key: @api_key)
  end

  def test_authenticated_request_handles_timeout
    @client.class.expects(:get).raises(Timeout::Error)

    error = assert_raises(Kaggle::Error) do
      @client.send(:authenticated_request, :get, '/test')
    end

    assert_equal 'Request timed out', error.message
  end

  def test_authenticated_request_handles_general_errors
    @client.class.expects(:get).raises(StandardError.new('Connection failed'))

    error = assert_raises(Kaggle::Error) do
      @client.send(:authenticated_request, :get, '/test')
    end

    assert_includes error.message, 'Request failed: Connection failed'
  end

  def test_csv_file_detection_is_case_insensitive
    assert @client.send(:csv_file?, 'test.csv')
    assert @client.send(:csv_file?, 'test.CSV')
    assert @client.send(:csv_file?, 'test.Csv')

    refute @client.send(:csv_file?, 'test.txt')
    refute @client.send(:csv_file?, 'test.json')
    refute @client.send(:csv_file?, 'test')
  end

  def test_dataset_files_with_json_parse_error
    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/data/owner/dataset')
      .to_return(status: 200, body: 'invalid json')

    assert_raises(Kaggle::ParseError) do
      @client.dataset_files('owner', 'dataset')
    end
  end

  def test_parse_csv_with_encoding_issues
    csv_file = Tempfile.new(['test', '.csv'])
    # Write some non-UTF8 content that might cause issues
    csv_file.write("name,description\nTest,Caf\xe9")
    csv_file.rewind

    # Should handle gracefully or raise ParseError
    begin
      result = @client.parse_csv_to_json(csv_file.path)
      assert_kind_of Array, result
    rescue Kaggle::ParseError
      # This is acceptable behavior for malformed CSV
    end
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_initialization_validates_required_credentials
    ENV.delete('KAGGLE_USERNAME')
    ENV.delete('KAGGLE_KEY')

    error = assert_raises(Kaggle::AuthenticationError) do
      Kaggle::Client.new
    end

    assert_equal 'Username and API key are required (or set cache_only: true for cache-only access)', error.message
  end

  def test_initialization_creates_directories
    temp_download = Dir.mktmpdir
    temp_cache = Dir.mktmpdir

    # Remove directories to test creation
    FileUtils.rm_rf(temp_download)
    FileUtils.rm_rf(temp_cache)

    Kaggle::Client.new(
      username: 'user',
      api_key: 'key',
      download_path: temp_download,
      cache_path: temp_cache
    )

    assert Dir.exist?(temp_download), 'Download directory should be created'
    assert Dir.exist?(temp_cache), 'Cache directory should be created'
  ensure
    FileUtils.rm_rf(temp_download) if temp_download && Dir.exist?(temp_download)
    FileUtils.rm_rf(temp_cache) if temp_cache && Dir.exist?(temp_cache)
  end
end
