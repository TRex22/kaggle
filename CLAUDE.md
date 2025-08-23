# Claude Assistant Documentation

This file documents how Claude helped develop this Ruby gem and provides guidance for future development.

## Development History

This Kaggle Ruby gem was created with assistance from Claude (Sonnet 4) on 2025-08-23. The development process followed established Ruby gem conventions and best practices.

## Architecture Decisions

### 1. Gem Structure
- Followed standard Ruby gem conventions based on successful gems like `url_categorise` and `luno`
- Used modular architecture with separate modules for constants, client logic, and error handling
- Implemented comprehensive test coverage using Minitest

### 2. API Design
- Used HTTParty for HTTP client functionality due to its simplicity and Ruby idioms
- Implemented authentication via basic auth with username/API key
- Added configurable paths for downloads and caching to support different deployment scenarios

### 3. Error Handling
- Created specific error classes inheriting from base `Kaggle::Error`
- Implemented graceful degradation for network and parsing failures
- Added comprehensive validation for user inputs

### 4. Testing Strategy
- Used Minitest with WebMock for HTTP request stubbing
- Included test coverage reporting with SimpleCov (70% minimum)
- Added comprehensive test helpers and fixtures

## Key Implementation Notes

### Authentication
The gem supports two authentication methods:
1. Environment variables (`KAGGLE_USERNAME`, `KAGGLE_KEY`)
2. Explicit parameters during client initialization

### Caching Strategy
- Simple file-based caching for parsed CSV data
- Cache keys generated from dataset paths
- Optional cache usage controlled by method parameters

### CSV Parsing
- Uses Ruby's built-in CSV library for reliability
- Converts CSV to JSON array of hashes (row objects)
- Includes comprehensive error handling for malformed files

## Commands for Development

### Setup
```bash
bin/setup                  # Install dependencies
```

### Testing
```bash
rake test                  # Run all tests
rake test TEST=specific    # Run specific test file
```

### Console
```bash
bin/console               # Interactive Ruby console with gem loaded
```

### Linting
```bash
# Note: No specific linter configured yet - add rubocop in future versions
```

## Future Development Guidelines

### 1. API Expansion
When adding new Kaggle API endpoints:
- Add constants to `lib/kaggle/constants.rb`
- Add methods to `lib/kaggle/client.rb` 
- Follow existing error handling patterns
- Add comprehensive tests in `test/kaggle/`

### 2. CLI Enhancement
The CLI tool (`bin/kaggle`) can be expanded with:
- More command options and flags
- Better output formatting
- Progress indicators for large downloads
- Configuration file support

### 3. Performance Optimizations
Consider adding:
- Concurrent downloads for multiple files
- Streaming for large files
- More sophisticated caching strategies
- Connection pooling for API requests

### 4. Error Handling Improvements
- Retry logic for transient failures
- Better error messages with suggested actions
- Logging capabilities for debugging

## Common Development Patterns

### Adding New API Methods
1. Add endpoint to constants
2. Implement client method with proper error handling
3. Add comprehensive tests
4. Update CLI if user-facing
5. Document in README

### Testing Network Interactions
- Always use WebMock to stub HTTP requests
- Test both success and failure scenarios
- Include edge cases like timeouts and malformed responses
- Verify authentication headers are sent correctly

### Code Style Guidelines
- Follow Ruby community style conventions
- Use descriptive method and variable names
- Keep methods focused and single-purpose
- Include inline documentation for complex logic

## Troubleshooting

### Common Issues
1. **Authentication Failures**: Verify credentials and API key permissions
2. **Download Failures**: Check network connectivity and dataset availability
3. **Parsing Errors**: Verify file format and encoding
4. **Path Issues**: Ensure download/cache directories are writable

### Debugging
- Use `bin/console` for interactive debugging
- Enable WebMock allow_localhost for integration testing
- Use Pry for breakpoint debugging in tests

## Contributing Guidelines

When contributing to this gem:
1. Follow existing code patterns and conventions
2. Add tests for new functionality
3. Update documentation (README, CLAUDE.md)
4. Ensure backward compatibility
5. Consider performance implications

## Claude-Specific Notes

This gem was developed iteratively with Claude assistance. The AI helper was particularly useful for:
- Analyzing existing gem patterns and conventions
- Implementing comprehensive test coverage
- Creating consistent error handling patterns
- Structuring CLI tools and bin scripts

Future Claude interactions should:
- Reference this documentation for context
- Maintain existing architectural decisions
- Follow established patterns for new features
- Update this file with new insights or changes