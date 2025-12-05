<#
    Sync-LockScreen.ps1
    Purpose:
        - Pull a lock screen wallpaper from a network location
        - Detect changes
        - Copy to local machine (required for Windows 10/11 lock screens)
        - Update GPO-controlled registry key
        - Refresh LockApp to apply immediately
        - Log actions for auditing
#>

# -----------------------------
# CONFIGURATION
# -----------------------------

$NetworkImage = "\\SERVER\Share\Wallpapers\LockScreen.jpg"      # <<< CHANGE ME
$LocalImage   = "C:\Windows\Web\Screen\CorpLockScreen.jpg"
$HashFile     = "C:\Windows\Temp\LockScreen.hash"
$LogFile      = "C:\Windows\Temp\LockScreenDeploy.log"

# GPO policy path
$PolicyPath   = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
$PolicyValue  = "LockScreenImage"

# -----------------------------
# LOGGING
# -----------------------------

function Write-Log {
    param([string]$msg)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$timestamp - $msg" | Out-File -Append $LogFile
}

Write-Log "=== Lock Screen Sync Started ==="

# -----------------------------
# VALIDATE NETWORK WALLPAPER
# -----------------------------

if (-not (Test-Path $NetworkImage)) {
    Write-Log "ERROR: Cannot access network file: $NetworkImage"
    exit 1
}

# Calculate hash of network image
try {
    $NetworkHash = (Get-FileHash $NetworkImage -Algorithm SHA256).Hash
}
catch {
    Write-Log "ERROR hashing network file: $($_.Exception.Message)"
    exit 1
}

# -----------------------------
# CHECK IF IMAGE CHANGED
# -----------------------------

if (Test-Path $HashFile) {
    $OldHash = Get-Content $HashFile -ErrorAction SilentlyContinue

    if ($OldHash -eq $NetworkHash) {
        Write-Log "No changes detected. Exiting."
        exit 0
    }
}

Write-Log "Change detected! Updating lock screen image..."

# -----------------------------
# COPY UPDATED IMAGE LOCALLY
# -----------------------------

try {
    Copy-Item $NetworkImage $LocalImage -Force
    Write-Log "Copied updated wallpaper to $LocalImage"
}
catch {
    Write-Log "ERROR copying file: $($_.Exception.Message)"
    exit 1
}

# Save new hash
$NetworkHash | Out-File $HashFile -Force

# -----------------------------
# UPDATE GPO LOCK SCREEN POLICY
# -----------------------------

if (-not (Test-Path $PolicyPath)) {
    New-Item -Path $PolicyPath -Force | Out-Null
    Write-Log "Created policy registry path."
}

try {
    New-ItemProperty -Path $PolicyPath -Name $PolicyValue -Value $LocalImage -PropertyType String -Force | Out-Null
    Write-Log "Updated GPO lock screen policy to use $LocalImage"
}
catch {
    Write-Log "ERROR updating registry policy: $($_.Exception.Message)"
    exit 1
}

# -----------------------------
# FORCE LOCK SCREEN REFRESH
# -----------------------------

# Kill LockApp (if applicable)
Stop-Process -Name "LockApp" -Force -ErrorAction SilentlyContinue
Write-Log "Restarted LockApp."

# Optional: force GPUpdate
gpupdate /target:computer /force | Out-Null
Write-Log "Group Policy updated."

Write-Log "=== Lock Screen Sync Completed Successfully ==="
