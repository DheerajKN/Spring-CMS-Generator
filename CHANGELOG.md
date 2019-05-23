# Changelog

All notable changes to this project will be documented in this file.

## [Releases]

## [1.1.0] - 2019-05-23

### Added

- Optimized Code for Better Processing of the system
- Better logs for easy changes

### Changed

- Now no need to run Ctrl+A and Ctrl+I to format xml file on --pluginCodeGen run
- Now all the dependencies will be added at the top for better visibility.
- Now user can know which set of dependencies are added for which extension

## [1.0.7] - 2019-05-21

### Added

- Added contextual changes that got overlooked during development.
- Important Deployment steps are also added for different packaging types.
- Also in --pluginCodeGen now user will know what all files are being generated or modified.

## [1.0.5] - 2019-05-02

### Added

- Added contextual changes that got overlooked during development.
- Aspect Bug Resolved

### Changed

- Resolved bugs that provided improper results due to `sed`
- Some text were missing, which are now added

## [1.0.4] - 2019-04-23

### Added

- Functions for code reusability
- Able to add relations from one entity to another when m flag is selected.
- File name used passed after [c | m | s] flag can be of any style but it's first letter
  will be capitalized by the code
- CHANGELOG.md
- Added Badges

### Changed

- Fetching javaVariable or dbVariable can be done via functions
- RepoCode now is variablized for better control.
- Now Folder creation command will be based on each use case instead of creating all the folders at once.

## [1.0.0] - 2019-04-18

### Added

- Initial Commit
- Documentation of the project
- MIT License .md

### Changed

- Understanable Error Comments for better debugging.

### Removed

- Multiple Imports from single Parent are removed to include Common Parent Imports using .\*;
