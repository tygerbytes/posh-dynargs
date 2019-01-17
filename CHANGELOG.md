# posh-dynargs Release History

## 0.1.0.3 - January 17, 2019

* Install module to `$Env:ProgramFiles\WindowsPowerShell\Modules`
* Don't automatically modify the user profile on choco install
* Warn user about PowerShell 5+ requirement during choco install
* Replace helper method template string with a cleaner code block.

## 0.1.0.2 - January 12, 2019

* Improve documentation

## 0.1.0.1 - January 12, 2019

* Begin documentation, with a note about perf.
* Rename `$DynamicArgumentCompleterSettings` to `$PoshDynArgsSettings`
* Add ability to time `Register-LocalArgumentCompleters` (`$PoshDynArgsSettings.EnableTiming = $true`)

## 0.1.0.0 - January 11, 2019

* Initial Release. Just a rough sketch.
