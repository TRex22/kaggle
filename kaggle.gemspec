require_relative 'lib/kaggle/version'

Gem::Specification.new do |spec|
  spec.name = 'kaggle'
  spec.version = Kaggle::VERSION
  spec.authors = ['Your Name']
  spec.email = ['your.email@example.com']

  spec.summary = 'Ruby client for the Kaggle API'
  spec.description = 'A Ruby gem for interacting with the Kaggle API, including dataset downloads with caching support'
  spec.homepage = 'https://github.com/yourusername/kaggle'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'csv', '>= 3.3'
  spec.add_dependency 'fileutils', '>= 1.7'
  spec.add_dependency 'httparty', '>= 0.23'
  spec.add_dependency 'oj', '3.16.11'
  spec.add_dependency 'rubyzip', '>= 2.0'

  spec.add_development_dependency 'minitest', '~> 5.25.5'
  spec.add_development_dependency 'minitest-focus', '~> 1.4.0'
  spec.add_development_dependency 'minitest-reporters', '~> 1.7.1'
  spec.add_development_dependency 'mocha', '~> 2.4.5'
  spec.add_development_dependency 'pry', '~> 0.15.2'
  spec.add_development_dependency 'rake', '~> 13.3.0'
  spec.add_development_dependency 'simplecov', '~> 0.22.0'
  spec.add_development_dependency 'timecop', '~> 0.9.10'
  spec.add_development_dependency 'webmock', '~> 3.24.0'
end
