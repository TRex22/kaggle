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

    def create_dataset(title:, dataset_id:, files:, license: 'CC0-1.0', public: false,
                       subtitle: nil, description: nil, tags: [])
      raise AuthenticationError, 'Cannot create datasets in cache_only mode' if @cache_only
      dataset_id = ensure_dataset_id_owner(dataset_id)

      warn "Creating dataset: #{dataset_id} with title: #{title}"
      warn "Public: #{public}, License: #{license}"

      prepared_files = prepare_files_for_upload(files)
      warn "Prepared files for upload: #{prepared_files.map { |f| f[:name] }}"

      metadata = build_create_request_payload(title: title,
                                              dataset_id: dataset_id,
                                              license: license,
                                              public: public,
                                              files: prepared_files,
                                              subtitle: subtitle,
                                              description: description,
                                              tags: tags)
      warn "Metadata generated: #{metadata}"

      response = upload_via_rest(metadata: metadata, files: prepared_files)

      warn "Create dataset response status: #{response.code}"
      warn "Create dataset response headers: #{response.headers}"
      warn "Create dataset response body: #{response.body}"

      unless response.success?
        error_msg = begin
          error_data = Oj.load(response.body)
          error_data['message'] || response.message
        rescue
          response.message
        end
        raise Error, "Failed to create dataset: #{error_msg}"
      end

      result = Oj.load(response.body)
      warn "Successfully created dataset: #{result}"
      result
    rescue Oj::ParseError => e
      raise ParseError, "Failed to parse create dataset response: #{e.message}"
    end

    def create_dataset_version(dataset_id:, files:, version_notes:, subtitle: nil, description: nil,
                               tags: [], delete_old_versions: false)
      raise AuthenticationError, 'Cannot create dataset versions in cache_only mode' if @cache_only
      dataset_id = ensure_dataset_id_owner(dataset_id)

      warn "Creating dataset version for: #{dataset_id}"
      warn "Version notes: #{version_notes}"

      owner_slug, dataset_slug = dataset_id.split('/')
      prepared_files = prepare_files_for_upload(files)
      warn "Prepared files for version upload: #{prepared_files.map { |f| f[:name] }}"

      metadata = build_version_request_payload(owner_slug: owner_slug,
                                               dataset_slug: dataset_slug,
                                               version_notes: version_notes,
                                               subtitle: subtitle,
                                               description: description,
                                               tags: tags,
                                               delete_old_versions: delete_old_versions)
      warn "Version metadata generated: #{metadata}"

      response = upload_version_via_rest(metadata: metadata, files: prepared_files)

      warn "Create dataset version response status: #{response.code}"
      warn "Create dataset version response headers: #{response.headers}"
      warn "Create dataset version response body: #{response.body}"

      unless response.success?
        error_msg = begin
          error_data = Oj.load(response.body)
          error_data['message'] || response.message
        rescue
          response.message
        end
        raise Error, "Failed to create dataset version: #{error_msg}"
      end

      result = Oj.load(response.body)
      warn "Successfully queued dataset version: #{result}"
      result
    rescue Oj::ParseError => e
      raise ParseError, "Failed to parse create dataset version response: #{e.message}"
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

    def prepare_files_for_upload(files)
      raise Error, 'Files must be provided as an array of paths' unless files.is_a?(Array)

      files.map do |entry|
        build_file_info(entry)
      end
    end

    def build_file_info(entry)
      info =
        case entry
        when String
          { path: entry }
        when Hash
          entry.transform_keys(&:to_sym)
        else
          raise Error, "Invalid file entry: #{entry.inspect}"
        end

      path = info[:path]
      raise Error, "File does not exist: #{path}" unless path && File.exist?(path)

      {
        name: info[:name] || File.basename(path),
        path: path
      }
    end

    def build_create_request_payload(title:, dataset_id:, license:, public:, files:, subtitle:, description:,
                                     tags: [])
      owner, slug = dataset_id.split('/')
      {
        owner_slug: owner,
        slug: slug,
        title: title,
        license_name: license,
        subtitle: subtitle || truncate_subtitle(title),
        description: sanitize_description(description || title),
        is_private: !public,
        category_ids: tags || [],
        resources: files.map { |file| { path: File.basename(file[:path]) } }
      }
    end

    def build_version_request_payload(owner_slug:, dataset_slug:, version_notes:, subtitle:, description:, tags: [],
                                      delete_old_versions: false)
      {
        owner_slug: owner_slug,
        dataset_slug: dataset_slug,
        body: {
          version_notes: version_notes,
          subtitle: subtitle,
          description: sanitize_description(description || ''),
          delete_old_versions: delete_old_versions,
          category_ids: tags || []
        }
      }
    end

    # REST upload helpers --------------------------------------------------

    def upload_via_rest(metadata:, files: [])
      warn "Starting REST upload for dataset: #{metadata[:owner_slug]}/#{metadata[:slug]}"
      new_files = files.map do |file_info|
        token = upload_blob(file_info)
        build_rest_file(token)
      end

      payload = metadata.merge(files: new_files)
      warn "REST payload prepared: #{payload}"

      options = {
        body: Oj.dump(camelize_keys(payload), mode: :compat),
        headers: {
          'Content-Type' => 'application/json'
        }
      }

      authenticated_request(:post, '/datasets/create/new', options)
    end

    def upload_version_via_rest(metadata:, files: [])
      warn "Starting REST version upload for dataset: #{metadata[:owner_slug]}/#{metadata[:dataset_slug]}"

      new_files = files.map do |file_info|
        token = upload_blob(file_info)
        build_rest_file(token)
      end

      version_body = metadata[:body].merge(files: new_files)
      warn "Version payload (pre-camelize): #{version_body}"

      options = {
        body: Oj.dump(camelize_keys(version_body), mode: :compat),
        headers: {
          'Content-Type' => 'application/json'
        }
      }

      endpoint = "/datasets/create/version/#{metadata[:owner_slug]}/#{metadata[:dataset_slug]}"
      authenticated_request(:post, endpoint, options)
    end

    def upload_blob(file_info)
      warn "Starting blob upload for #{file_info[:name]}"
      timestamp = File.mtime(file_info[:path]).to_i
      body = {
        type: 'DATASET',
        name: file_info[:name],
        content_length: File.size(file_info[:path]),
        last_modified_epoch_seconds: timestamp
      }

      response = authenticated_request(:post, '/blobs/upload',
                                       body: Oj.dump(body, mode: :compat),
                                       headers: {
                                         'Content-Type' => 'application/json'
                                       })

      raise Error, "Failed to start blob upload: #{response.message}" unless response.success?

      data = Oj.load(response.body)
      upload_url = data['createUrl']
      token = data['token']

      upload_file_contents(upload_url, file_info[:path])

      token
    rescue Oj::ParseError => e
      raise ParseError, "Failed to parse blob upload response: #{e.message}"
    end

    def upload_file_contents(url, path)
      warn "Uploading file contents to blob storage: #{url}"
      File.open(path, 'rb') do |file|
        response = HTTParty.put(url, body: file.read,
                                     headers: {
                                       'Content-Type' => 'application/octet-stream'
                                     })
        raise Error, "Failed to upload file contents: #{response.message}" unless response.success?
      end
    rescue StandardError => e
      raise Error, "File upload failed: #{e.message}"
    end

    def build_rest_file(token)
      { token: token }
    end

    def truncate_subtitle(text)
      text.length < 20 ? text.ljust(20, ' ') : text[0, 80]
    end

    def sanitize_description(text)
      text.strip.empty? ? 'Dataset created via Kaggle Ruby Client' : text
    end

    def ensure_dataset_id_owner(dataset_id)
      return dataset_id if dataset_id.include?('/')

      raise AuthenticationError, 'Username is required to infer dataset owner' unless @username

      "#{@username}/#{dataset_id}"
    end

    def camelize_keys(value)
      case value
      when Array
        value.map { |item| camelize_keys(item) }
      when Hash
        value.each_with_object({}) do |(key, val), result|
          result[camelize(key)] = camelize_keys(val)
        end
      else
        value
      end
    end

    def camelize(key)
      return key unless key.respond_to?(:to_s)
      string_key = key.to_s
      parts = string_key.split('_')
      return parts.first if parts.length <= 1

      head = parts.shift
      camel_tail = parts.map { |part| part.capitalize }
      ([head] + camel_tail).join
    end
  end
end
