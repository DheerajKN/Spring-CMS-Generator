# Changelog

All notable changes to this project will be documented in this file.

## [Releases]

## [1.2.7] - 2019-06-26

### Added

- Swagger plugin with dependency import and sample code snippets
- wiremock dependency
- lombok.config added to remove unwanted code coverage when using lombok annotations.
- Added DTO with javax.validations when m flag is passed
- Date datatype along with DTO validations and sql insert
- M2M mapping added

### Changed

- More data to CustomLocaleResolver to support Localization of javax.hibernate.validate annotations
- More data added to sonar-project.properties in form of sonar.exclusions
- Updated LanguageTranslationService.getTranslationLanguageData method
- Updated Internationalization Component
- OneToOne code updated

## [1.2.5] - 2019-06-26

### Added

- added --c-folder flag for `c` that helps in generating `controller` file at custom position in place of pre-defined controller folder.
- added --m-folder flag for `m` that helps in generating `model` file at custom position in place of pre-defined model folder.
- added --s-folder flag for `s` that helps in generating `service` file at custom position in place of pre-defined service folder.
- added --r-folder flag for `m` that helps in generating `repository` file at custom position in place of pre-defined repository folder.
- added --a-folder flag for `a` that helps in generating `aspect` file at custom position in place of pre-defined aspect folder.
- Added defintion for ElementType.PARAMETER inside aspect flag
- Added Internalization i18N to CMS accessible inside `--pluginCodeGen` through `internationalization` flag

## [1.1.0] - 2019-05-23

### Added

- Optimized Code for Better Processing of the system
- Better logs for easy changes
- Bugs Resolved for --pluginCodeGen oauth2 flag
- --import-sql flag to model entity which create insert sql statement and add it to import.sql file in both main and test environments present under resources folder.
- -times is an extension to --import-sql flag that will add the same insert statement n times as mentioned along with the flag under a single multLine comment in both main and test environments

### Changed

- Now user has no need to manually add essential sql files during --pluginCodeGen, script will automatically do it
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
