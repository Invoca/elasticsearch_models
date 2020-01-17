# Changelog
All notable changes to this project will be documented in this file
## [1.0.0] - 2020-01-13
### Added
- Added initial entry in ChangeLog (see README at this point for gem details)
- Indicate a default `missing` value for aggregations when documents are missing the expected aggregation term.
- Querying for records can now filter for fields that have missing values (`nil` or `[]`)

### Changed
- Updated ruby version from `2.4.2` to `2.6.1`
