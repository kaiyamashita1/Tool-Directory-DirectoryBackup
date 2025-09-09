rem @echo off
cd %~dp0

set /p Suffix=Input BackupDirectory Suffix

PowerShell -ExecutionPolicy Unrestricted -File ".\DirectoryBackup.ps1" -CsvFilePath ".\DirectoryBackup.csv" -Suffix %Suffix%

pause