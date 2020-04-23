# Changelog
All notable changes to this project will be documented in this file

## [2.0.0] - 2020-04-16
### Changed
- Depend on `aggregate` version `~> 1.3`, which allows a `datetime_formatter` to be specified.
- Use the `datetime_formatter` to specify millisecond precision when formatting aggregate datetimes to be stored in ES.
- When a `Time` is passed in to a `QueryString` or `MatchCondition`, use the same format as specified by `datetime_formatter` to guarantee it is compatible the timestamps stored in ES.

## [1.0.1] - 2020-03-02
### Added
- Documentation for best practices for using/querying `aggregate_has_many` fields.
- Test coverage for querying `aggregate_has_many` fields.

## [1.0.0] - 2020-01-13
### Added
- Added initial entry in ChangeLog (see README at this point for gem details)
- Indicate a default `missing` value for aggregations when documents are missing the expected aggregation term.
- Querying for records can now filter for fields that have missing values (`nil` or `[]`)

### Changed
- Updated ruby version from `2.4.2` to `2.6.1`
