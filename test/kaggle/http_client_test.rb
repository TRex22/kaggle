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
    stub_request(:get, "https://www.kaggle.com/api/v1/test-endpoint")
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

    response = @client.send(:authenticated_request, :get, "/test-endpoint")
    
    assert response.success?
    assert_includes response.body, 'success'
  end

  def test_authenticated_request_handles_timeout_error
    @client.class.expects(:get).raises(Timeout::Error)
    
    error = assert_raises(Kaggle::Error) do
      @client.send(:authenticated_request, :get, "/test-endpoint")
    end
    
    assert_equal 'Request timed out', error.message
  end

  def test_authenticated_request_handles_general_network_errors
    @client.class.expects(:get).raises(SocketError.new('Connection refused'))
    
    error = assert_raises(Kaggle::Error) do
      @client.send(:authenticated_request, :get, "/test-endpoint")
    end
    
    assert_includes error.message, 'Request failed: Connection refused'
  end

  def test_authenticated_request_with_post_method
    stub_request(:post, "https://www.kaggle.com/api/v1/test-endpoint")
      .with(
        headers: {
          'Accept' => 'application/json',
          'Authorization' => /Basic/,
          'User-Agent' => 'Kaggle Ruby Client/0.0.1'
        },
        body: hash_including(data: 'test')
      )
      .to_return(status: 201, body: '{"created": true}')

    response = @client.send(:authenticated_request, :post, "/test-endpoint", { body: { data: 'test' } })
    
    assert response.success?
    assert_includes response.body, 'created'
  end

  def test_authenticated_request_with_custom_options
    stub_request(:get, "https://www.kaggle.com/api/v1/test-endpoint")
      .with(query: hash_including(param: 'value'))
      .to_return(status: 200, body: '{"data": "response"}')

    response = @client.send(:authenticated_request, :get, "/test-endpoint", { query: { param: 'value' } })
    
    assert response.success?
    assert_includes response.body, 'response'
  end

  def test_list_datasets_with_successful_response
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/list?page=1&size=20")
      .to_return(
        status: 200,
        body: '{"datasets": [{"name": "test-dataset", "owner": "test-user"}]}',
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @client.list_datasets
    
    assert_equal({ 'datasets' => [{ 'name' => 'test-dataset', 'owner' => 'test-user' }] }, result)
  end

  def test_list_datasets_with_http_error
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/list?page=1&size=20")
      .to_return(status: 500, body: 'Internal Server Error')

    error = assert_raises(Kaggle::Error) do
      @client.list_datasets
    end
    
    assert_includes error.message, 'Failed to list datasets'
  end

  def test_dataset_files_with_successful_response
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/data/owner/dataset")
      .to_return(
        status: 200,
        body: '{"files": [{"name": "data.csv", "size": 1024}]}',
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @client.dataset_files('owner', 'dataset')
    
    assert_equal({ 'files' => [{ 'name' => 'data.csv', 'size' => 1024 }] }, result)
  end

  def test_dataset_files_with_not_found_error
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/data/owner/dataset")
      .to_return(status: 404, body: 'Dataset not found')

    error = assert_raises(Kaggle::DatasetNotFoundError) do
      @client.dataset_files('owner', 'dataset')
    end
    
    assert_includes error.message, 'Dataset not found or accessible: owner/dataset'
  end

  def test_download_dataset_with_successful_response
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/download/owner/dataset")
      .to_return(
        status: 200,
        body: 'mock zip file content',
        headers: { 'Content-Type' => 'application/zip' }
      )

    Timecop.freeze(Time.at(1234567890)) do
      result = @client.download_dataset('owner', 'dataset')
      
      assert_kind_of String, result
      assert_includes result, './downloads'
      assert_includes result, 'owner_dataset_1234567890.zip'
      assert File.exist?(result)
      assert_equal 'mock zip file content', File.read(result)
    end
  end

  def test_download_dataset_with_http_error
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/download/owner/dataset")
      .to_return(status: 403, body: 'Access denied')

    error = assert_raises(Kaggle::DownloadError) do
      @client.download_dataset('owner', 'dataset')
    end
    
    assert_includes error.message, 'Failed to download dataset'
  end
end