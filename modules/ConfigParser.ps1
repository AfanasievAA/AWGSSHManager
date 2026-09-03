#requires -Version 7.5
# =============================================================================
#  ConfigParser.ps1 — AmneziaWG config and JSON response parser
#  Version: 0.3
#  Description: Parses .conf files and JSON responses from manage_amneziawg.sh.
#               Provides validation, formatting, and utility functions.
# =============================================================================

# =============================================================================
#  CONSTANTS
# =============================================================================

# AWG 2.0 obfuscation parameter regex: Jc, Jmin, Jmax, S1-S4, H1-H4, I1-I5
$script:AWGObfuscationParamRegex = '^(Jc|Jmin|Jmax|S[1-4]|H[1-4]|I[1-5])$'

# 11 required AWG 2.0 parameters (I1-I5 are optional)
$script:AWGRequiredParams20 = @(
    'Jc', 'Jmin', 'Jmax',
    'S1', 'S2', 'S3', 'S4',
    'H1', 'H2', 'H3', 'H4'
)

# Allowed parameters for modify command (manage_amneziawg.sh)
$script:AWGModifyAllowedParams = @(
    'DNS', 'Endpoint', 'AllowedIPs', 'PersistentKeepalive'
)


# =============================================================================
#  HELPER FUNCTIONS
# =============================================================================

function Get-AWGConfigProperty {
    <#
    .SYNOPSIS
        Internal function: safely reads an object property (StrictMode-safe).
        Returns $null if property doesn't exist or value is not set.
    #>
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) { return $prop.Value }
    return $null
}


# =============================================================================
#  SECTION 1: EXPIRATION (--expires)
# =============================================================================

function Get-AWGExpiryStatus {
    <#
    .SYNOPSIS
        Returns expiration status for a client by Unix timestamp.
    .PARAMETER ExpiresAt
        Unix timestamp (number), string with number, 'null' or $null.
    .OUTPUTS
        Hashtable: Status, Text, DaysLeft, HoursLeft, ExpiryDate,
                   IsExpired, UnixTimestamp.
        Status: Permanent | Expired | ExpiringSoon | Active | Unknown
    #>
    param(
        $ExpiresAt,
        [DateTime]$Now = (Get-Date)
    )

    # --- Normalize input ---
    $hasExpiry = $false
    $ts = 0L

    if ($null -ne $ExpiresAt) {
        if ($ExpiresAt -is [long] -or $ExpiresAt -is [int] -or $ExpiresAt -is [double]) {
            $ts = [long]$ExpiresAt
            if ($ts -gt 0) { $hasExpiry = $true }
        }
        elseif ($ExpiresAt -is [string]) {
            if ($ExpiresAt -and $ExpiresAt -ne 'null' -and $ExpiresAt -match '^\d+$') {
                $ts = [long]$ExpiresAt
                if ($ts -gt 0) { $hasExpiry = $true }
            }
        }
    }

    if (-not $hasExpiry) {
        return @{
            Status = 'Permanent'; Text = (Get-String -Key "Status_Permanent")
            DaysLeft = $null; HoursLeft = $null; ExpiryDate = $null
            IsExpired = $false; UnixTimestamp = 0
        }
    }

    # --- Convert timestamp ---
    try {
        $expiryDate = [DateTimeOffset]::FromUnixTimeSeconds($ts).LocalDateTime
    }
    catch {
        return @{
            Status = 'Unknown'; Text = 'Unknown'
            DaysLeft = $null; HoursLeft = $null; ExpiryDate = $null
            IsExpired = $false; UnixTimestamp = $ts
        }
    }

    $timeLeft = $expiryDate - $Now

    # --- Expired ---
    if ($timeLeft.TotalSeconds -le 0) {
        return @{
            Status = 'Expired'; Text = (Get-String -Key "Status_Expired")
            DaysLeft = 0; HoursLeft = 0; ExpiryDate = $expiryDate
            IsExpired = $true; UnixTimestamp = $ts
        }
    }

    # --- Expiring within 24 hours ---
    if ($timeLeft.TotalHours -le 24) {
        return @{
            Status = 'ExpiringSoon'
            Text   = '{0:N0} h' -f [Math]::Ceiling($timeLeft.TotalHours)
            DaysLeft   = [Math]::Ceiling($timeLeft.TotalDays)
            HoursLeft  = [Math]::Ceiling($timeLeft.TotalHours)
            ExpiryDate = $expiryDate
            IsExpired  = $false
            UnixTimestamp = $ts
        }
    }

    # --- Active ---
    return @{
        Status = 'Active'
        Text   = '{0:N0} d' -f [Math]::Floor($timeLeft.TotalDays)
        DaysLeft   = [Math]::Floor($timeLeft.TotalDays)
        HoursLeft  = $null
        ExpiryDate = $expiryDate
        IsExpired  = $false
        UnixTimestamp = $ts
    }
}


# =============================================================================
#  SECTION 2: FORMATTING AND DISPLAY
# =============================================================================

function Format-Bytes {
    <#
    .SYNOPSIS
        Formats bytes to human-readable: 1536 → "1.50 KB".
    #>
    param([long]$Bytes)

    if ($Bytes -lt 0) { return '0 B' }

    $units = @('B', 'KB', 'MB', 'GB', 'TB', 'PB')
    $size  = [double]$Bytes
    $i     = 0

    while ($size -ge 1024 -and $i -lt $units.Count - 1) {
        $size /= 1024
        $i++
    }

    if ($i -eq 0) { return "$([long]$size) B" }
    return ('{0:N2} {1}' -f $size, $units[$i])
}
function Get-AWGStatusDisplay {
    <#
    .SYNOPSIS
        Converts machine-stable status_code to text and level for GUI.
    .DESCRIPTION
        IMPORTANT: accepts status_code (active, recent, ...), NOT the
        localized status field ("Active"/"Активен") — the latter depends
        on server language and is not suitable for logic.
    .OUTPUTS
        PSCustomObject: StatusCode, Text, Level
        Level: Ok | Info | Warn | Error | Neutral
    #>
    param([string]$StatusCode)

    $map = @{
        'active'       = @{ Text = (Get-String -Key "Status_Active");       Level = 'Ok' }
        'recent'       = @{ Text = (Get-String -Key "Status_Recent");       Level = 'Info' }
        'inactive'     = @{ Text = (Get-String -Key "Status_Inactive");     Level = 'Warn' }
        'no_handshake' = @{ Text = (Get-String -Key "Status_NoHandshake"); Level = 'Warn' }
        'key_error'    = @{ Text = (Get-String -Key "Status_KeyError");    Level = 'Error' }
        'no_data'      = @{ Text = (Get-String -Key "Status_NoData");      Level = 'Neutral' }
        # Local codes (computed in GUI, not from server)
        'expired'      = @{ Text = (Get-String -Key "Status_Expired");      Level = 'Error' }
        'permanent'    = @{ Text = (Get-String -Key "Status_Permanent");    Level = 'Neutral' }
    }

    if ($map.ContainsKey($StatusCode)) {
        return [PSCustomObject]@{
            StatusCode = $StatusCode
            Text       = $map[$StatusCode].Text
            Level      = $map[$StatusCode].Level
        }
    }

    return [PSCustomObject]@{
        StatusCode = $StatusCode
        Text       = if ($StatusCode) { $StatusCode } else { '—' }
        Level      = 'Neutral'
    }
}

function Get-AWGStatusColor {
    <#
    .SYNOPSIS
        Returns colors for DataGridView by status level from
        Get-AWGStatusDisplay.
    .NOTES
        Requires System.Drawing loaded — main.ps1 calls
        Add-Type -AssemblyName System.Drawing BEFORE dot-sourcing this file.
    .OUTPUTS
        Hashtable: ForeColor, BackColor ([System.Drawing.Color]).
    #>
    param([string]$Level)

    switch ($Level) {
        'Ok' {
            return @{
                ForeColor = [System.Drawing.Color]::Green
                BackColor = [System.Drawing.Color]::FromArgb(220, 255, 220)
            }
        }
        'Info' {
            return @{
                ForeColor = [System.Drawing.Color]::DarkGreen
                BackColor = [System.Drawing.Color]::White
            }
        }
        'Warn' {
            return @{
                ForeColor = [System.Drawing.Color]::DarkOrange
                BackColor = [System.Drawing.Color]::White
            }
        }
        'Error' {
            return @{
                ForeColor = [System.Drawing.Color]::Red
                BackColor = [System.Drawing.Color]::FromArgb(255, 225, 225)
            }
        }
        default {
            return @{
                ForeColor = [System.Drawing.Color]::Black
                BackColor = [System.Drawing.Color]::White
            }
        }
    }
}