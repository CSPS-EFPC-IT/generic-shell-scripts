# Get Input
Param(
    [parameter(
        HelpMessage="The path of the directory where the backup files will be stored.",
        Mandatory=$true
    )]
    [string]
    $backupRootDirectoryPath,

    [parameter(
        HelpMessage="The number of days to keep the daily backups. Allowed values: [1-365]."
    )]
    [int]
    [ValidateRange(1, 365)]
    $dailyBackupRetentionDays = 7,

    [parameter(
        HelpMessage="The name of the database to back up.",
        Mandatory=$true
    )]
    [string]
    $databaseName,

    [parameter(
        HelpMessage="The path to a *.cnf file for mysql or .pg_service.conf file for postgres.",
        Mandatory=$true
    )]
    [string]
    $databaseServerCredentialsFilePath,

    [parameter(
        HelpMessage="The database server resource name.",
        Mandatory=$true
    )]
    [string]
    $databaseServerResourceName,

    [parameter(
        HelpMessage="The database server type. Allowed values: `"mysql`", `"postgres`"",
        Mandatory=$true
    )]
    [string]
    [ValidateSet(
        "mysql",
        "postgres"
    )]
    $databaseServerType,

    [parameter(
        HelpMessage="The day of the month when the monthly backup is created. Allowed values: [1-28]."
    )]
    [int]
    [ValidateRange(1, 28)]
    $monthlyBackupDay = 15,

    [parameter(
        HelpMessage="The number of days to keep the monthly backups. Allowed values: [1-365]."
    )]
    [int]
    [ValidateRange(1, 365)]
    $monthlyBackupRetentionDays = 90,

    [parameter(
        HelpMessage="Whether or not database backup logs should be verbatim."
    )]
    [switch]
    $verboseBackupLog,

    [parameter(
        HelpMessage="The day of the week when the weekly backup is created. Allowed values: `"Sunday`", `"Monday`", `"Tuesday`", `"Wednesday`", `"Thursday`", `"Friday`", `"Saturday`"."
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
    $weeklyBackupDay = "Sunday",

    [parameter(
        HelpMessage="The number of days to keep the weekly backups. Allowed values: [1-365]."
    )]
    [int]
    [ValidateRange(1, 365)]
    $weeklyBackupRetentionDays = 35
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
function Echo-Input-Parameters{
    Write-Host "Echo input parameters..."

    Write-Host "- backupRootDirectoryPath = ${backupRootDirectoryPath}"
    Write-Host "- dailyBackupRetentionDays = ${dailyBackupRetentionDays}"
    Write-Host "- databaseName = ${databaseName}"
    Write-Host "- databaseServerCredentialsFilePath = ${databaseServerCredentialsFilePath}"
    Write-Host "- databaseServerResourceName = ${databaseServerResourceName}"
    Write-Host "- databaseServerType = ${databaseServerType}"
    Write-Host "- monthlyBackupDay = ${monthlyBackupDay}"
    Write-Host "- monthlyBackupRetentionDays = ${monthlyBackupRetentionDays}"
    Write-Host "- verboseBackupLog = ${verboseBackupLog}"
    Write-Host "- weeklyBackupDay = ${weeklyBackupDay}"
    Write-Host "- weeklyBackupRetentionDays = ${weeklyBackupRetentionDays}"

    Write-Host "Echo input parameters: completed."
}
function Validate-Input-Parameters {
    Write-Host "Validate input parameters: started."

    # Check if the database server credentials file exists.
    if (-Not(Test-Path -Path "${databaseServerCredentialsFilePath}" -PathType Leaf)){
        Write-Host "- Error: Specified database server credentials file NOT found. Aborting."
        Exit 1
    }

    # Check if backup directory exists.
    if(-Not(Test-Path -Path "${backupRootDirectoryPath}" -PathType Container)){
        Write-Host "- Error: Specified root backup directory NOT found. Aborting."
        Exit 1
    }

    Write-Host "Validate input parameter: completed."
}

function Create-Backup-Directory {

    Write-Host "Create backup directory: started."

    Write-Host "- Backup directory path: ${backupDirectoryPath}"

    if(Test-Path -Path "${backupDirectoryPath}" -PathType Container){
        Write-Host "- Warning: Backup directory already exists. Skipping."
    }
    else {
        New-Item -ItemType Directory -Path ${backupDirectoryPath} | Out-Null
        Write-Host "- Backup directory created."
    }

    Write-Host "Create backup directory: completed."
}
function Get-Backup-Base-Filename {
    if ((Get-Date).Day -eq "${monthlyBackupDay}") {
        $backupFilenameSuffix = "${MONTHLY_BACKUP_SUFFIX}"
    }
    elseif ((Get-Date).DayOfWeek -eq "$weeklyBackupDay") {
        $backupFilenameSuffix = "${WEEKLY_BACKUP_SUFFIX}"
    }
    else {
        $backupFilenameSuffix = "${DAILY_BACKUP_SUFFIX}"
    }
    Write-Output  "${backupFilenamePrefix}.$(Get-Date -Format yyyyMMdd).${backupFilenameSuffix}"
}

function Backup-Database {
    Param(
        [string]$backupFilePath,
        [string]$logFilePath
    )

    Write-Host "Backup database: started."

    Write-Host "- Backup file path: ${backupFilePath}"
    Write-Host "- Log file path: ${logFilePath}"

    # Compute verbose option based on script parameter switch.
    if ($verboseBackupLog){
        $verboseOption='--verbose'
    }
    else {
        $verboseOption=''
    }

    switch($databaseServerType){
        "$MYSQL_DATABASE_SERVER_TYPE" {
            Start-Process "C:\Program Files\MySQL\MySQL Workbench 8.0\mysqldump.exe" `
                -ArgumentList "--defaults-file=`"${databaseServerCredentialsFilePath}`" --compress=TRUE --default-character-set=utf8 --no-tablespaces --protocol=tcp --single-transaction=TRUE --skip-triggers ${verboseOption} `"${databaseName}`"" `
                -RedirectStandardError "${logFilePath}" `
                -RedirectStandardOutput "${backupFilePath}" `
                -Wait
        }
        "$POSTGRES_DATABASE_SERVER_TYPE"{
            # Set PGSERVICEFILE
            $Env:PGSERVICEFILE = "${databaseServerCredentialsFilePath}"
            Start-Process "C:\Program Files\PostgreSQL\14\bin\pg_dump.exe" `
                -ArgumentList "--clean --create --if-exists --no-acl --no-owner ${verboseOption} `"service=${databaseServerResourceName} dbname=${databaseName}`"" `
                -RedirectStandardError "${logFilePath}" `
                -RedirectStandardOutput "${backupFilePath}" `
                -Wait
        }
    }

    Write-Host "Backup database: completed."
}

function Validate-Backup-File {
    Param(
        [string]$backupFilePath
    )

    Write-Host "Validate backup file: started."
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
    Write-Host "Validate backup file: completed."
}


function Remove-Backup-Files {
    Param(
        [string]$backupFilenameSuffix,
        [int]$retentionDays
    )

    Write-Host "- Removing ${backupFilenameSuffix} backup files older than ${retentionDays} days, if any..."

    Get-ChildItem "${backupDirectoryPath}\${backupFilenamePrefix}.*.${backupFilenameSuffix}.${SQL_FILE_EXTENSION}" |
        Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-${retentionDays}) } |
            ForEach-Object {
                $file = Get-Item $_.FullName
                Write-Host "- Removing: $(${file}.Name) - Creation Date: $(${file}.CreationTime)"
                Remove-Item "${file}"
    }
}

function Apply-Backup-File-Retention-Policy{
    Write-Host "Apply backup file retention policy: started."

    Remove-Backup-Files `
        -backupFilenameSuffix "${MONTHLY_BACKUP_SUFFIX}" `
        -retentionDays ${monthlyBackupRetentionDays}

    Remove-Backup-Files `
        -backupFilenameSuffix "${WEEKLY_BACKUP_SUFFIX}" `
        -retentionDays ${weeklyBackupRetentionDays}

    Remove-Backup-Files `
        -backupFilenameSuffix "${DAILY_BACKUP_SUFFIX}" `
        -retentionDays ${dailyBackupRetentionDays}

    Write-Host "Apply backup file retention policy: completed."
}

# Main Work
Write-Host "------------------------- START -------------------------"
Echo-Input-Parameters
Validate-Input-Parameters
$backupDirectoryPath = "${backupRootDirectoryPath}\${databaseServerResourceName}"
Create-Backup-Directory
$backupFilenamePrefix = "${databaseServerResourceName}.${databaseName}"
$baseFilename = "$(Get-Backup-Base-Filename)"
$backupFilePath = "$backupDirectoryPath\${baseFilename}.${SQL_FILE_EXTENSION}"
$logFilePath = "$backupDirectoryPath\${baseFilename}.${LOG_FILE_EXTENSION}"
Backup-Database -backupFilePath "${backupFilePath}" -logFilePath "${logFilePath}"
Validate-Backup-File -backupFilePath "${backupFilePath}"
Apply-Backup-File-Retention-Policy
Write-Host "------------------------- FINISH -------------------------"

# Exit Script
Exit 0