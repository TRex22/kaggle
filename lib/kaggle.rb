require 'httparty'
require 'csv'
require 'json'
require 'fileutils'

require_relative 'kaggle/version'
require_relative 'kaggle/constants'
require_relative 'kaggle/client'

module Kaggle
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class DatasetNotFoundError < Error; end
  class DownloadError < Error; end
  class ParseError < Error; end
end