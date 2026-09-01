#requires -Version 7.5
# =============================================================================
#  AddClientForm.ps1 — Dialog for adding a new client
#  Version: 0.1
#  Description: Dialog for creating new AmneziaWG clients with options
#               for PSK and expiration time.
# =============================================================================

function Show-AddClientForm {
    param([System.Windows.Forms.Form]$ParentForm)
    
    if (-not $script:App.ClientManager) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_ConnectFirst"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $dialog = [System.Windows.Forms.Form]::new()
    $dialog.Text = Get-String -Key "AddClient_Title"
    $dialog.Size = [System.Drawing.Size]::new(440, 380)
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.Font = [System.Drawing.Font]::new("Segoe UI", 9)
    
    # === Main group ===
    $grpMain = [System.Windows.Forms.GroupBox]::new()
    $grpMain.Text = Get-String -Key "AddClient_Title"
    $grpMain.Location = [System.Drawing.Point]::new(15, 15)
    $grpMain.Size = [System.Drawing.Size]::new(395, 80)
    $dialog.Controls.Add($grpMain)
    
    $lblName = [System.Windows.Forms.Label]::new()
    $lblName.Text = Get-String -Key "AddClient_Name"
    $lblName.Location = [System.Drawing.Point]::new(15, 30)
    $lblName.AutoSize = $true
    $grpMain.Controls.Add($lblName)
    
    $txtName = [System.Windows.Forms.TextBox]::new()
    $txtName.Location = [System.Drawing.Point]::new(120, 27)
    $txtName.Size = [System.Drawing.Size]::new(250, 23)
    $grpMain.Controls.Add($txtName)
    
    $lblNameHint = [System.Windows.Forms.Label]::new()
    $lblNameHint.Text = Get-String -Key "AddClient_NameHint"
    $lblNameHint.Location = [System.Drawing.Point]::new(15, 55)
    $lblNameHint.AutoSize = $true
    $lblNameHint.ForeColor = [System.Drawing.Color]::Gray
    $lblNameHint.Font = [System.Drawing.Font]::new("Segoe UI", 8)
    $grpMain.Controls.Add($lblNameHint)
    
    # === Options group ===
    $grpOptions = [System.Windows.Forms.GroupBox]::new()
    $grpOptions.Text = Get-String -Key "AddClient_Options"
    $grpOptions.Location = [System.Drawing.Point]::new(15, 105)
    $grpOptions.Size = [System.Drawing.Size]::new(395, 140)
    $dialog.Controls.Add($grpOptions)
    
    $chkPSK = [System.Windows.Forms.CheckBox]::new()
    $chkPSK.Text = Get-String -Key "AddClient_PSK"
    $chkPSK.Location = [System.Drawing.Point]::new(15, 25)
    $chkPSK.AutoSize = $true
    $grpOptions.Controls.Add($chkPSK)
    
    $chkExpires = [System.Windows.Forms.CheckBox]::new()
    $chkExpires.Text = Get-String -Key "AddClient_Expires"
    $chkExpires.Location = [System.Drawing.Point]::new(15, 55)
    $chkExpires.AutoSize = $true
    $grpOptions.Controls.Add($chkExpires)
    
    $lblDuration = [System.Windows.Forms.Label]::new()
    $lblDuration.Text = Get-String -Key "AddClient_Duration"
    $lblDuration.Location = [System.Drawing.Point]::new(40, 85)
    $lblDuration.AutoSize = $true
    $grpOptions.Controls.Add($lblDuration)
    
    $numValue = [System.Windows.Forms.NumericUpDown]::new()
    $numValue.Location = [System.Drawing.Point]::new(90, 82)
    $numValue.Size = [System.Drawing.Size]::new(60, 23)
    $numValue.Minimum = 1
    $numValue.Maximum = 365
    $numValue.Value = 7
    $numValue.Enabled = $false
    $grpOptions.Controls.Add($numValue)
    
    $cboUnit = [System.Windows.Forms.ComboBox]::new()
    $cboUnit.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cboUnit.Items.AddRange(@(
        (Get-String -Key "AddClient_UnitHours"),
        (Get-String -Key "AddClient_UnitDays"),
        (Get-String -Key "AddClient_UnitWeeks")
    ))
    $cboUnit.SelectedIndex = 1
    $cboUnit.Location = [System.Drawing.Point]::new(160, 82)
    $cboUnit.Size = [System.Drawing.Size]::new(120, 23)
    $cboUnit.Enabled = $false
    $grpOptions.Controls.Add($cboUnit)
    
    $chkExpires.Add_CheckedChanged({
        $numValue.Enabled = $chkExpires.Checked
        $cboUnit.Enabled = $chkExpires.Checked
    })
    
    # === Info panel ===
    $lblInfo = [System.Windows.Forms.Label]::new()
    $lblInfo.Text = Get-String -Key "AddClient_Info"
    $lblInfo.Location = [System.Drawing.Point]::new(15, 250)
    $lblInfo.Size = [System.Drawing.Size]::new(395, 30)
    $lblInfo.ForeColor = [System.Drawing.Color]::Gray
    $lblInfo.Font = [System.Drawing.Font]::new("Segoe UI", 8)
    $dialog.Controls.Add($lblInfo)
    
    # === Buttons ===
    $btnCreate = [System.Windows.Forms.Button]::new()
    $btnCreate.Text = Get-String -Key "AddClient_Create"
    $btnCreate.Location = [System.Drawing.Point]::new(195, 295)
    $btnCreate.Size = [System.Drawing.Size]::new(100, 32)
    $btnCreate.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $dialog.Controls.Add($btnCreate)
    
    $btnCancel = [System.Windows.Forms.Button]::new()
    $btnCancel.Text = Get-String -Key "AddClient_Cancel"
    $btnCancel.Location = [System.Drawing.Point]::new(305, 295)
    $btnCancel.Size = [System.Drawing.Size]::new(85, 32)
    $btnCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCancel.Add_Click({ $dialog.Close() })
    $dialog.Controls.Add($btnCancel)
    
    # === Validation ===
    $txtName.Add_TextChanged({
        $valid = $txtName.Text -match '^[a-zA-Z0-9_-]*$'
        $btnCreate.Enabled = $valid -and $txtName.Text.Length -gt 0 -and $txtName.Text.Length -le 32
        
        if (-not $valid -and $txtName.Text.Length -gt 0) {
            $lblNameHint.ForeColor = [System.Drawing.Color]::Red
            $lblNameHint.Text = Get-String -Key "AddClient_NameInvalid"
        }
        else {
            $lblNameHint.ForeColor = [System.Drawing.Color]::Gray
            $lblNameHint.Text = Get-String -Key "AddClient_NameHint"
        }
    })
    
    # === Create handler ===
    $btnCreate.Add_Click({
        $clientName = $txtName.Text.Trim()
        
        if ([string]::IsNullOrWhiteSpace($clientName)) {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "AddClient_NameRequired"),
                (Get-String -Key "Msg_Error"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        
        if ($clientName -notmatch '^[a-zA-Z0-9_-]+$') {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "AddClient_InvalidChars"),
                (Get-String -Key "Msg_Error"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        
        $expires = $null
        if ($chkExpires.Checked) {
            $unitLetter = switch ($cboUnit.SelectedIndex) {
                0 { "h" }
                1 { "d" }
                2 { "w" }
            }
            $expires = "$([int]$numValue.Value)$unitLetter"
        }
        
        $btnCreate.Enabled = $false
        $btnCreate.Text = Get-String -Key "AddClient_Creating"
        [System.Windows.Forms.Application]::DoEvents()
        
        try {
            $cm = $script:App.ClientManager
            $usePSK = [bool]$chkPSK.Checked
            $result = $cm.AddClient($clientName, $expires, $usePSK)
            
            if ($result.ok) {
                # Support both array 'results' and flat object responses
                $clientResult = $null
                if ($result.PSObject.Properties['results']) {
                    $clientResult = @($result.results | Where-Object { $_.name -eq $clientName }) | Select-Object -First 1
                } else {
                    $clientResult = $result
                }
                
                $report = (Get-String -Key "AddClient_Created" -Params $clientName) + "`n`n"
                
                if ($clientResult -and $clientResult.conf) {
                    $report += (Get-String -Key "AddClient_ConfigFile") + " $($clientResult.conf)`n"
                }
                if ($clientResult.qr) {
                    $report += (Get-String -Key "AddClient_QRCode") + " $($clientResult.qr)`n"
                }
                if ($clientResult.vpnuri) {
                    $report += (Get-String -Key "AddClient_VpnUri") + " $($clientResult.vpnuri)`n"
                }
                if ($clientResult.expires_at) {
                    $expiryDate = [DateTimeOffset]::FromUnixTimeSeconds([long]$clientResult.expires_at).LocalDateTime
                    $report += (Get-String -Key "AddClient_ExpiresAt") + " $($expiryDate.ToString('dd.MM.yyyy HH:mm'))`n"
                }
                
                [System.Windows.Forms.MessageBox]::Show(
                    $report,
                    (Get-String -Key "Msg_Info"),
                    "OK",
                    [System.Windows.Forms.MessageBoxIcon]::Information)
                
                $dialog.Close()
                Refresh-ClientsList
            }
            else {
                $errorMessage = "Server returned error: $($result.error)"
                
                $failedResult = $result.results | Where-Object { $_.name -eq $clientName }
                if ($failedResult -and $failedResult.status -eq "exists") {
                    $errorMessage += "`n`n" + (Get-String -Key "Error_ClientExists" -Params $clientName)
                }
                
                throw $errorMessage
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "AddClient_Error") + "`n$($_.Exception.Message)",
                (Get-String -Key "Msg_Error"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        finally {
            $btnCreate.Enabled = $true
            $btnCreate.Text = Get-String -Key "AddClient_Create"
        }
    })
    
    $dialog.Add_Shown({ $txtName.Focus() })
    
    $dialog.AcceptButton = $btnCreate
    $dialog.CancelButton = $btnCancel
    
    $dialog.ShowDialog($ParentForm) | Out-Null
    $dialog.Dispose()
}