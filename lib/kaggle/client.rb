module Kaggle
  class Client
    include HTTParty

    base_uri Constants::BASE_URL

    attr_reader :username, :api_key, :download_path, :cache_path, :timeout, :cache_only

    def initialize(username: nil, api_key: nil, credentials_file: nil, download_path: nil, cache_path: nil,
                   timeout: nil, cache_only: false)
      load_credentials(username, api_key, credentials_file)
      @download_path = download_path || Constants::DEFAULT_DOWNLOAD_PATH
      @cache_path = cache_path || Constants::DEFAULT_CACHE_PATH
      @timeout = timeout || Constants::DEFAULT_TIMEOUT
      @cache_only = cache_only

      unless cache_only || (valid_credential?(@username) && valid_credential?(@api_key))
        raise AuthenticationError,
              'Username and API key are required (or set cache_only: true for cache-only access)'
      end

      ensure_directories_exist
      setup_httparty_options unless cache_only
    end

    def download_dataset(dataset_owner, dataset_name, options = {})
      dataset_path = "#{dataset_owner}/#{dataset_name}"

      # Check cache first for parsed data
      if options[:use_cache] && options[:parse_csv]
        cache_key = generate_cache_key(dataset_path)
        return load_from_cache(cache_key) if cached_file_exists?(cache_key)
      end

      # Check if we already have extracted files for this dataset
      extracted_dir = get_extracted_dir(dataset_path)
      if options[:use_cache] && Dir.exist?(extracted_dir) && !Dir.empty?(extracted_dir)
        return handle_existing_dataset(extracted_dir, options)
      end

      # If cache_only mode and no cached data found, return nil or raise based on force_cache option
      if @cache_only
        if options[:force_cache]
          raise CacheNotFoundError, "Dataset '#{dataset_path}' not found in cache and force_cache is enabled"
        else
          return nil # Gracefully return nil when cache_only but not forced
        end
      end

      # Download the zip file
      response = authenticated_request(:get, "#{Constants::DATASET_ENDPOINTS[:download]}/#{dataset_path}")

      raise DownloadError, "Failed to download dataset: #{response.message}" unless response.success?

      # Save zip file
      zip_file = save_zip_file(dataset_path, response.body)

      # Extract zip file
      extract_zip_file(zip_file, extracted_dir)

      # Clean up zip file
      File.delete(zip_file) if File.exist?(zip_file)

      # Handle the extracted files
      result = handle_extracted_dataset(extracted_dir, options)

      # Cache parsed CSV data if requested
      if options[:use_cache] && options[:parse_csv] && (result.is_a?(Hash) || result.is_a?(Array))
        cache_key = generate_cache_key(dataset_path)
        cache_parsed_data(cache_key, result)
      end

      result
    end

    def dataset_files(dataset_owner, dataset_name)
      dataset_path = "#{dataset_owner}/#{dataset_name}"
      response = authenticated_request(:get, "#{Constants::DATASET_ENDPOINTS[:files]}/#{dataset_path}")

      raise DatasetNotFoundError, "Dataset not found or accessible: #{dataset_path}" unless response.success?

      Oj.load(response.body)
    rescue Oj::ParseError => e
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

    def valid_credential?(credential)
      credential && !credential.to_s.strip.empty?
    end

    def load_credentials(username, api_key, credentials_file)
      # Try provided credentials file first
      if credentials_file && File.exist?(credentials_file)
        credentials = load_credentials_from_file(credentials_file)
        @username = username || credentials['username']
        @api_key = api_key || credentials['key']
      # Try default kaggle.json file if no explicit credentials
      elsif !username && !api_key && File.exist?(Constants::DEFAULT_CREDENTIALS_FILE)
        credentials = load_credentials_from_file(Constants::DEFAULT_CREDENTIALS_FILE)
        @username = credentials['username']
        @api_key = credentials['key']
      else
        # Fall back to environment variables
        @username = username || ENV['KAGGLE_USERNAME']
        @api_key = api_key || ENV['KAGGLE_KEY']
      end
    end

    def load_credentials_from_file(file_path)
      content = File.read(file_path)
      Oj.load(content)
    rescue Oj::ParseError => e
      raise AuthenticationError, "Invalid credentials file format: #{e.message}"
    rescue StandardError => e
      raise AuthenticationError, "Failed to read credentials file: #{e.message}"
    end

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
    rescue Timeout::Error, Net::ReadTimeout, Net::OpenTimeout
      raise Error, 'Request timed out'
    rescue StandardError => e
      raise Error, "Request failed: #{e.message}"
    end

    def get_extracted_dir(dataset_path)
      dir_name = dataset_path.gsub('/', '_')
      File.join(@download_path, dir_name)
    end

    def save_zip_file(dataset_path, content)
      filename = "#{dataset_path.gsub('/', '_')}.zip"
      file_path = File.join(@download_path, filename)

      File.open(file_path, 'wb') do |file|
        file.write(content)
      end

      file_path
    end

    def extract_zip_file(zip_file_path, extract_to_dir)
      FileUtils.mkdir_p(extract_to_dir)

      Zip::File.open(zip_file_path) do |zip_file|
        zip_file.each do |entry|
          extract_path = File.join(extract_to_dir, entry.name)

          if entry.directory?
            # Create directory
            FileUtils.mkdir_p(extract_path)
          else
            # Create parent directory if it doesn't exist
            parent_dir = File.dirname(extract_path)
            FileUtils.mkdir_p(parent_dir) unless Dir.exist?(parent_dir)

            # Extract file manually to avoid path issues
            File.open(extract_path, 'wb') do |f|
              f.write entry.get_input_stream.read
            end
          end
        end
      end
    rescue Zip::Error => e
      raise DownloadError, "Failed to extract zip file: #{e.message}"
    end

    def handle_existing_dataset(extracted_dir, options)
      if options[:parse_csv]
        csv_files = find_csv_files(extracted_dir)
        return parse_csv_files_to_json(csv_files) unless csv_files.empty?
      end

      extracted_dir
    end

    def handle_extracted_dataset(extracted_dir, options)
      if options[:parse_csv]
        csv_files = find_csv_files(extracted_dir)
        unless csv_files.empty?
          parsed_data = parse_csv_files_to_json(csv_files)
          return parsed_data
        end
      end

      extracted_dir
    end

    def find_csv_files(directory)
      Dir.glob(File.join(directory, '**', '*.csv'))
    end

    def parse_csv_files_to_json(csv_files)
      result = {}

      csv_files.each do |csv_file|
        file_name = File.basename(csv_file, '.csv')
        result[file_name] = parse_csv_to_json(csv_file)
      end

      # If there's only one CSV file, return its data directly
      result.length == 1 ? result.values.first : result
    end

    def generate_cache_key(dataset_path)
      "#{dataset_path.gsub('/', '_')}_parsed.json"
    end

    def cached_file_exists?(cache_key)
      File.exist?(File.join(@cache_path, cache_key))
    end

    def load_from_cache(cache_key)
      cache_file_path = File.join(@cache_path, cache_key)
      Oj.load(File.read(cache_file_path))
    rescue Oj::ParseError => e
      raise ParseError, "Failed to parse cached data: #{e.message}"
    end

    def cache_parsed_data(cache_key, data)
      cache_file_path = File.join(@cache_path, cache_key)
      File.write(cache_file_path, Oj.dump(data, mode: :compat, indent: 2))
    end

    def csv_file?(file_path)
      File.extname(file_path).downcase == '.csv'
    end
  end
end
