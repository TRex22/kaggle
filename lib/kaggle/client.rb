module Kaggle
  class Client
    include HTTParty
    
    base_uri Constants::BASE_URL
    
    attr_reader :username, :api_key, :download_path, :cache_path, :timeout
    
    def initialize(username: nil, api_key: nil, download_path: nil, cache_path: nil, timeout: nil)
      @username = username || ENV['KAGGLE_USERNAME']
      @api_key = api_key || ENV['KAGGLE_KEY']
      @download_path = download_path || Constants::DEFAULT_DOWNLOAD_PATH
      @cache_path = cache_path || Constants::DEFAULT_CACHE_PATH
      @timeout = timeout || Constants::DEFAULT_TIMEOUT
      
      raise AuthenticationError, 'Username and API key are required' unless @username && @api_key
      
      ensure_directories_exist
      setup_httparty_options
    end
    
    def download_dataset(dataset_owner, dataset_name, options = {})
      dataset_path = "#{dataset_owner}/#{dataset_name}"
      cache_key = generate_cache_key(dataset_path)
      
      if options[:use_cache] && cached_file_exists?(cache_key)
        return load_from_cache(cache_key)
      end
      
      response = authenticated_request(:get, "#{Constants::DATASET_ENDPOINTS[:download]}/#{dataset_path}")
      
      unless response.success?
        raise DownloadError, "Failed to download dataset: #{response.message}"
      end
      
      downloaded_file = save_downloaded_file(dataset_path, response.body)
      
      if options[:parse_csv] && csv_file?(downloaded_file)
        parsed_data = parse_csv_to_json(downloaded_file)
        cache_parsed_data(cache_key, parsed_data) if options[:use_cache]
        return parsed_data
      end
      
      downloaded_file
    end
    
    def list_datasets(options = {})
      params = build_list_params(options)
      response = authenticated_request(:get, Constants::DATASET_ENDPOINTS[:list], query: params)
      
      unless response.success?
        raise Error, "Failed to list datasets: #{response.message}"
      end
      
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise ParseError, "Failed to parse response: #{e.message}"
    end
    
    def dataset_files(dataset_owner, dataset_name)
      dataset_path = "#{dataset_owner}/#{dataset_name}"
      response = authenticated_request(:get, "#{Constants::DATASET_ENDPOINTS[:files]}/#{dataset_path}")
      
      unless response.success?
        raise DatasetNotFoundError, "Dataset not found or accessible: #{dataset_path}"
      end
      
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise ParseError, "Failed to parse dataset files response: #{e.message}"
    end
    
    def parse_csv_to_json(file_path)
      raise Error, "File does not exist: #{file_path}" unless File.exist?(file_path)
      raise Error, "File is not a CSV: #{file_path}" unless csv_file?(file_path)
      
      data = []
      CSV.foreach(file_path, headers: true) do |row|
        data << row.to_hash
      end
      
      data
    rescue CSV::MalformedCSVError => e
      raise ParseError, "Failed to parse CSV file: #{e.message}"
    end
    
    private
    
    def ensure_directories_exist
      FileUtils.mkdir_p(@download_path) unless Dir.exist?(@download_path)
      FileUtils.mkdir_p(@cache_path) unless Dir.exist?(@cache_path)
    end
    
    def setup_httparty_options
      self.class.default_options.merge!({
        headers: Constants::REQUIRED_HEADERS,
        timeout: @timeout,
        basic_auth: {
          username: @username,
          password: @api_key
        }
      })
    end
    
    def authenticated_request(method, endpoint, options = {})
      self.class.send(method, endpoint, options)
    rescue Net::TimeoutError
      raise Error, 'Request timed out'
    rescue => e
      raise Error, "Request failed: #{e.message}"
    end
    
    def save_downloaded_file(dataset_path, content)
      filename = "#{dataset_path.gsub('/', '_')}_#{Time.now.to_i}.zip"
      file_path = File.join(@download_path, filename)
      
      File.open(file_path, 'wb') do |file|
        file.write(content)
      end
      
      file_path
    end
    
    def generate_cache_key(dataset_path)
      "#{dataset_path.gsub('/', '_')}_parsed.json"
    end
    
    def cached_file_exists?(cache_key)
      File.exist?(File.join(@cache_path, cache_key))
    end
    
    def load_from_cache(cache_key)
      cache_file_path = File.join(@cache_path, cache_key)
      JSON.parse(File.read(cache_file_path))
    rescue JSON::ParserError => e
      raise ParseError, "Failed to parse cached data: #{e.message}"
    end
    
    def cache_parsed_data(cache_key, data)
      cache_file_path = File.join(@cache_path, cache_key)
      File.write(cache_file_path, JSON.pretty_generate(data))
    end
    
    def csv_file?(file_path)
      File.extname(file_path).downcase == '.csv'
    end
    
    def build_list_params(options)
      {
        page: options[:page] || 1,
        search: options[:search],
        sortBy: options[:sort_by],
        size: options[:page_size] || Constants::DEFAULT_PAGE_SIZE
      }.compact
    end
  end
end