require 'test_helper'

class Kaggle::HttpClientTest < Minitest::Test
  def setup
    @username = 'test_user'
    @api_key = 'test_key'
    @client = Kaggle::Client.new(username: @username, api_key: @api_key)
  end

  def test_setup_httparty_options_sets_headers
    options = @client.class.default_options

    assert_equal 'Kaggle Ruby Client/0.0.1', options[:headers]['User-Agent']
    assert_equal 'application/json', options[:headers]['Accept']
    assert_equal 30, options[:timeout]
    assert_equal @username, options[:basic_auth][:username]
    assert_equal @api_key, options[:basic_auth][:password]
  end

  def test_authenticated_request_with_successful_response
    stub_request(:get, 'https://www.kaggle.com/api/v1/test-endpoint')
      .with(
        headers: {
          'Accept' => 'application/json',
          'Authorization' => /Basic/,
          'User-Agent' => 'Kaggle Ruby Client/0.0.1'
        }
      )
      .to_return(
        status: 200,
        body: '{"success": true}',
        headers: { 'Content-Type' => 'application/json' }
      )

    response = @client.send(:authenticated_request, :get, '/test-endpoint')

    assert response.success?
    assert_includes response.body, 'success'
  end

  def test_authenticated_request_handles_timeout_error
    @client.class.expects(:get).raises(Timeout::Error)

    error = assert_raises(Kaggle::Error) do
      @client.send(:authenticated_request, :get, '/test-endpoint')
    end

    assert_equal 'Request timed out', error.message
  end

  def test_authenticated_request_handles_general_network_errors
    @client.class.expects(:get).raises(SocketError.new('Connection refused'))

    error = assert_raises(Kaggle::Error) do
      @client.send(:authenticated_request, :get, '/test-endpoint')
    end

    assert_includes error.message, 'Request failed: Connection refused'
  end

  def test_authenticated_request_with_post_method
    stub_request(:post, 'https://www.kaggle.com/api/v1/test-endpoint')
      .with(
        headers: {
          'Accept' => 'application/json',
          'Authorization' => /Basic/,
          'User-Agent' => 'Kaggle Ruby Client/0.0.1'
        },
        body: hash_including(data: 'test')
      )
      .to_return(status: 201, body: '{"created": true}')

    response = @client.send(:authenticated_request, :post, '/test-endpoint', { body: { data: 'test' } })

    assert response.success?
    assert_includes response.body, 'created'
  end

  def test_authenticated_request_with_custom_options
    stub_request(:get, 'https://www.kaggle.com/api/v1/test-endpoint')
      .with(query: hash_including(param: 'value'))
      .to_return(status: 200, body: '{"data": "response"}')

    response = @client.send(:authenticated_request, :get, '/test-endpoint', { query: { param: 'value' } })

    assert response.success?
    assert_includes response.body, 'response'
  end

  def test_dataset_files_with_successful_response
    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/data/owner/dataset')
      .to_return(
        status: 200,
        body: '{"files": [{"name": "data.csv", "size": 1024}]}',
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @client.dataset_files('owner', 'dataset')

    assert_equal({ 'files' => [{ 'name' => 'data.csv', 'size' => 1024 }] }, result)
  end

  def test_dataset_files_with_not_found_error
    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/data/owner/dataset')
      .to_return(status: 404, body: 'Dataset not found')

    error = assert_raises(Kaggle::DatasetNotFoundError) do
      @client.dataset_files('owner', 'dataset')
    end

    assert_includes error.message, 'Dataset not found or accessible: owner/dataset'
  end

  def test_download_dataset_with_successful_response
    zip_content = create_test_zip_with_csv

    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/download/owner/dataset')
      .to_return(
        status: 200,
        body: zip_content,
        headers: { 'Content-Type' => 'application/zip' }
      )

    result = @client.download_dataset('owner', 'dataset')

    assert_kind_of String, result
    assert_includes result, './downloads'
    assert_includes result, 'owner_dataset'
    assert Dir.exist?(result)

    # Check that files were extracted
    csv_files = Dir.glob(File.join(result, '**', '*.csv'))
    assert csv_files.length > 0
  end

  def test_download_dataset_with_http_error
    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/download/owner/dataset')
      .to_return(status: 403, body: 'Access denied')

    error = assert_raises(Kaggle::DownloadError) do
      @client.download_dataset('owner', 'dataset')
    end

    assert_includes error.message, 'Failed to download dataset'
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
