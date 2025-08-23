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
    dataset_path = 'test-owner/test-dataset'
    csv_content = "name,age,city\nJohn,30,NYC\nJane,25,LA"
    
    expected_data = [
      { 'name' => 'John', 'age' => '30', 'city' => 'NYC' },
      { 'name' => 'Jane', 'age' => '25', 'city' => 'LA' }
    ]
    
    # Test cache functionality directly
    cache_key = @client.send(:generate_cache_key, dataset_path)
    
    # Initially no cache should exist
    refute @client.send(:cached_file_exists?, cache_key)
    
    # Cache some data
    @client.send(:cache_parsed_data, cache_key, expected_data)
    
    # Verify cache file was created
    assert @client.send(:cached_file_exists?, cache_key)
    
    # Load from cache
    cached_result = @client.send(:load_from_cache, cache_key)
    assert_equal expected_data, cached_result
  end

  def test_dataset_listing_and_file_inspection_workflow
    # Mock dataset list API
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/list?page=1&size=20")
      .to_return(
        status: 200,
        body: '{"datasets":[{"name":"housing-data","owner":"realestate","description":"Housing price data"},{"name":"stock-prices","owner":"finance","description":"Stock market data"}]}'
      )
    
    # Mock dataset files API
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/data/realestate/housing-data")
      .to_return(
        status: 200,
        body: '{"files":[{"name":"train.csv","size":1048576},{"name":"test.csv","size":524288},{"name":"README.md","size":2048}]}'
      )
    
    # Test workflow: list datasets, then inspect specific dataset
    datasets = @client.list_datasets
    refute_nil datasets, "Datasets response should not be nil"
    refute_nil datasets['datasets'], "Datasets array should not be nil"
    assert_equal 2, datasets['datasets'].length
    assert_equal 'housing-data', datasets['datasets'][0]['name']
    
    # Inspect files for the first dataset
    files = @client.dataset_files('realestate', 'housing-data')
    assert_equal 3, files['files'].length
    assert_equal 'train.csv', files['files'][0]['name']
    assert_equal 1048576, files['files'][0]['size']
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

  def test_search_and_pagination_workflow
    # Test search functionality
    search_term = 'finance'
    
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/list?page=1&search=#{search_term}&size=10")
      .to_return(
        status: 200,
        body: '{"datasets":[{"name":"stock-data","owner":"finance-corp"},{"name":"crypto-prices","owner":"blockchain-data"}],"pagination":{"page":1,"total_pages":3,"total_count":25}}'
      )
    
    # Test pagination
    stub_request(:get, "https://www.kaggle.com/api/v1/datasets/list?page=2&size=10")
      .to_return(
        status: 200,
        body: '{"datasets":[{"name":"housing-market","owner":"real-estate"}],"pagination":{"page":2,"total_pages":3,"total_count":25}}'
      )
    
    # Search for finance-related datasets
    search_results = @client.list_datasets(search: search_term, page_size: 10)
    refute_nil search_results, "Search results should not be nil"
    refute_nil search_results['datasets'], "Search results datasets array should not be nil"
    assert_equal 2, search_results['datasets'].length
    assert_equal 'stock-data', search_results['datasets'][0]['name']
    
    # Get second page
    page2_results = @client.list_datasets(page: 2, page_size: 10)
    assert_equal 1, page2_results['datasets'].length
    assert_equal 'housing-market', page2_results['datasets'][0]['name']
  end

  def test_file_format_detection_and_parsing_workflow
    # Create various file types to test detection
    csv_file = create_test_file('test.csv', "name,age\nJohn,30")
    txt_file = create_test_file('test.txt', "Just plain text")
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
end