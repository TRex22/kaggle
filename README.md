# Kaggle
A Ruby client for the Kaggle API with support for datasets, competitions, models, and more. See: https://www.kaggle.com/docs/api

This is an unofficial project and still a work in progress (WIP) ... more to come soon.

## Features

- 📊 Download Kaggle datasets programmatically
- 📄 Parse CSV datasets to JSON format
- 💾 Configurable caching to avoid re-downloading
- 🔧 Flexible download and cache paths
- ⚡ Built-in error handling and validation
- 🛠️ Command-line interface for quick operations

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kaggle'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install kaggle

## Setup

You'll need Kaggle API credentials to use this gem. There are three ways to authenticate:

### Option 1: JSON File (Recommended)
1. Go to your [Kaggle account page](https://www.kaggle.com/account)
2. Click "Create New API Token" to download `kaggle.json`
3. Place the file in your project directory or specify the path

### Option 2: Environment Variables
```bash
export KAGGLE_USERNAME="yourusername"
export KAGGLE_KEY="your_api_key"
```

### Option 3: Direct Credentials
Pass credentials directly when initializing the client.

### Kaggle JSON File Format
The `kaggle.json` file downloaded from Kaggle should have this format:
```json
{
  "username": "yourusername",
  "key": "your_api_key"
}
```

## Usage

### Basic Usage

```ruby
require 'kaggle'

# Option 1: Use kaggle.json file (automatically detected)
client = Kaggle::Client.new

# Option 1b: Use custom JSON file path
client = Kaggle::Client.new(credentials_file: '/path/to/kaggle.json')

# Option 2: Use environment variables
client = Kaggle::Client.new

# Option 3: Use explicit credentials
client = Kaggle::Client.new(
  username: 'your_username',
  api_key: 'your_api_key'
)
```

### List Datasets

```ruby
# List all datasets
datasets = client.list_datasets

# Search datasets
datasets = client.list_datasets(search: 'housing')

# Paginate results
datasets = client.list_datasets(page: 2, page_size: 10)
```

### Download Datasets

```ruby
# Basic download
file_path = client.download_dataset('zillow', 'zecon')

# Download and parse CSV to JSON
data = client.download_dataset('zillow', 'zecon', parse_csv: true)

# Use caching to avoid re-downloading
data = client.download_dataset('zillow', 'zecon', 
                              parse_csv: true, 
                              use_cache: true)
```

### Custom Paths

```ruby
client = Kaggle::Client.new(
  credentials_file: '/path/to/kaggle.json',
  download_path: '/custom/downloads',
  cache_path: '/custom/cache'
)
```

### Dataset Information

```ruby
# Get dataset files list
files = client.dataset_files('zillow', 'zecon')

# Parse existing CSV file
data = client.parse_csv_to_json('/path/to/file.csv')
```

## Command Line Interface

The gem includes a command-line interface:

```bash
# List datasets
kaggle list

# Search datasets
kaggle list "housing"

# Download dataset
kaggle download zillow zecon

# Download and parse CSV
kaggle download zillow zecon --parse-csv

# Use custom credentials file
kaggle download zillow zecon --credentials-file /path/to/kaggle.json

# Use custom paths
kaggle download zillow zecon --download-path /custom --cache-path /custom/cache

# Show dataset files
kaggle files zillow zecon

# Show version
kaggle --version
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `credentials_file` | `./kaggle.json` | Path to Kaggle credentials JSON file |
| `download_path` | `./downloads` | Where to save downloaded files |
| `cache_path` | `./cache` | Where to cache parsed data |
| `timeout` | `30` | HTTP request timeout in seconds |
| `use_cache` | `false` | Use cached parsed data when available |
| `parse_csv` | `false` | Automatically parse CSV files to JSON |

## Error Handling

The gem includes specific error types:

```ruby
begin
  client.download_dataset('invalid', 'dataset')
rescue Kaggle::AuthenticationError
  puts "Invalid credentials"
rescue Kaggle::DatasetNotFoundError
  puts "Dataset not found"
rescue Kaggle::DownloadError
  puts "Download failed"
rescue Kaggle::ParseError
  puts "Failed to parse data"
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Tests

To run tests execute:

    $ rake test

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/kaggle. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Kaggle project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/yourusername/kaggle/blob/main/CODE_OF_CONDUCT.md).
