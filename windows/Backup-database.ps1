# Get Input
Param(
    [parameter(
        HelpMessage = "The path of the directory where the backup files will be stored.",
        Mandatory = $true
    )]
    [string]
    $BackupRootDirectoryPath,

    [parameter(
        HelpMessage = "The number of days to keep the daily backups. Allowed values: [1-730]."
    )]
    [int]
    [ValidateRange(1, 730)]
    $DailyBackupRetentionDays = 15,

    [parameter(
        HelpMessage = "The name of the database to back up.",
        Mandatory = $true
    )]
    [string]
    $DatabaseName,

    [parameter(
        HelpMessage = "The path to a *.cnf file for mysql or .pg_service.conf file for postgres.",
        Mandatory = $true
    )]
    [string]
    $DatabaseServerCredentialsFilePath,

    [parameter(
        HelpMessage = "The database server resource name.",
        Mandatory = $true
    )]
    [string]
    $DatabaseServerResourceName,

    [parameter(
        HelpMessage = "The database server type. Allowed values: `"mysql`", `"postgres`"",
        Mandatory = $true
    )]
    [string]
    [ValidateSet(
        "mysql",
        "postgres"
    )]
    $DatabaseServerType,

    [parameter(
        HelpMessage = "The day of the month when the monthly backup is created. Allowed values: [1-28]."
    )]
    [int]
    [ValidateRange(1, 28)]
    $MonthlyBackupDay = 15,

    [parameter(
        HelpMessage = "The number of days to keep the monthly backups. Allowed values: [1-730]."
    )]
    [int]
    [ValidateRange(1, 730)]
    $MonthlyBackupRetentionDays = 730,

    [parameter(
        HelpMessage = "Whether or not database backup logs should be verbatim."
    )]
    [switch]
    $VerboseBackupLog,

    [parameter(
        HelpMessage = "The day of the week when the weekly backup is created. Allowed values: `"Sunday`", `"Monday`", `"Tuesday`", `"Wednesday`", `"Thursday`", `"Friday`", `"Saturday`"."
    )]
    [string]
    [ValidateSet(
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday"
    )]
    $WeeklyBackupDay = "Sunday",

    [parameter(
        HelpMessage = "The number of days to keep the weekly backups. Allowed values: [1-730]."
    )]
    [int]
    [ValidateRange(1, 730)]
    $WeeklyBackupRetentionDays = 35
)

# Define constants
Set-Variable DAILY_BACKUP_SUFFIX -Option Constant -Value "daily"
Set-Variable DATE_FORMAT -Option Constant -Value "yyyyMMdd"
Set-Variable LOG_FILE_EXTENSION -Option Constant -Value "log"
Set-Variable MONTHLY_BACKUP_SUFFIX -Option Constant -Value "monthly"
Set-Variable MYSQL_DATABASE_SERVER_TYPE -Option Constant -Value "mysql"
Set-Variable POSTGRES_DATABASE_SERVER_TYPE -Option Constant -Value "postgres"
Set-Variable SQL_FILE_EXTENSION -Option Constant -Value "sql"
Set-Variable WEEKLY_BACKUP_SUFFIX -Option Constant -Value "weekly"

# Define functions
function Show-InputParameters {

    Write-Host "$($MyInvocation.MyCommand.Name): started."

    Write-Host "- BackupRootDirectoryPath = ${BackupRootDirectoryPath}"
    Write-Host "- DailyBackupRetentionDays = ${DailyBackupRetentionDays}"
    Write-Host "- DatabaseName = ${DatabaseName}"
    Write-Host "- DatabaseServerCredentialsFilePath = ${DatabaseServerCredentialsFilePath}"
    Write-Host "- DatabaseServerResourceName = ${DatabaseServerResourceName}"
    Write-Host "- DatabaseServerType = ${DatabaseServerType}"
    Write-Host "- MonthlyBackupDay = ${MonthlyBackupDay}"
    Write-Host "- MonthlyBackupRetentionDays = ${MonthlyBackupRetentionDays}"
    Write-Host "- VerboseBackupLog = ${VerboseBackupLog}"
    Write-Host "- WeeklyBackupDay = ${WeeklyBackupDay}"
    Write-Host "- WeeklyBackupRetentionDays = ${WeeklyBackupRetentionDays}"

    Write-Host "$($MyInvocation.MyCommand.Name): completed."
}

function Confirm-InputParameters {

    Write-Host "$($MyInvocation.MyCommand.Name): started."

    # Check if the database server credentials file exists.
    if (-Not(Test-Path -Path "${DatabaseServerCredentialsFilePath}" -PathType Leaf)) {
        Write-Host "- Error: Specified database server credentials file NOT found. Aborting."
        Exit 1
    }

    # Check if backup directory exists.
    if (-Not(Test-Path -Path "${BackupRootDirectoryPath}" -PathType Container)) {
        Write-Host "- Error: Specified root backup directory NOT found. Aborting."
        Exit 1
    }

    Write-Host "$($MyInvocation.MyCommand.Name): completed."
}

function New-BackupDirectory {

    Write-Host "$($MyInvocation.MyCommand.Name): started."

    Write-Host "- Backup directory path: ${backupDirectoryPath}"

    if (Test-Path -Path "${backupDirectoryPath}" -PathType Container) {
        Write-Host "- Warning: Backup directory already exists. Skipping."
    }
    else {
        New-Item -ItemType Directory -Path ${backupDirectoryPath} | Out-Null
        Write-Host "- Backup directory created."
    }

    Write-Host "$($MyInvocation.MyCommand.Name): completed."
}

function Get-BackupBaseFilename {

    if ((Get-Date).Day -eq "${MonthlyBackupDay}") {
        $backupFilenameSuffix = "${MONTHLY_BACKUP_SUFFIX}"
    }
    elseif ((Get-Date).DayOfWeek -eq "$WeeklyBackupDay") {
        $backupFilenameSuffix = "${WEEKLY_BACKUP_SUFFIX}"
    }
    else {
        $backupFilenameSuffix = "${DAILY_BACKUP_SUFFIX}"
    }
    Write-Output  "${backupFilenamePrefix}.$(Get-Date -Format ${DATE_FORMAT}).${backupFilenameSuffix}"
}

function Backup-Database {

    Write-Host "$($MyInvocation.MyCommand.Name): started."

    Write-Host "- Backup file path: ${backupFilePath}"
    Write-Host "- Log file path: ${logFilePath}"

    # Compute verbose option based on script parameter switch.
    if ($VerboseBackupLog) {
        $verboseOption = '--verbose'
    }
    else {
        $verboseOption = ''
    }

    switch ($DatabaseServerType) {
        "$MYSQL_DATABASE_SERVER_TYPE" {
            Start-Process "C:\Program Files\MySQL\MySQL Workbench 8.0\mysqldump.exe" `
                -ArgumentList "--defaults-file=`"${DatabaseServerCredentialsFilePath}`" --compress=TRUE --default-character-set=utf8 --no-tablespaces --protocol=tcp --single-transaction=TRUE --skip-triggers ${verboseOption} `"${DatabaseName}`"" `
                -RedirectStandardError "${logFilePath}" `
                -RedirectStandardOutput "${backupFilePath}" `
                -Wait
        }
        "$POSTGRES_DATABASE_SERVER_TYPE" {
            # Overwride default service file location by setting corresponding envionment variable.
            $Env:PGSERVICEFILE = "${DatabaseServerCredentialsFilePath}"
            Start-Process "C:\Program Files\PostgreSQL\14\bin\pg_dump.exe" `
                -ArgumentList "--clean --create --if-exists --no-acl --no-owner ${verboseOption} `"service=${DatabaseServerResourceName} dbname=${DatabaseName}`"" `
                -RedirectStandardError "${logFilePath}" `
                -RedirectStandardOutput "${backupFilePath}" `
                -Wait
        }
    }

    Write-Host "$($MyInvocation.MyCommand.Name): completed."
}

function Confirm-BackupFile {

    Write-Host "$($MyInvocation.MyCommand.Name): started."

    if (Select-String `
            -Path "${backupFilePath}" `
            -Pattern '^-- (Dump completed on \d{4}-\d{2}-\d{2}\s{1,2}\d{1,2}:\d{2}:\d{2}|PostgreSQL database dump complete)$' `
            -Quiet) {
        Write-Host "- Database Backup completed successfully."
    }
    else {
        Write-Host "- Error: Database Backup failed. Aborting."
        Exit 1
    }

    Write-Host "$($MyInvocation.MyCommand.Name): completed."
}

function Remove-BackupFiles {
    Param(
        [string]$BackupFilenameSuffix,
        [int]$RetentionDays
    )

    Write-Host "- Removing ${BackupFilenameSuffix} backup files older than ${RetentionDays} days, if any..."

    Get-ChildItem "${backupDirectoryPath}\${backupFilenamePrefix}.*.${BackupFilenameSuffix}.${SQL_FILE_EXTENSION}" |
    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-${RetentionDays}) } |
    ForEach-Object {
        $file = Get-Item $_.FullName
        Write-Host "- Removing: $(${file}.Name) - Creation Date: $(${file}.CreationTime)"
        Remove-Item "${file}"
    }
}

function Invoke-BackupFileRetentionPolicy {

    Write-Host "$($MyInvocation.MyCommand.Name): started."

    Remove-BackupFiles `
        -BackupFilenameSuffix "${MONTHLY_BACKUP_SUFFIX}" `
        -RetentionDays ${MonthlyBackupRetentionDays}

    Remove-BackupFiles `
        -BackupFilenameSuffix "${WEEKLY_BACKUP_SUFFIX}" `
        -RetentionDays ${WeeklyBackupRetentionDays}

    Remove-BackupFiles `
        -BackupFilenameSuffix "${DAILY_BACKUP_SUFFIX}" `
        -RetentionDays ${DailyBackupRetentionDays}

    Write-Host "$($MyInvocation.MyCommand.Name): completed."
}

# Main Work
Write-Host "------------------------- START -------------------------"
Show-InputParameters
Confirm-InputParameters

# Compute global variables
$backupDirectoryPath = "${BackupRootDirectoryPath}\${DatabaseServerResourceName}"
$backupFilenamePrefix = "${DatabaseServerResourceName}.${DatabaseName}"
$baseFilename = "$(Get-BackupBaseFilename)"
$backupFilePath = "$backupDirectoryPath\${baseFilename}.${SQL_FILE_EXTENSION}"
$logFilePath = "$backupDirectoryPath\${baseFilename}.${LOG_FILE_EXTENSION}"

New-BackupDirectory
Backup-Database
Confirm-BackupFile
Invoke-BackupFileRetentionPolicy
Write-Host "------------------------- FINISH -------------------------"

# Exit Script
Exit 0
