#requires -Version 7.5
# =============================================================================
#  Classes.ps1 — Core classes for AmneziaWG Admin (SSH.NET powered)
#  Version: 0.4
#  Description: Defines SSHProfile, SSHManager, ProfileManager, and ClientManager.
#               Uses SSH.NET for persistent, high-speed connections.
# =============================================================================

# =============================================================================
#  SSHProfile — server connection profile
# =============================================================================
class SSHProfile {
    [string]$Name
    [string]$Host
    [int]$Port = 22
    [string]$User = "root"
    [string]$PrivateKeyPath      # Path to private key (or $null)
    [string]$PasswordEncrypted   # Password (in memory; on disk — DPAPI)
}


# =============================================================================
#  SSHManager — persistent SSH/SCP connection via SSH.NET
# =============================================================================
class SSHManager {
    hidden [SSHProfile]$Profile
    hidden [string]$ManageScript = "/root/awg/manage_amneziawg.sh"
    # Using [object] to prevent IDE static analysis errors for dynamic DLL
    hidden [object]$Client
    hidden [object]$ScpClient

    SSHManager([SSHProfile]$profile) {
        $this.Profile = $profile

        $keySet  = -not [string]::IsNullOrWhiteSpace($profile.PrivateKeyPath)
        $passSet = -not [string]::IsNullOrWhiteSpace($profile.PasswordEncrypted)

        $auth = $null
        if ($keySet) {
            if (-not (Test-Path -LiteralPath $profile.PrivateKeyPath)) {
                throw (Get-String -Key "Error_PrivateKeyNotFound" -Params $profile.PrivateKeyPath)
            }
            $keyFile = New-Object -TypeName 'Renci.SshNet.PrivateKeyFile' -ArgumentList $profile.PrivateKeyPath
            $auth = New-Object -TypeName 'Renci.SshNet.PrivateKeyAuthenticationMethod' -ArgumentList $profile.User, $keyFile
        }
        elseif ($passSet) {
            $auth = New-Object -TypeName 'Renci.SshNet.PasswordAuthenticationMethod' -ArgumentList $profile.User, $profile.PasswordEncrypted
        }
        else {
            throw (Get-String -Key "Error_ProfileNoKeyOrPassword")
        }

        $connInfo = New-Object -TypeName 'Renci.SshNet.ConnectionInfo' -ArgumentList $profile.Host, $profile.Port, $profile.User, $auth
        $connInfo.Timeout = [TimeSpan]::FromSeconds(15)
        $connInfo.RetryAttempts = 1
        
        $this.Client = New-Object -TypeName 'Renci.SshNet.SshClient' -ArgumentList $connInfo
        $this.ScpClient = New-Object -TypeName 'Renci.SshNet.ScpClient' -ArgumentList $connInfo
    }

    [bool] IsConnected() {
        return ($null -ne $this.Client -and $this.Client.IsConnected)
    }

    [void] Connect() {
        if (-not $this.Client.IsConnected) { $this.Client.Connect() }
        if (-not $this.ScpClient.IsConnected) { $this.ScpClient.Connect() }
    }

    [void] Disconnect() {
        if ($this.Client.IsConnected) { $this.Client.Disconnect() }
        if ($this.ScpClient.IsConnected) { $this.ScpClient.Disconnect() }
    }

    hidden [hashtable] RunBash([string]$command, [string]$stdinData, [int]$timeoutSec) {
        $cmd = $null
        try {
            $this.Connect()
            $cmd = $this.Client.CreateCommand($command)
            $cmd.CommandTimeout = [TimeSpan]::FromSeconds($timeoutSec)
            
            $outputStr = ""

            # stdin data must go to InputStream BEFORE BeginExecute:
            # SSH.NET flushes it to the remote process at command start;
            # OutputStream is a read stream — writing to it never delivers data.
            if (-not [string]::IsNullOrWhiteSpace($stdinData)) {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($stdinData)
                $cmd.InputStream.Write($bytes, 0, $bytes.Length)
            }

            # Async is used for ALL commands: SSH.NET enforces CommandTimeout
            # only in the async path; synchronous Execute() may hang forever.
            $async = $cmd.BeginExecute()
            
            $timeoutMs = $timeoutSec * 1000
            $startTime = [System.Diagnostics.Stopwatch]::StartNew()
            
            while (-not $async.IsCompleted) {
                if ($startTime.ElapsedMilliseconds -gt $timeoutMs) {
                    $cmd.CancelAsync()
                    return @{
                        Success  = $false
                        Output   = $null
                        Error    = (Get-String -Key "Error_Timeout" -Params $timeoutSec, "Command took too long")
                        ExitCode = -1
                    }
                }
                [System.Threading.Thread]::Sleep(20)
            }
            $cmd.EndExecute($async)
            $outputStr = $cmd.Result
            
            return @{
                Success  = ($cmd.ExitStatus -eq 0)
                Output   = $outputStr
                Error    = $cmd.Error
                ExitCode = $cmd.ExitStatus
            }
        } catch {
            return @{
                Success  = $false
                Output   = $null
                Error    = $_.Exception.Message
                ExitCode = -1
            }
        } finally {
            if ($cmd) { try { $cmd.Dispose() } catch { } }
        }
    }

    [hashtable] InvokeRemote([string]$remoteCommand) {
        return $this.RunBash($remoteCommand, $null, 60)
    }

    # 1-argument overload: PowerShell classes do not apply default parameter
    # values during overload resolution, so InvokeCommand("cmd") without a
    # timeout would fail with "Cannot find an overload ... argument count: 1"
    [hashtable] InvokeCommand([string]$arguments) {
        return $this.InvokeCommand($arguments, 60)
    }

    [hashtable] InvokeCommand([string]$arguments, [int]$TimeoutSec) {
        $cleanArgs = $arguments.Trim()
        if ($cleanArgs -notmatch '(^|\s)--json(\s|$)') { $cleanArgs += " --json" }
        
        $stdinData = $null
        $remoteCmd = ""
        
        if ($this.Profile.User -eq "root") {
            $remoteCmd = "sudo -n bash -l $($this.ManageScript) $($cleanArgs)"
        } else {
            $remoteCmd = "sudo -S -p '' bash -l $($this.ManageScript) $($cleanArgs)"
            if (-not [string]::IsNullOrWhiteSpace($this.Profile.PasswordEncrypted)) {
                $stdinData = $this.Profile.PasswordEncrypted + "`n"
            }
        }
        
        return $this.RunBash($remoteCmd, $stdinData, $TimeoutSec)
    }

    # Runs a raw shell command as root: directly for root user, via sudo -S
    # (password on stdin) otherwise. No --json wrapping — judged by exit code.
    # $shellCommand must not contain single quotes.
    [hashtable] InvokeRootShell([string]$shellCommand, [int]$TimeoutSec) {
        $stdinData = $null
        $remoteCmd = ""
        if ($this.Profile.User -eq "root") {
            $remoteCmd = $shellCommand
        }
        else {
            $remoteCmd = "sudo -S -p '' bash -c '$shellCommand'"
            if (-not [string]::IsNullOrWhiteSpace($this.Profile.PasswordEncrypted)) {
                $stdinData = $this.Profile.PasswordEncrypted + "`n"
            }
        }
        return $this.RunBash($remoteCmd, $stdinData, $TimeoutSec)
    }

    [bool] UploadFile([string]$localPath, [string]$remotePath) {
        try {
            $this.Connect()
            $fileInfo = [System.IO.FileInfo]::new($localPath)
            $this.ScpClient.Upload($fileInfo, $remotePath)
            return $true
        }
        catch {
            return $false
        }
    }

    [bool] DownloadFile([string]$remotePath, [string]$localPath) {
        try {
            $this.Connect()
            $fileInfo = [System.IO.FileInfo]::new($localPath)
            $this.ScpClient.Download($remotePath, $fileInfo)
            # A zero-length file means the transfer failed; treat it as an error too
            return ((Test-Path -LiteralPath $localPath) -and (Get-Item -LiteralPath $localPath).Length -gt 0)
        }
        catch {
            Remove-Item -LiteralPath $localPath -Force -ErrorAction SilentlyContinue
            return $false
        }
    }

    [bool] DownloadQR([string]$clientName, [string]$localPath) {
        return $this.DownloadQR($clientName, $localPath, 'png')
    }

    [bool] DownloadQR([string]$clientName, [string]$localPath, [string]$kind) {
        $suffix = if ($kind -eq 'vpnuri') { '.vpnuri.png' } else { '.png' }
        $paths = @(
            "/root/awg/$clientName$suffix",
            "/root/awg/clients/$clientName/$clientName$suffix"
        )
        foreach ($p in $paths) {
            if ($this.DownloadFile($p, $localPath)) { return $true }
        }
        return $false
    }

    [string] GetLatestBackupPath() {
        $result = $this.InvokeRemote(
            "sudo -n /bin/ls -1t /root/awg/backups/awg_backup_*.tar.gz 2>/dev/null | head -1"
        )
        if (-not $result.Success -or [string]::IsNullOrWhiteSpace($result.Output)) {
            throw (Get-String -Key "Error_BackupNotFound")
        }
        return $result.Output.Trim()
    }

    [hashtable] GetServerInfo() {
        $cmd = 'TOOLS=$(awg --version 2>/dev/null | head -n 1); ' +
               'KERN=$(cat /sys/module/amneziawg/version 2>/dev/null); ' +
               'echo "$TOOLS|$KERN"'
        $result = $this.InvokeRemote($cmd)
        
        $tools = "N/A"
        $kern  = "N/A"
        
        if ($result.Success -and -not [string]::IsNullOrWhiteSpace($result.Output)) {
            $parts = $result.Output.Trim() -split '\|'
            if ($parts.Length -ge 1 -and -not [string]::IsNullOrWhiteSpace($parts[0])) {
                $tools = $parts[0].Trim()
            }
            if ($parts.Length -ge 2 -and -not [string]::IsNullOrWhiteSpace($parts[1])) {
                $kern = $parts[1].Trim()
            }
        }
        return @{ Tools = $tools; Kernel = $kern }
    }

    [bool] DownloadConfig([string]$clientName, [string]$localPath) {
        $remotePaths = @(
            "/root/awg/clients/$clientName/$clientName.conf",
            "/root/awg/$clientName.conf",
            "/root/awg/${clientName}_$clientName.conf"
        )

        foreach ($remotePath in $remotePaths) {
            if ($this.DownloadFile($remotePath, $localPath)) {
                return $true
            }
        }
        return $false
    }
}


# =============================================================================
#  ProfileManager — profile storage (DPAPI encryption for passwords)
# =============================================================================
class ProfileManager {
    hidden [string]$ConfigDir
    hidden [string]$ConfigPath

    ProfileManager() {
        $this.ConfigDir  = Join-Path $env:APPDATA "AmneziaWGAdmin"
        $this.ConfigPath = Join-Path $this.ConfigDir "profiles.json"
        if (-not (Test-Path -LiteralPath $this.ConfigDir)) {
            New-Item -ItemType Directory -Path $this.ConfigDir -Force | Out-Null
        }
    }

    [void] SaveProfile([SSHProfile]$profile) {
        $this.SaveProfile($profile, $null)
    }

    [void] SaveProfile([SSHProfile]$profile, [string]$OriginalName) {
        $toSave = [SSHProfile]::new()
        $toSave.Name            = $profile.Name
        $toSave.Host            = $profile.Host
        $toSave.Port            = $profile.Port
        $toSave.User            = $profile.User
        $toSave.PrivateKeyPath  = $profile.PrivateKeyPath
        if (-not [string]::IsNullOrWhiteSpace($profile.PasswordEncrypted)) {
            $sec = ConvertTo-SecureString $profile.PasswordEncrypted -AsPlainText -Force
            $toSave.PasswordEncrypted = ConvertFrom-SecureString $sec
        }

        $nameToMatch = if ([string]::IsNullOrWhiteSpace($OriginalName)) { $profile.Name } else { $OriginalName }
        $existing = @($this.LoadAllProfilesRaw())
        $filtered = @($existing | Where-Object { $_.Name -ne $nameToMatch })
        $filtered += $toSave

        $json = ConvertTo-Json -InputObject $filtered -Depth 5
        Set-Content -LiteralPath $this.ConfigPath -Value $json -Encoding UTF8

        try {
            # DACL-only read/write via .NET API: Get-Acl/Set-Acl pair round-trips
            # descriptor sections that require SeSecurityPrivilege and fails
            # on non-elevated processes; Access-only sections work without it
            $fileInfo = [System.IO.FileInfo]::new($this.ConfigPath)
            $sections = [System.Security.AccessControl.AccessControlSections]::Access
            $acl = [System.IO.FileSystemAclExtensions]::GetAccessControl($fileInfo, $sections)
            $acl.SetAccessRuleProtection($true, $false)
            $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                [System.Security.AccessControl.FileSystemRights]::FullControl,
                [System.Security.AccessControl.AccessControlType]::Allow)
            $acl.AddAccessRule($rule)
            [System.IO.FileSystemAclExtensions]::SetAccessControl($fileInfo, $acl)
        }
        catch {
            # Non-fatal: file already has default user-scoped ACL from %APPDATA%,
            # and the stored password is DPAPI-encrypted per-user
            Write-Warning "Failed to restrict profile file permissions: $($_.Exception.Message)"
        }
    }

    hidden [object] LoadAllProfilesRaw() {
        if (-not (Test-Path -LiteralPath $this.ConfigPath)) { return @() }
        $json = Get-Content -LiteralPath $this.ConfigPath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($json)) { return @() }
        $raw = ConvertFrom-Json $json
        if ($raw -is [System.Array]) { return $raw }
        return @($raw)
    }

    [SSHProfile[]] LoadAllProfiles() {
        $items = @($this.LoadAllProfilesRaw())
        $result = [System.Collections.Generic.List[SSHProfile]]::new()

        foreach ($item in $items) {
            $p = [SSHProfile]::new()
            $p.Name = [string]$item.Name
            $p.Host = [string]$item.Host
            $p.Port = if ($item.PSObject.Properties['Port'] -and $item.Port) { [int]$item.Port } else { 22 }
            $p.User = if ($item.PSObject.Properties['User'] -and $item.User) { [string]$item.User } else { "root" }

            if ($item.PSObject.Properties['PrivateKeyPath'] -and $item.PrivateKeyPath) {
                $p.PrivateKeyPath = [string]$item.PrivateKeyPath
            }

            if ($item.PSObject.Properties['PasswordEncrypted'] -and $item.PasswordEncrypted) {
                try {
                    $sec  = ConvertTo-SecureString -String ([string]$item.PasswordEncrypted)
                    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
                    $p.PasswordEncrypted = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                }
                catch {
                    $p.PasswordEncrypted = $null
                }
            }

            $result.Add($p)
        }
        return $result.ToArray()
    }

    [void] DeleteProfile([string]$name) {
        $existing = @($this.LoadAllProfilesRaw())
        $filtered = @($existing | Where-Object { $_.Name -ne $name })

        if ($filtered.Count -eq 0) {
            Remove-Item -LiteralPath $this.ConfigPath -Force -ErrorAction SilentlyContinue
            return
        }

        $json = ConvertTo-Json -InputObject $filtered -Depth 5
        Set-Content -LiteralPath $this.ConfigPath -Value $json -Encoding UTF8
    }
}


# =============================================================================
#  ClientManager — client operations via manage_amneziawg.sh
# =============================================================================
class ClientManager {
    hidden [SSHManager]$ssh
    hidden [string]$ManageScript = "/root/awg/manage_amneziawg.sh"

    ClientManager([SSHManager]$sshManager) {
        $this.ssh = $sshManager
    }

    hidden [PSCustomObject] ParseJson([hashtable]$result, [string]$context) {
        if (-not $result.Success) {
            throw "$context — SSH error (code $($result.ExitCode)): $($result.Error)"
        }
        # Handle empty server responses gracefully
        if ([string]::IsNullOrWhiteSpace($result.Output)) {
            return $null
        }
        try {
            return $result.Output | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "JSON parse error: $($_.Exception.Message)"
        }
    }

    [PSCustomObject[]] GetClients() {
        $result = $this.ssh.InvokeCommand("list --json")
        $data = $this.ParseJson($result, "list")
        if ($null -eq $data) { return @() }
        if ($data -is [System.Array]) { return $data }
        return @($data)
    }

    [PSCustomObject[]] GetClientStats() {
        $result = $this.ssh.InvokeCommand("stats --json")
        $data = $this.ParseJson($result, "stats")
        if ($null -eq $data) { return @() }
        if ($data -is [System.Array]) { return $data }
        return @($data)
    }

    [PSCustomObject] AddClient([string]$name) {
        return $this.AddClient($name, $null, $false)
    }

    [PSCustomObject] AddClient([string]$name, [string]$expires) {
        return $this.AddClient($name, $expires, $false)
    }

    [PSCustomObject] AddClient([string]$name, [string]$expires, [bool]$usePSK) {
        $cmd = "add $($name.Trim())"
        if (-not [string]::IsNullOrWhiteSpace($expires)) {
            $cmd += " --expires=$expires"
        }
        if ($usePSK) { $cmd += " --psk" }

        $result = $this.ssh.InvokeCommand($cmd)
        return $this.ParseJson($result, "add")
    }

    [PSCustomObject] RemoveClient([string]$name) {
        $result = $this.ssh.InvokeCommand("remove $($name.Trim()) --yes")
        return $this.ParseJson($result, "remove")
    }

    [PSCustomObject] ModifyClient([string]$name, [string]$param, [string]$value) {
        $valid = @("DNS", "Endpoint", "AllowedIPs", "PersistentKeepalive")
        if ($param -notin $valid) {
            throw (Get-String -Key "Error_InvalidParam" -Params $param, ($valid -join ', '))
        }
        # Reject characters that could break out of the quoted remote shell argument
        if ($value -match '["`$\\]') {
            throw (Get-String -Key "Error_InvalidValue" -Params $param, $value)
        }
        $result = $this.ssh.InvokeCommand("modify $($name.Trim()) $param `"$value`"")
        return $this.ParseJson($result, "modify")
    }

    [PSCustomObject] RegenClient([string]$name) {
        return $this.RegenClient($name, $false)
    }

    [PSCustomObject] RegenClient([string]$name, [bool]$resetRoutes) {
        $cmd = "regen $($name.Trim())"
        if ($resetRoutes) { $cmd += " --reset-routes" }

        $result = $this.ssh.InvokeCommand($cmd)
        return $this.ParseJson($result, "regen")
    }

    [PSCustomObject] RestoreBackup([string]$remotePath) {
        $result = $this.ssh.InvokeCommand("restore $remotePath --yes", 180)
        return $this.ParseJson($result, "restore")
    }

    [hashtable] CreateBackup() {
        $result = $this.ssh.InvokeCommand("backup", 180)
        if (-not $result.Success) {
            return @{
                Success = $false
                Error   = "Command backup failed with code $($result.ExitCode): $($result.Error)"
            }
        }
        $json = $null
        try { $json = $result.Output | ConvertFrom-Json -ErrorAction Stop } catch { }
        return @{ Success = $true; Error = $null; Json = $json }
    }

    [PSCustomObject] RestartService() {
        $result = $this.ssh.InvokeCommand("restart")
        return $this.ParseJson($result, "restart")
    }

    # Downloads manage_amneziawg.sh + awg_common.sh from the LATEST release as
    # a PAIR: both staged as .new first, originals replaced only after both
    # downloads succeed. A failed wget can never leave a half-updated pair
    # (which the scripts refuse to run). Timeout 180 s: two HTTPS downloads.
    [hashtable] UpdateScripts([bool]$englishVersion) {
        $suffix = if ($englishVersion) { "_en" } else { "" }
        $base   = "https://github.com/bivlked/amneziawg-installer/releases/latest/download"
        $chain  =
            "rm -f /root/awg/manage_amneziawg.sh.new /root/awg/awg_common.sh.new; " +
            "wget -q -O /root/awg/manage_amneziawg.sh.new $base/manage_amneziawg$suffix.sh && " +
            "wget -q -O /root/awg/awg_common.sh.new $base/awg_common$suffix.sh && " +
            "chmod 700 /root/awg/manage_amneziawg.sh.new /root/awg/awg_common.sh.new && " +
            "mv -f /root/awg/manage_amneziawg.sh.new /root/awg/manage_amneziawg.sh && " +
            "mv -f /root/awg/awg_common.sh.new /root/awg/awg_common.sh || " +
            "{ rm -f /root/awg/manage_amneziawg.sh.new /root/awg/awg_common.sh.new; exit 1; }"
        return $this.ssh.InvokeRootShell($chain, 180)
    }

    [string] GetClientConfig([string]$clientName) {
        # sudo is required for non-root users to read /root/awg
        $result = $this.ssh.InvokeRemote(
            "sudo -n cat /root/awg/clients/$clientName/$clientName.conf 2>/dev/null || sudo -n cat /root/awg/$clientName.conf 2>/dev/null"
        )
        if (-not $result.Success -or [string]::IsNullOrWhiteSpace($result.Output)) {
            throw (Get-String -Key "Error_ConfigReadFailed" -Params $clientName, $result.Error)
        }
        return (($result.Output.TrimEnd()) -split '\r?\n') -join "`r`n"
    }
}