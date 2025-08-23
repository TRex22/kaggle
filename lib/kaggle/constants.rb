module Kaggle
  module Constants
    BASE_URL = 'https://www.kaggle.com/api/v1'
    
    DEFAULT_DOWNLOAD_PATH = './downloads'
    DEFAULT_CACHE_PATH = './cache'
    DEFAULT_PAGE_SIZE = 20
    DEFAULT_TIMEOUT = 30
    
    SUPPORTED_FORMATS = %w[csv json].freeze
    
    DATASET_ENDPOINTS = {
      list: '/datasets/list',
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