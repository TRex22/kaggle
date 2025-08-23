require 'test_helper'

class KaggleTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Kaggle::VERSION
  end

  def test_module_constants_exist
    assert_equal 'https://www.kaggle.com/api/v1', Kaggle::Constants::BASE_URL
    assert_equal %w[csv json], Kaggle::Constants::SUPPORTED_FORMATS
    assert_equal 30, Kaggle::Constants::DEFAULT_TIMEOUT
  end

  def test_error_classes_inherit_from_standard_error
    assert_kind_of StandardError, Kaggle::Error.new
    assert_kind_of Kaggle::Error, Kaggle::AuthenticationError.new
    assert_kind_of Kaggle::Error, Kaggle::DatasetNotFoundError.new
    assert_kind_of Kaggle::Error, Kaggle::DownloadError.new
    assert_kind_of Kaggle::Error, Kaggle::ParseError.new
  end
end