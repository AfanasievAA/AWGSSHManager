#requires -Version 7.5
# =============================================================================
#  ProfileForm.ps1 — Dialog for creating/editing server profile
#  Version: 0.1
#  Description: Dialog for creating and editing SSH server profiles.
#               Supports key-based and password authentication.
#               Passwords are stored encrypted using DPAPI.
# =============================================================================

function Show-ProfileForm {
    param(
        [System.Windows.Forms.Form]$ParentForm,
        $ProfileManager,
        [string]$Mode = "Add",
        $ExistingProfile = $null
    )
    
    $dialog = [System.Windows.Forms.Form]::new()
    $dialog.Text = if ($Mode -eq "Add") { Get-String -Key "Profile_Title_Add" } else { Get-String -Key "Profile_Title_Edit" }
    $dialog.Size = [System.Drawing.Size]::new(480, 520)
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.Font = [System.Drawing.Font]::new("Segoe UI", 9)
    
    # === Connection parameters group ===
    $grpConnection = [System.Windows.Forms.GroupBox]::new()
    $grpConnection.Text = Get-String -Key "Profile_Connection"
    $grpConnection.Location = [System.Drawing.Point]::new(15, 15)
    $grpConnection.Size = [System.Drawing.Size]::new(440, 160)
    $dialog.Controls.Add($grpConnection)
    
    $lblProfileName = [System.Windows.Forms.Label]::new()
    $lblProfileName.Text = Get-String -Key "Profile_Name"
    $lblProfileName.Location = [System.Drawing.Point]::new(15, 30)
    $lblProfileName.AutoSize = $true
    $grpConnection.Controls.Add($lblProfileName)
    
    $txtProfileName = [System.Windows.Forms.TextBox]::new()
    $txtProfileName.Location = [System.Drawing.Point]::new(150, 27)
    $txtProfileName.Size = [System.Drawing.Size]::new(270, 23)
    if ($ExistingProfile) { $txtProfileName.Text = $ExistingProfile.Name }
    $grpConnection.Controls.Add($txtProfileName)
    
    $lblHost = [System.Windows.Forms.Label]::new()
    $lblHost.Text = Get-String -Key "Profile_Host"
    $lblHost.Location = [System.Drawing.Point]::new(15, 60)
    $lblHost.AutoSize = $true
    $grpConnection.Controls.Add($lblHost)
    
    $txtHost = [System.Windows.Forms.TextBox]::new()
    $txtHost.Location = [System.Drawing.Point]::new(150, 57)
    $txtHost.Size = [System.Drawing.Size]::new(270, 23)
    if ($ExistingProfile) { $txtHost.Text = $ExistingProfile.Host }
    $grpConnection.Controls.Add($txtHost)
    
    $lblPort = [System.Windows.Forms.Label]::new()
    $lblPort.Text = Get-String -Key "Profile_Port"
    $lblPort.Location = [System.Drawing.Point]::new(15, 90)
    $lblPort.AutoSize = $true
    $grpConnection.Controls.Add($lblPort)
    
    $numPort = [System.Windows.Forms.NumericUpDown]::new()
    $numPort.Location = [System.Drawing.Point]::new(150, 87)
    $numPort.Size = [System.Drawing.Size]::new(80, 23)
    $numPort.Minimum = 1
    $numPort.Maximum = 65535
    $numPort.Value = if ($ExistingProfile -and $ExistingProfile.Port) { $ExistingProfile.Port } else { 22 }
    $grpConnection.Controls.Add($numPort)
    
    $lblUser = [System.Windows.Forms.Label]::new()
    $lblUser.Text = Get-String -Key "Profile_User"
    $lblUser.Location = [System.Drawing.Point]::new(15, 120)
    $lblUser.AutoSize = $true
    $grpConnection.Controls.Add($lblUser)
    
    $txtUser = [System.Windows.Forms.TextBox]::new()
    $txtUser.Location = [System.Drawing.Point]::new(150, 117)
    $txtUser.Size = [System.Drawing.Size]::new(270, 23)
    $txtUser.Text = if ($ExistingProfile -and $ExistingProfile.User) { $ExistingProfile.User } else { "root" }
    $grpConnection.Controls.Add($txtUser)
    
    # === Authentication group ===
    $grpAuth = [System.Windows.Forms.GroupBox]::new()
    $grpAuth.Text = Get-String -Key "Profile_Auth"
    $grpAuth.Location = [System.Drawing.Point]::new(15, 185)
    $grpAuth.Size = [System.Drawing.Size]::new(440, 200)
    $dialog.Controls.Add($grpAuth)
    
    $rbKey = [System.Windows.Forms.RadioButton]::new()
    $rbKey.Text = Get-String -Key "Profile_Key"
    $rbKey.Location = [System.Drawing.Point]::new(15, 25)
    $rbKey.AutoSize = $true
    $rbKey.Checked = $true
    $grpAuth.Controls.Add($rbKey)
    
    $lblKeyPath = [System.Windows.Forms.Label]::new()
    $lblKeyPath.Text = Get-String -Key "Profile_KeyPath"
    $lblKeyPath.Location = [System.Drawing.Point]::new(35, 55)
    $lblKeyPath.AutoSize = $true
    $grpAuth.Controls.Add($lblKeyPath)
    
    $txtKeyPath = [System.Windows.Forms.TextBox]::new()
    $txtKeyPath.Location = [System.Drawing.Point]::new(35, 80)
    $txtKeyPath.Size = [System.Drawing.Size]::new(300, 23)
    if ($ExistingProfile -and $ExistingProfile.PrivateKeyPath) {
        $txtKeyPath.Text = $ExistingProfile.PrivateKeyPath
        $rbKey.Checked = $true
    }
    $grpAuth.Controls.Add($txtKeyPath)
    
    $btnBrowseKey = [System.Windows.Forms.Button]::new()
    $btnBrowseKey.Text = "..."
    $btnBrowseKey.Location = [System.Drawing.Point]::new(345, 78)
    $btnBrowseKey.Size = [System.Drawing.Size]::new(30, 26)
    $btnBrowseKey.Add_Click({
        $openDialog = [System.Windows.Forms.OpenFileDialog]::new()
        $openDialog.Filter = "Private keys|*|All files (*.*)|*.*"
        $openDialog.Title = "Select private key"
        $openDialog.InitialDirectory = "$env:USERPROFILE\.ssh"
        
        if ($openDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtKeyPath.Text = $openDialog.FileName
        }
    })
    $grpAuth.Controls.Add($btnBrowseKey)
    
    $rbPassword = [System.Windows.Forms.RadioButton]::new()
    $rbPassword.Text = Get-String -Key "Profile_Password"
    $rbPassword.Location = [System.Drawing.Point]::new(15, 115)
    $rbPassword.AutoSize = $true
    $grpAuth.Controls.Add($rbPassword)
    
    $lblPassword = [System.Windows.Forms.Label]::new()
    $lblPassword.Text = Get-String -Key "Profile_PasswordField"
    $lblPassword.Location = [System.Drawing.Point]::new(35, 140)
    $lblPassword.AutoSize = $true
   # $grpAuth.Controls.Add($lblPassword)
    
    $txtPassword = [System.Windows.Forms.TextBox]::new()
    $txtPassword.UseSystemPasswordChar = $true
    $txtPassword.Location = [System.Drawing.Point]::new(35, 158)
    $txtPassword.Size = [System.Drawing.Size]::new(340, 23)
    if ($ExistingProfile -and $ExistingProfile.PasswordEncrypted) {
        $txtPassword.Text = $ExistingProfile.PasswordEncrypted
        $rbPassword.Checked = $true
        $rbKey.Checked = $false
    }
    $grpAuth.Controls.Add($txtPassword)
    
    $lblWarning = [System.Windows.Forms.Label]::new()
    $lblWarning.Text = Get-String -Key "Profile_PasswordWarning"
    $lblWarning.Location = [System.Drawing.Point]::new(35, 135)
    $lblWarning.AutoSize = $true
    $lblWarning.ForeColor = [System.Drawing.Color]::Orange
    $lblWarning.Font = [System.Drawing.Font]::new("Segoe UI", 8)
    $grpAuth.Controls.Add($lblWarning)
    
    $rbKey.Add_CheckedChanged({
        $txtKeyPath.Enabled = $rbKey.Checked
        $btnBrowseKey.Enabled = $rbKey.Checked
        $txtPassword.Enabled = -not $rbKey.Checked
    })
    
    $rbPassword.Add_CheckedChanged({
        $txtKeyPath.Enabled = -not $rbPassword.Checked
        $btnBrowseKey.Enabled = -not $rbPassword.Checked
        $txtPassword.Enabled = $rbPassword.Checked
    })
    
    $txtPassword.Enabled = $false
    
    # === Buttons ===
    $btnSave = [System.Windows.Forms.Button]::new()
    $btnSave.Text = if ($Mode -eq "Add") { Get-String -Key "Profile_Create" } else { Get-String -Key "Profile_Save" }
    $btnSave.Location = [System.Drawing.Point]::new(195, 420)
    $btnSave.Size = [System.Drawing.Size]::new(120, 32)
    $btnSave.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $dialog.Controls.Add($btnSave)
    
    $btnCancel = [System.Windows.Forms.Button]::new()
    $btnCancel.Text = Get-String -Key "Profile_Cancel"
    $btnCancel.Location = [System.Drawing.Point]::new(325, 420)
    $btnCancel.Size = [System.Drawing.Size]::new(90, 32)
    $btnCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCancel.Add_Click({ $dialog.Close() })
    $dialog.Controls.Add($btnCancel)
    
    # === Validation and save ===
    $btnSave.Add_Click({
        $errors = @()
        
        if ([string]::IsNullOrWhiteSpace($txtProfileName.Text)) {
            $errors += Get-String -Key "Profile_Validate_Name"
        }
        
        if ([string]::IsNullOrWhiteSpace($txtHost.Text)) {
            $errors += Get-String -Key "Profile_Validate_Host"
        }
        
        if ($rbKey.Checked -and [string]::IsNullOrWhiteSpace($txtKeyPath.Text)) {
            $errors += Get-String -Key "Profile_Validate_KeyPath"
        }
        
        if ($rbKey.Checked -and -not (Test-Path $txtKeyPath.Text)) {
            $errors += (Get-String -Key "Profile_Validate_KeyNotFound" -Params $txtKeyPath.Text)
        }
        
        if ($rbPassword.Checked -and [string]::IsNullOrWhiteSpace($txtPassword.Text)) {
            $errors += Get-String -Key "Profile_Validate_Password"
        }
        
        if ($errors.Count -gt 0) {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Profile_Validate_Errors") + "`n`n" + ($errors -join "`n"),
                (Get-String -Key "Msg_Error"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        
        $profile = if ($ExistingProfile) { $ExistingProfile } else { [SSHProfile]::new() }
        
        $profile.Name = $txtProfileName.Text.Trim()
        $profile.Host = $txtHost.Text.Trim()
        $profile.Port = [int]$numPort.Value
        $profile.User = $txtUser.Text.Trim()
        
        if ($rbKey.Checked) {
            $profile.PrivateKeyPath = $txtKeyPath.Text
            $profile.PasswordEncrypted = $null
        }
        else {
            $profile.PrivateKeyPath = $null
            $profile.PasswordEncrypted = $txtPassword.Text
        }
        
        $testConnection = [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Profile_Test"),
            (Get-String -Key "Profile_Test"),
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question)
        
        if ($testConnection -eq [System.Windows.Forms.DialogResult]::Yes) {
            $btnSave.Enabled = $false
            $btnSave.Text = "Testing..."
            [System.Windows.Forms.Application]::DoEvents()
            
            try {
                $sshManager = [SSHManager]::new($profile)
                $result = $sshManager.InvokeCommand("list --json")
                
                if ($result.Success) {
                    [System.Windows.Forms.MessageBox]::Show(
                        (Get-String -Key "Profile_Test_Success"),
                        (Get-String -Key "Msg_Info"),
                        "OK",
                        [System.Windows.Forms.MessageBoxIcon]::Information)
                }
                else {
                    $continueAnyway = [System.Windows.Forms.MessageBox]::Show(
                        (Get-String -Key "Profile_Test_Failed" -Params $result.Error),
                        (Get-String -Key "Msg_Warning"),
                        [System.Windows.Forms.MessageBoxButtons]::YesNo,
                        [System.Windows.Forms.MessageBoxIcon]::Warning)
                    
                    if ($continueAnyway -ne [System.Windows.Forms.DialogResult]::Yes) {
                        return
                    }
                }
            }
            catch {
                $continueAnyway = [System.Windows.Forms.MessageBox]::Show(
                    (Get-String -Key "Profile_Test_Error" -Params $_.Exception.Message),
                    (Get-String -Key "Msg_Error"),
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Warning)
                
                if ($continueAnyway -ne [System.Windows.Forms.DialogResult]::Yes) {
                    return
                }
            }
            finally {
                $btnSave.Enabled = $true
                $btnSave.Text = if ($Mode -eq "Add") { Get-String -Key "Profile_Create" } else { Get-String -Key "Profile_Save" }
            }
        }
        
        try {
            $ProfileManager.SaveProfile($profile)
            
            $script:App.Profiles = $ProfileManager.LoadAllProfiles()
            
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Profile_Saved" -Params $profile.Name),
                (Get-String -Key "Msg_Info"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Information)
            
            $dialog.Close()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Error_ProfileSave" -Params $_.Exception.Message),
                (Get-String -Key "Msg_Error"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    
    $dialog.ShowDialog($ParentForm) | Out-Null
    $dialog.Dispose()
}