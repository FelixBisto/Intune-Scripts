<#

.SYNOPSIS

Install the Dell WinPE drivers in the Windows Recovery Environment to make sure that an Intune wipe functions correctly.

.DESCRIPTION

This script installs the Dell WinPE drivers in the Windows Recovery Environment. This must be done because some drivers

used in the latest Dell devices are missing causing a failure when trying to accomplish an Intune wipe.

.EXAMPLE

.\Install-DellWinREDrivers.ps1

.NOTES

https://www.dell.com/community/Image-Assist/Windows-10-Recovery-System-Reset-failed-Workaround-add-most/td-p/7957209

#>

begin {
$filePath = "C:\ICT\ResetFixSuccess.txt"

if (Test-Path $filePath) {
    Write-Host "The file $filePath exists. Exiting script."
    exit
}

#----------------------------------------------------------------------------------------------------

# Functions

#----------------------------------------------------------------------------------------------------

function Write-LogEntry {

param(

[parameter(Mandatory=$true, HelpMessage="Value added to the log file.")]

[ValidateNotNullOrEmpty()]

[String] $Value,

[parameter(Mandatory=$false, HelpMessage="The category of the action that is being processed.")]

[ValidateNotNullOrEmpty()]

[String] $Category,

[Parameter(Mandatory=$false, HelpMessage="Value added to the log file without a timestamp.")]

[Switch] $Announcement,

[parameter(Mandatory=$false, HelpMessage="Name of the log file that the entry will written to.")]

[ValidateNotNullOrEmpty()]

[String] $FileName = "Install-DellWinREDrivers.log"

)

$logFilePath = Join-Path -Path $autopilotFolder -ChildPath "$($FileName)"

$timeStamp = "[{0:dd-MM-yyyy} {0:HH:mm:ss}]" -f (Get-Date)

try

{

if ($Announcement.IsPresent)

{

Out-File -InputObject "$Value" -Append -NoClobber -Encoding Default -FilePath $logFilePath -ErrorAction Stop

}

elseif ($Category)

{

Out-File -InputObject "$timeStamp $Category $Value" -Append -NoClobber -Encoding Default -FilePath $logFilePath -ErrorAction Stop

}

else

{

Out-File -InputObject "$timeStamp $Value" -Append -NoClobber -Encoding Default -FilePath $logFilePath -ErrorAction Stop

}

}

catch [System.Exception]

{

Write-Warning -Message "Unable to append log entry to $($FileName) file"

}

}

#----------------------------------------------------------------------------------------------------

# Variables

#----------------------------------------------------------------------------------------------------

$autopilotFolder = "$($env:ProgramData)\Microsoft\Autopilot\DellWinREDrivers"

$driverFolder = "winpe"

$mountFolder = "C:\MountWinRE"

$wim = "C:\Windows\System32\Recovery\Winre.wim"

}

process {

if (-not (Test-Path $autopilotFolder))

{

New-Item -Path $autopilotFolder -ItemType Directory

}

# Initial logging

Write-LogEntry -Announcement -Value "------------------------------------------------------------\nInstall-DellWinREDrivers has been started at $(Get-Date -Format "dd-MM-yyyy HH:mm:ss")`n------------------------------------------------------------"`

if (-not (Test-Path $mountFolder))

{

New-Item -Path $mountFolder -ItemType Directory

}

Write-LogEntry -Value "Temporary disabling Windows RE agent"

ReAgentC.exe /disable

$reAgentDisabled = ReAgentC.exe /info | Select-Object -Index 3 | Where-Object { $_ -like "*Disabled*" }

if ($reAgentDisabled)

{

# Create a notepad file in the C:\ICT folder
Out-File -FilePath C:\ICT\ResetFixSuccess.txt -Force

Write-LogEntry -Value "Mounting $wim in $mountFolder"

Mount-WindowsImage -ImagePath $wim -Index 1 -Path $mountFolder

Write-LogEntry -Value "Expanding $driverFolder.zip"

Invoke-WebRequest -Uri https://downloads.dell.com/FOLDER10964270M/1/WinPE10.0-Drivers-A32-473P6.cab -OutFile "C:\ICT\winpe.cab"
# Replace 'yourfile.cab' with the actual name of your .cab file
$CabFilePath = "C:\ICT\winpe.cab"

# Replace 'C:\Path\To\Your\Destination' with the desired extraction location
$ExtractedFolderPath = "C:\ICT\winpe"

# Replace 'C:\Path\To\Your\Output.zip' with the desired location and name for the .zip file
$ZipFilePath = "C:\ICT\winpe.zip"

# Step 1: Extract the contents of the .cab file
Expand C:\ICT\winpe.cab -F:* C:\ICT\

Write-LogEntry -Value "Adding drivers to mounted wim"

Add-WindowsDriver -Path $mountFolder -Driver "c:\ICT\winpe" -Recurse -ForceUnsigned

Write-LogEntry -Value "Committing changes and dismounting wim"

Dismount-WindowsImage -Path $mountFolder -Save

}

else

{

Write-LogEntry -Value "Failed to disable the Windows Recovery agent, exiting"

return

}

Write-LogEntry -Value "Enabling Windows RE agent"

ReAgentC.exe /enable

$reAgentEnabled = ReAgentC.exe /info | Select-Object -Index 3 | Where-Object { $_ -like "*Enabled*" }

if ($reAgentEnabled)

{

Write-LogEntry -Value "The operation completed successfully"

# Create a tag file so Intune knows it is installed

Set-Content -Path "$autopilotFolder\Install-DellWinREDrivers.ps1.tag" -Value "Installed"

}

else

{

Write-LogEntry -Value "Failed to enable the Windows Recovery agent, exiting"

$exitCode = 1

}

}

end {

Remove-Item -Path $mountFolder -Recurse -Force

Remove-Item -Path C:\ICT\winpe -Recurse -Force

Write-LogEntry -Announcement -Value "------------------------------------------------------------\nInstall-DellWinREDrivers has been finished at $(Get-Date -Format "dd-MM-yyyy HH:mm:ss")`n------------------------------------------------------------"`

exit $exitCode

}