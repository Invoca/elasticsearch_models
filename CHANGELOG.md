# Changelog
All notable changes to this project will be documented in this file

## [2.0.0] - 2020-04-29
### Changed
- Depend on `aggregate` version `~> 2.0`, which defaults to storing all times with millisecond precision.
- When a `Time` is passed in to a `QueryString` or `MatchCondition`, format it to use 3 decimal places (milliseconds) to guarantee it is compatible with millisecond timestamps stored in ES

## [1.0.2] - 2020-04-27
### Added
- Add `where(_ignore_unavailable: true)` example to README

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
