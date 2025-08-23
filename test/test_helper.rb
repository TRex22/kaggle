require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  minimum_coverage 70
end

require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest/focus'
require 'webmock/minitest'
require 'mocha/minitest'
require 'timecop'
require 'pry'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require_relative '../lib/kaggle'

WebMock.disable_net_connect!(allow_localhost: true)

class Minitest::Test
  def setup
    WebMock.reset!
    Timecop.return
  end
  
  def teardown
    WebMock.reset!
    Timecop.return
  end
end