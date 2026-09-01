#requires -Version 7.5
# =============================================================================
#  ConfigParser.ps1 — AmneziaWG config and JSON response parser
#  Version: 0.2
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

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) { return $prop.Value }
    return $null
}


# =============================================================================
#  SECTION 1: .conf FILE PARSING
# =============================================================================

function ConvertFrom-AWGClientConfig {
    <#
    .SYNOPSIS
        Parses AmneziaWG .conf file text (client or server awg0.conf).
    .PARAMETER ConfigText
        Full configuration file text.
    .OUTPUTS
        PSCustomObject:
          InterfaceParams  — [ordered] dictionary of ALL [Interface] section keys
          PeerParams       — [ordered] dictionary of ALL [Peer] section keys
          AWGParams        — [ordered] dictionary of AWG 2.0 obfuscation params
          PeerName         — peer name from "#_Name = <name>" marker (awg0.conf)
          + convenience properties: PrivateKey, Address, DNS, MTU, ListenPort,
            PostUp, PostDown, ServerPublicKey, PresharedKey, AllowedIPs,
            Endpoint, PersistentKeepalive
          RawConfig        — original text unchanged
    .NOTES
        Base64 keys end with '=' — regex parses "key = value" by FIRST '=',
        so trailing '=' in values are preserved correctly.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$ConfigText
    )

    $result = [PSCustomObject]@{
        InterfaceParams     = [ordered]@{}
        PeerParams          = [ordered]@{}
        AWGParams           = [ordered]@{}
        PeerName            = $null

        PrivateKey          = $null
        Address             = $null
        DNS                 = $null
        MTU                 = $null
        ListenPort          = $null
        PostUp              = $null
        PostDown            = $null

        ServerPublicKey     = $null
        PresharedKey        = $null
        AllowedIPs          = $null
        Endpoint            = $null
        PersistentKeepalive = $null

        RawConfig           = $ConfigText
    }

    $currentSection = ''

    foreach ($rawLine in ($ConfigText -split '\r?\n')) {
        $line = $rawLine.Trim()

        # Skip empty lines
        if (-not $line) { continue }

        # Peer name marker: "#_Name = <name>" (manage_amneziawg.sh)
        if ($line -match '^#\s*_Name\s*=\s*(.+)$') {
            $result.PeerName = $Matches[1].Trim()
            continue
        }

        # Skip other comments
        if ($line.StartsWith('#')) { continue }

        # Sections [Interface] / [Peer]
        if ($line -match '^\[(.+)\]$') {
            $currentSection = $Matches[1].Trim()
            continue
        }

        # "key = value" pair (separator is first '=')
        if ($line -match '^([^=]+?)\s*=\s*(.*)$') {
            $key   = $Matches[1].Trim()
            $value = $Matches[2].Trim()

            switch ($currentSection) {
                'Interface' {
                    $result.InterfaceParams[$key] = $value

                    switch ($key) {
                        'PrivateKey' { $result.PrivateKey = $value; break }
                        'Address'    { $result.Address    = $value; break }
                        'DNS'        { $result.DNS        = $value; break }
                        'MTU'        { $result.MTU        = $value; break }
                        'ListenPort' { $result.ListenPort = $value; break }
                        'PostUp'     { $result.PostUp     = $value; break }
                        'PostDown'   { $result.PostDown   = $value; break }
                        default {
                            if ($key -match $script:AWGObfuscationParamRegex) {
                                $result.AWGParams[$key] = $value
                            }
                        }
                    }
                }
                'Peer' {
                    $result.PeerParams[$key] = $value

                    switch ($key) {
                        'PublicKey'           { $result.ServerPublicKey     = $value; break }
                        'PresharedKey'        { $result.PresharedKey        = $value; break }
                        'AllowedIPs'          { $result.AllowedIPs          = $value; break }
                        'Endpoint'            { $result.Endpoint            = $value; break }
                        'PersistentKeepalive' { $result.PersistentKeepalive = $value; break }
                    }
                }
                default {
                    # Unknown section — data not lost (RawConfig preserved)
                }
            }
        }
    }

    return $result
}

function ConvertFrom-AWGJsonResponse {
    <#
    .SYNOPSIS
        Safely parses JSON response from manage_amneziawg.sh.
    .DESCRIPTION
        Contract guarantee: stdout contains EXACTLY one JSON document.
        All human-readable messages go to stderr, so stdout is always clean.
        Supports both response formats:
        1. Raw array — list --json, stats --json.
        2. Envelope {"command":"...","ok":true/false,...} — add, remove,
           regen, modify, backup, restore, check, restart, etc.
    .OUTPUTS
        PSCustomObject:
          IsEnvelope — true if response is envelope with ok field
          IsArray    — true if response is raw array (list/stats)
          Ok         — true/false (for array — always true)
          Error      — error text from envelope or $null
          Rc         — return code from envelope (0 if not set)
          Data       — parsed JSON (array or envelope object)
    #>
    param(
        [Parameter(Mandatory)][string]$JsonText,
        [string]$CommandName = ''
    )

    if ([string]::IsNullOrWhiteSpace($JsonText)) {
        $ctx = if ($CommandName) { " (command: $CommandName)" } else { '' }
        throw (Get-String -Key "Error_EmptyJSON") + $ctx
    }

    # Contract guarantees clean JSON in stdout. No need to trim garbage.
    $parsed = $null
    try {
        $parsed = $JsonText.Trim() | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $preview = $JsonText.Substring(0, [Math]::Min(200, $JsonText.Length))
        throw (Get-String -Key "Error_JSONParse" -Params $_.Exception.Message, $preview)
    }

    if ($null -eq $parsed) {
        throw (Get-String -Key "Error_JSONNull")
    }

    # --- Form 1: raw array (list --json, stats --json) ---
    if ($parsed -is [System.Array]) {
        return [PSCustomObject]@{
            IsEnvelope = $false
            IsArray    = $true
            Ok         = $true
            Error      = $null
            Rc         = 0
            Data       = $parsed
        }
    }

    # --- Form 2: envelope {"command":"...","ok":...} ---
    $okProp = $parsed.PSObject.Properties['ok']
    if ($null -ne $okProp) {
        $errProp = $parsed.PSObject.Properties['error']
        $rcProp  = $parsed.PSObject.Properties['rc']

        return [PSCustomObject]@{
            IsEnvelope = $true
            IsArray    = $false
            Ok         = [bool]$okProp.Value
            Error      = if ($errProp) { $errProp.Value } else { $null }
            Rc         = if ($rcProp)  { [int]$rcProp.Value } else { 0 }
            Data       = $parsed
        }
    }

    # --- Single object without envelope — treat as data ---
    return [PSCustomObject]@{
        IsEnvelope = $false
        IsArray    = $false
        Ok         = $true
        Error      = $null
        Rc         = 0
        Data       = $parsed
    }
}
function Test-AWGConfigValid {
    <#
    .SYNOPSIS
        Validates AmneziaWG .conf file.
    .OUTPUTS
        Hashtable:
          Valid    — bool
          Errors   — List[string], critical issues
          Warnings — List[string], non-critical issues
          Config   — ConvertFrom-AWGClientConfig object or $null
    .NOTES
        Critical (Errors): missing sections, PrivateKey, Address,
        PublicKey, AllowedIPs, Endpoint; invalid AllowedIPs format.
        Warnings: missing AWG 2.0 parameters (config for WireGuard/AWG 1.0),
        H1-H4 beyond INT32_MAX, Endpoint format, PersistentKeepalive.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$ConfigText
    )

    $errors   = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    if ([string]::IsNullOrWhiteSpace($ConfigText)) {
        $errors.Add((Get-String -Key "Error_ConfigEmpty"))
        return @{ Valid = $false; Errors = $errors; Warnings = $warnings; Config = $null }
    }

    if ($ConfigText -notmatch '(?m)^\s*\[Interface\]') {
        $errors.Add((Get-String -Key "Error_MissingInterface"))
    }
    if ($ConfigText -notmatch '(?m)^\s*\[Peer\]') {
        $errors.Add((Get-String -Key "Error_MissingPeer"))
    }
    if ($errors.Count -gt 0) {
        return @{ Valid = $false; Errors = $errors; Warnings = $warnings; Config = $null }
    }

    $config = ConvertFrom-AWGClientConfig -ConfigText $ConfigText

    # --- Required fields ---
    if (-not $config.PrivateKey)      { $errors.Add((Get-String -Key "Error_MissingPrivateKey")) }
    if (-not $config.Address)         { $errors.Add((Get-String -Key "Error_MissingAddress")) }
    if (-not $config.ServerPublicKey) { $errors.Add((Get-String -Key "Error_MissingPublicKey")) }
    if (-not $config.AllowedIPs)      { $errors.Add((Get-String -Key "Error_MissingAllowedIPs")) }
    if (-not $config.Endpoint)        { $errors.Add((Get-String -Key "Error_MissingEndpoint")) }

    # --- AllowedIPs ---
    if ($config.AllowedIPs) {
        $ipCheck = Test-AWGAllowedIPs -AllowedIPs $config.AllowedIPs
        if (-not $ipCheck.IsValid) {
            $errors.Add((Get-String -Key "Error_InvalidAllowedIPs" -Params $ipCheck.Error))
        }
    }

    # --- Endpoint ---
    if ($config.Endpoint) {
        $epCheck = Test-AWGEndpoint -Endpoint $config.Endpoint
        if (-not $epCheck.IsValid) {
            $warnings.Add((Get-String -Key "Error_InvalidEndpoint" -Params $epCheck.Error))
        }
    }

    # --- AWG 2.0: 11 required parameters ---
    $missingAwg = @()
    foreach ($p in $script:AWGRequiredParams20) {
        if (-not $config.AWGParams.Contains($p)) { $missingAwg += $p }
    }
    if ($missingAwg.Count -gt 0) {
        $warnings.Add(
            "Missing AWG 2.0 parameters: $($missingAwg -join ', ') " +
            "— config may be for WireGuard/AWG 1.0"
        )
    }

    # --- H1-H4: value or range, upper ≤ INT32_MAX ---
    foreach ($h in @('H1', 'H2', 'H3', 'H4')) {
        if ($config.AWGParams.Contains($h)) {
            $val = [string]$config.AWGParams[$h]
            if ($val -notmatch '^\d{1,10}(-\d{1,10})?$') {
                $warnings.Add("$h = '$val' — expected number or range (N or N-M)")
            }
            else {
                foreach ($part in ($val -split '-')) {
                    if ([long]$part -gt 2147483647) {
                        $warnings.Add(
                            "$h = '$val' — value exceeds INT32_MAX (2147483647), " +
                            "Windows client will reject config"
                        )
                    }
                }
            }
        }
    }

    # --- PersistentKeepalive ---
    if ($config.PersistentKeepalive -and
        $config.PersistentKeepalive -notmatch '^\d{1,5}$') {
        $warnings.Add(
            "PersistentKeepalive = '$($config.PersistentKeepalive)' " +
            "— expected number 0-65535"
        )
    }

    return @{
        Valid    = ($errors.Count -eq 0)
        Errors   = $errors
        Warnings = $warnings
        Config   = $config
    }
}


# =============================================================================
#  SECTION 2: JSON RESPONSES FROM manage_amneziawg.sh (--json)
# =============================================================================

function ConvertFrom-AWGJsonResponse {
    <#
    .SYNOPSIS
        Safely parses JSON response from manage_amneziawg.sh.
    .DESCRIPTION
        Supports both response formats:
        1. Raw array — list --json, stats --json.
        2. Envelope {"command":"...","ok":true/false,...} — add, remove,
           regen, modify, backup, restore, check, restart, etc.
        If there is garbage around JSON (bash warnings in stdout), tries to
        extract document starting from first '[' or '{'.
    .OUTPUTS
        PSCustomObject:
          IsEnvelope — true if response is envelope with ok field
          IsArray    — true if response is raw array (list/stats)
          Ok         — true/false (for array — always true)
          Error      — error text from envelope or $null
          Rc         — return code from envelope (0 if not set)
          Data       — parsed JSON (array or envelope object)
    #>
    param(
        [Parameter(Mandatory)][string]$JsonText,
        [string]$CommandName = ''
    )

    if ([string]::IsNullOrWhiteSpace($JsonText)) {
        $ctx = if ($CommandName) { " (command: $CommandName)" } else { '' }
        throw (Get-String -Key "Error_EmptyJSON") + $ctx
    }

    $trimmed = $JsonText.Trim()

    $parsed = $null
    try {
        $parsed = $trimmed | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $parseError = $_.Exception.Message
        $recovered  = $false

        # Try to trim garbage BEFORE JSON document start
        $jsonMatch = [regex]::Match($trimmed, '[\[{]')
        if ($jsonMatch.Success -and $jsonMatch.Index -gt 0) {
            try {
                $parsed = $trimmed.Substring($jsonMatch.Index) |
                    ConvertFrom-Json -ErrorAction Stop
                $recovered = $true
            }
            catch {
                # Failed — will throw with original error below
            }
        }

        if (-not $recovered) {
            $preview = $trimmed.Substring(0, [Math]::Min(200, $trimmed.Length))
            throw (Get-String -Key "Error_JSONParse" -Params $parseError, $preview)
        }
    }

    if ($null -eq $parsed) {
        throw (Get-String -Key "Error_JSONNull")
    }

    # --- Form 1: raw array (list --json, stats --json) ---
    if ($parsed -is [System.Array]) {
        return [PSCustomObject]@{
            IsEnvelope = $false
            IsArray    = $true
            Ok         = $true
            Error      = $null
            Rc         = 0
            Data       = $parsed
        }
    }

    # --- Form 2: envelope {"command":"...","ok":...} ---
    $okProp = $parsed.PSObject.Properties['ok']
    if ($null -ne $okProp) {
        $errProp = $parsed.PSObject.Properties['error']
        $rcProp  = $parsed.PSObject.Properties['rc']

        return [PSCustomObject]@{
            IsEnvelope = $true
            IsArray    = $false
            Ok         = [bool]$okProp.Value
            Error      = if ($errProp) { $errProp.Value } else { $null }
            Rc         = if ($rcProp)  { [int]$rcProp.Value } else { 0 }
            Data       = $parsed
        }
    }

    # --- Single object without envelope — treat as data ---
    return [PSCustomObject]@{
        IsEnvelope = $false
        IsArray    = $false
        Ok         = $true
        Error      = $null
        Rc         = 0
        Data       = $parsed
    }
}

function Assert-AWGResponseOk {
    <#
    .SYNOPSIS
        Checks ConvertFrom-AWGJsonResponse response and throws exception
        with clear message if ok = false.
    .OUTPUTS
        Data from response (for envelope — the object itself with results[] etc.).
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Response,
        [string]$Context = ''
    )

    if (-not $Response.Ok) {
        $msg = if ($Response.Error) {
            $Response.Error
        }
        else {
            "return code $($Response.Rc)"
        }
        $prefix = if ($Context) { "$($Context): " } else { '' }
        throw "${prefix}Server returned error: $msg"
    }

    return $Response.Data
}


# =============================================================================
#  SECTION 3: EXPIRATION (--expires)
# =============================================================================

function ConvertTo-AWGDurationFlag {
    <#
    .SYNOPSIS
        Builds --expires flag string: 7 + 'd' → "7d".
    #>
    param(
        [Parameter(Mandatory)][ValidateRange(1, 365)][int]$Value,
        [Parameter(Mandatory)][ValidateSet('h', 'd', 'w')][string]$Unit
    )

    return "$Value$Unit"
}

function ConvertFrom-AWGDurationFlag {
    <#
    .SYNOPSIS
        Parses --expires flag string: "7d" → Value=7, Unit='d', TimeSpan=7 days.
    .OUTPUTS
        Hashtable: IsValid, Value, Unit, TimeSpan, Error.
    #>
    param([string]$Flag)

    if ([string]::IsNullOrWhiteSpace($Flag)) {
        return @{ IsValid = $false; Value = 0; Unit = $null; TimeSpan = $null; Error = 'Value not specified' }
    }

    if ($Flag -notmatch '^(\d+)\s*([hdw])$') {
        return @{
            IsValid  = $false
            Value    = 0
            Unit     = $null
            TimeSpan = $null
            Error    = "Invalid format: '$Flag'. Expected Nd, Nh or Nw (e.g., 7d, 12h, 4w)"
        }
    }

    $value = [int]$Matches[1]
    $unit  = $Matches[2]

    if ($value -lt 1) {
        return @{ IsValid = $false; Value = 0; Unit = $unit; TimeSpan = $null; Error = 'Value must be at least 1' }
    }

    $span = switch ($unit) {
        'h' { [TimeSpan]::FromHours($value) }
        'd' { [TimeSpan]::FromDays($value) }
        'w' { [TimeSpan]::FromDays($value * 7) }
    }

    return @{
        IsValid  = $true
        Value    = $value
        Unit     = $unit
        TimeSpan = $span
        Error    = $null
    }
}

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
#  SECTION 4: VALIDATION
# =============================================================================

function Test-AWGClientName {
    <#
    .SYNOPSIS
        Validates client name according to manage_amneziawg.sh rules.
    .OUTPUTS
        Hashtable: IsValid (bool), Reason (string or $null).
    #>
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return @{ IsValid = $false; Reason = (Get-String -Key "Error_NameRequired") }
    }
    if ($Name.Length -gt 32) {
        return @{ IsValid = $false; Reason = 'Name longer than 32 characters' }
    }
    if ($Name -notmatch '^[a-zA-Z0-9_-]+$') {
        return @{
            IsValid = $false
            Reason  = (Get-String -Key "Error_InvalidName")
        }
    }
    return @{ IsValid = $true; Reason = $null }
}

function Test-AWGEndpoint {
    <#
    .SYNOPSIS
        Validates Endpoint format: host:port or [IPv6]:port.
    .OUTPUTS
        Hashtable: IsValid, Error, Host, Port.
    #>
    param([string]$Endpoint)

    if ([string]::IsNullOrWhiteSpace($Endpoint)) {
        return @{ IsValid = $false; Error = 'Endpoint not specified'; Host = $null; Port = 0 }
    }

    $hostPart = $null
    $port     = 0

    # --- Format [IPv6]:port ---
    if ($Endpoint -match '^\[(.+)\]:(\d{1,5})$') {
        $hostPart = $Matches[1]
        $port     = [int]$Matches[2]

        $ip = $null
        if (-not [System.Net.IPAddress]::TryParse($hostPart, [ref]$ip) -or
            $ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
            return @{
                IsValid = $false
                Error   = "Invalid IPv6 address in brackets: [$hostPart]"
                Host    = $null; Port = 0
            }
        }
    }
    # --- Format host:port (hostname or IPv4) ---
    elseif ($Endpoint -match '^([^:\[\]]+):(\d{1,5})$') {
        $hostPart = $Matches[1]
        $port     = [int]$Matches[2]

        # Allow letters, digits, dots, hyphens, underscores (DDNS names)
        if ($hostPart -notmatch '^[a-zA-Z0-9_]([a-zA-Z0-9._-]*[a-zA-Z0-9_])?$') {
            return @{
                IsValid = $false
                Error   = "Invalid host: '$hostPart'"
                Host    = $null; Port = 0
            }
        }
    }
    else {
        return @{
            IsValid = $false
            Error   = "Invalid Endpoint format: '$Endpoint'. Expected host:port or [IPv6]:port"
            Host    = $null; Port = 0
        }
    }

    if ($port -lt 1 -or $port -gt 65535) {
        return @{
            IsValid = $false
            Error   = "Port out of range 1-65535: $port"
            Host    = $hostPart; Port = $port
        }
    }

    return @{ IsValid = $true; Error = $null; Host = $hostPart; Port = $port }
}

function Test-AWGAllowedIPs {
    <#
    .SYNOPSIS
        Validates AllowedIPs list: CIDR IPv4/IPv6 comma-separated.
        Bare IPs (without /prefix) are also allowed.
    .OUTPUTS
        Hashtable: IsValid, Error, InvalidEntries.
    #>
    param([string]$AllowedIPs)

    $invalidEntries = [System.Collections.Generic.List[string]]::new()
    $checked        = 0

    if ([string]::IsNullOrWhiteSpace($AllowedIPs)) {
        return @{ IsValid = $false; Error = 'AllowedIPs not specified'; InvalidEntries = @() }
    }

    foreach ($entry in ($AllowedIPs -split '\s*,\s*')) {
        if (-not $entry) { continue }
        $checked++

        $addr       = $entry
        $prefixLen  = $null

        # Split prefix: 10.0.0.0/8, ::/0, etc.
        if ($entry -match '^(.+)/(\d{1,3})$') {
            $addr      = $Matches[1]
            $prefixLen = [int]$Matches[2]
        }

        # Validate address
        $ip = $null
        if (-not [System.Net.IPAddress]::TryParse($addr, [ref]$ip)) {
            $invalidEntries.Add($entry)
            continue
        }

        # Validate prefix length
        if ($null -ne $prefixLen) {
            $maxLen = if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
                32
            }
            else {
                128
            }
            if ($prefixLen -lt 0 -or $prefixLen -gt $maxLen) {
                $invalidEntries.Add($entry)
            }
        }
    }

    if ($checked -eq 0) {
        return @{ IsValid = $false; Error = 'AllowedIPs not specified'; InvalidEntries = @() }
    }

    if ($invalidEntries.Count -gt 0) {
        return @{
            IsValid        = $false
            Error          = "Invalid entries: $($invalidEntries -join ', ')"
            InvalidEntries = $invalidEntries
        }
    }

    return @{ IsValid = $true; Error = $null; InvalidEntries = @() }
}


# =============================================================================
#  SECTION 5: FORMATTING AND DISPLAY
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

function Format-UnixTimestamp {
    <#
    .SYNOPSIS
        Formats Unix timestamp to local date-time.
        Accepts number, string with number, 'null' or $null.
    #>
    param(
        $Timestamp,
        [string]$Format = 'dd.MM.yyyy HH:mm'
    )

    if ($null -eq $Timestamp) { return '—' }

    if ($Timestamp -is [string]) {
        if ($Timestamp -eq 'null' -or $Timestamp -notmatch '^\d+$') { return '—' }
        $Timestamp = [long]$Timestamp
    }

    $ts = [long]$Timestamp
    if ($ts -le 0) { return '—' }

    try {
        return [DateTimeOffset]::FromUnixTimeSeconds($ts).LocalDateTime.ToString($Format)
    }
    catch {
        return $ts.ToString()
    }
}

function Format-TimeAgo {
    <#
    .SYNOPSIS
        Formats Unix timestamp as "time ago":
        "just now", "5 min ago", "3 h ago", "2 d ago", date.
    #>
    param(
        $UnixTimestamp,
        [DateTime]$Now = (Get-Date)
    )

    if ($null -eq $UnixTimestamp) { return 'never' }

    if ($UnixTimestamp -is [string]) {
        if ($UnixTimestamp -notmatch '^\d+$') { return 'never' }
        $UnixTimestamp = [long]$UnixTimestamp
    }

    $ts = [long]$UnixTimestamp
    if ($ts -le 0) { return 'never' }

    try {
        $time = [DateTimeOffset]::FromUnixTimeSeconds($ts).LocalDateTime
    }
    catch {
        return 'never'
    }

    $diff = $Now - $time

    # Server and client clocks may differ
    if ($diff.TotalSeconds -lt 60)  { return 'just now' }
    if ($diff.TotalMinutes -lt 60)  { return "$([int]$diff.TotalMinutes) min ago" }
    if ($diff.TotalHours   -lt 24)  { return "$([int]$diff.TotalHours) h ago" }
    if ($diff.TotalDays    -lt 30)  { return "$([int]$diff.TotalDays) d ago" }

    return $time.ToString('dd.MM.yyyy')
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