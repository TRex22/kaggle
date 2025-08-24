module Kaggle
  module Constants
    BASE_URL = 'https://www.kaggle.com/api/v1'
    
    DEFAULT_DOWNLOAD_PATH = './downloads'
    DEFAULT_CACHE_PATH = './cache'
    DEFAULT_CREDENTIALS_FILE = './kaggle.json'
    DEFAULT_TIMEOUT = 30
    
    SUPPORTED_FORMATS = %w[csv json].freeze
    
    DATASET_ENDPOINTS = {
      view: '/datasets/view',
      download: '/datasets/download',
      files: '/datasets/data'
    }.freeze
    
    REQUIRED_HEADERS = {
      'User-Agent' => 'Kaggle Ruby Client/0.0.1',
      'Accept' => 'application/json'
    }.freeze
  end
end