require 'test_helper'

class Kaggle::ConstantsTest < Minitest::Test
  def test_base_url_is_correct
    assert_equal 'https://www.kaggle.com/api/v1', Kaggle::Constants::BASE_URL
  end

  def test_default_paths_are_set
    assert_equal './downloads', Kaggle::Constants::DEFAULT_DOWNLOAD_PATH
    assert_equal './cache', Kaggle::Constants::DEFAULT_CACHE_PATH
  end

  def test_default_values_are_reasonable
    assert_equal 30, Kaggle::Constants::DEFAULT_TIMEOUT
  end

  def test_supported_formats_includes_csv_and_json
    assert_includes Kaggle::Constants::SUPPORTED_FORMATS, 'csv'
    assert_includes Kaggle::Constants::SUPPORTED_FORMATS, 'json'
    assert_equal 2, Kaggle::Constants::SUPPORTED_FORMATS.length
  end

  def test_dataset_endpoints_are_defined
    endpoints = Kaggle::Constants::DATASET_ENDPOINTS

    assert_equal '/datasets/view', endpoints[:view]
    assert_equal '/datasets/download', endpoints[:download]
    assert_equal '/datasets/data', endpoints[:files]
  end

  def test_required_headers_are_set
    headers = Kaggle::Constants::REQUIRED_HEADERS

    assert_equal 'Kaggle Ruby Client/0.0.1', headers['User-Agent']
    assert_equal 'application/json', headers['Accept']
  end

  def test_constants_are_frozen
    assert Kaggle::Constants::SUPPORTED_FORMATS.frozen?
    assert Kaggle::Constants::DATASET_ENDPOINTS.frozen?
    assert Kaggle::Constants::REQUIRED_HEADERS.frozen?
  end
end
