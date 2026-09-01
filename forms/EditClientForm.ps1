#requires -Version 7.5
# =============================================================================
#  EditClientForm.ps1 — Dialog for editing client parameters
#  Version: 0.1
#  Description: Dialog for editing client configuration parameters:
#               DNS, Endpoint, AllowedIPs, PersistentKeepalive.
# =============================================================================

function Show-EditClientForm {
    if ($script:dgvClients.SelectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_SelectClient"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    if (-not $script:App.ClientManager) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_ConnectFirst"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $clientName = $script:dgvClients.SelectedRows[0].Cells["Name"].Value
    
    $dialog = [System.Windows.Forms.Form]::new()
    $dialog.Text = Get-String -Key "EditClient_Title" -Params $clientName
    $dialog.Size = [System.Drawing.Size]::new(500, 480)
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.Font = [System.Drawing.Font]::new("Segoe UI", 9)
    
    # === Load current config ===
    $currentConfig = $null
    
    $lblLoading = [System.Windows.Forms.Label]::new()
    $lblLoading.Text = Get-String -Key "EditClient_Loading"
    $lblLoading.Location = [System.Drawing.Point]::new(15, 15)
    $lblLoading.AutoSize = $true
    $lblLoading.ForeColor = [System.Drawing.Color]::Gray
    $dialog.Controls.Add($lblLoading)
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        $cm = $script:App.ClientManager
        $currentConfig = $cm.GetClientConfig($clientName)
    } catch {
        $currentConfig = $null
    }
    
    $dialog.Controls.Remove($lblLoading)
    
    # === Parse current values ===
    $currentDNS = "1.1.1.1, 1.0.0.1"
    $currentEndpoint = ""
    $currentAllowedIPs = "0.0.0.0/0"
    $currentKeepalive = "25"
    
    if ($currentConfig) {
        foreach ($line in ($currentConfig -split '\r?\n')) {
            if ($line -match '^\s*DNS\s*=\s*(.+)$') {
                $currentDNS = $Matches[1].Trim()
            }
            elseif ($line -match '^\s*Endpoint\s*=\s*(.+)$') {
                $currentEndpoint = $Matches[1].Trim()
            }
            elseif ($line -match '^\s*AllowedIPs\s*=\s*(.+)$') {
                $currentAllowedIPs = $Matches[1].Trim()
            }
            elseif ($line -match '^\s*PersistentKeepalive\s*=\s*(.+)$') {
                $currentKeepalive = $Matches[1].Trim()
            }
        }
        # Trim all loaded values to prevent false "modified" detection
        $currentDNS = $currentDNS.Trim()
        $currentEndpoint = $currentEndpoint.Trim()
        $currentAllowedIPs = $currentAllowedIPs.Trim()
        $currentKeepalive = $currentKeepalive.Trim()
    }
    
    # === DNS group ===
    $grpDNS = [System.Windows.Forms.GroupBox]::new()
    $grpDNS.Text = Get-String -Key "EditClient_DNS"
    $grpDNS.Location = [System.Drawing.Point]::new(15, 15)
    $grpDNS.Size = [System.Drawing.Size]::new(455, 85)
    $dialog.Controls.Add($grpDNS)
    
    $txtDNS = [System.Windows.Forms.TextBox]::new()
    $txtDNS.Text = $currentDNS
    $txtDNS.Location = [System.Drawing.Point]::new(15, 25)
    $txtDNS.Size = [System.Drawing.Size]::new(425, 23)
    $grpDNS.Controls.Add($txtDNS)
    
    $lblDNSHint = [System.Windows.Forms.Label]::new()
    $lblDNSHint.Text = Get-String -Key "EditClient_DNSHint"
    $lblDNSHint.Location = [System.Drawing.Point]::new(15, 55)
    $lblDNSHint.AutoSize = $true
    $lblDNSHint.ForeColor = [System.Drawing.Color]::Gray
    $lblDNSHint.Font = [System.Drawing.Font]::new("Segoe UI", 8)
    $grpDNS.Controls.Add($lblDNSHint)
    
    # === Endpoint group ===
    $grpEndpoint = [System.Windows.Forms.GroupBox]::new()
    $grpEndpoint.Text = Get-String -Key "EditClient_Endpoint"
    $grpEndpoint.Location = [System.Drawing.Point]::new(15, 110)
    $grpEndpoint.Size = [System.Drawing.Size]::new(455, 85)
    $dialog.Controls.Add($grpEndpoint)
    
    $txtEndpoint = [System.Windows.Forms.TextBox]::new()
    $txtEndpoint.Text = $currentEndpoint
    $txtEndpoint.Location = [System.Drawing.Point]::new(15, 25)
    $txtEndpoint.Size = [System.Drawing.Size]::new(425, 23)
    $grpEndpoint.Controls.Add($txtEndpoint)
    
    $lblEndpointHint = [System.Windows.Forms.Label]::new()
    $lblEndpointHint.Text = Get-String -Key "EditClient_EndpointHint"
    $lblEndpointHint.Location = [System.Drawing.Point]::new(15, 55)
    $lblEndpointHint.AutoSize = $true
    $lblEndpointHint.ForeColor = [System.Drawing.Color]::Gray
    $lblEndpointHint.Font = [System.Drawing.Font]::new("Segoe UI", 8)
    $grpEndpoint.Controls.Add($lblEndpointHint)
    
    # === AllowedIPs group ===
    $grpAllowedIPs = [System.Windows.Forms.GroupBox]::new()
    $grpAllowedIPs.Text = Get-String -Key "EditClient_AllowedIPs"
    $grpAllowedIPs.Location = [System.Drawing.Point]::new(15, 205)
    $grpAllowedIPs.Size = [System.Drawing.Size]::new(455, 110)
    $dialog.Controls.Add($grpAllowedIPs)
    
    $txtAllowedIPs = [System.Windows.Forms.TextBox]::new()
    $txtAllowedIPs.Text = $currentAllowedIPs
    $txtAllowedIPs.Location = [System.Drawing.Point]::new(15, 25)
    $txtAllowedIPs.Size = [System.Drawing.Size]::new(425, 23)
    $grpAllowedIPs.Controls.Add($txtAllowedIPs)
    
    $lblPresets = [System.Windows.Forms.Label]::new()
    $lblPresets.Text = Get-String -Key "EditClient_AllowedPreset"
    $lblPresets.Location = [System.Drawing.Point]::new(15, 55)
    $lblPresets.AutoSize = $true
    $grpAllowedIPs.Controls.Add($lblPresets)
    
    $btnPresetAll = [System.Windows.Forms.Button]::new()
    $btnPresetAll.Text = Get-String -Key "EditClient_AllTraffic"
    $btnPresetAll.Location = [System.Drawing.Point]::new(115, 52)
    $btnPresetAll.Size = [System.Drawing.Size]::new(100, 25)
    $btnPresetAll.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnPresetAll.Add_Click({ $txtAllowedIPs.Text = "0.0.0.0/0, ::/0" })
    $grpAllowedIPs.Controls.Add($btnPresetAll)
    
    $btnPresetPrivate = [System.Windows.Forms.Button]::new()
    $btnPresetPrivate.Text = Get-String -Key "EditClient_PrivateNetworks"
    $btnPresetPrivate.Location = [System.Drawing.Point]::new(220, 52)
    $btnPresetPrivate.Size = [System.Drawing.Size]::new(125, 25)
    $btnPresetPrivate.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnPresetPrivate.Add_Click({ $txtAllowedIPs.Text = "10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16" })
    $grpAllowedIPs.Controls.Add($btnPresetPrivate)
    
    $lblIPsHint = [System.Windows.Forms.Label]::new()
    $lblIPsHint.Text = Get-String -Key "EditClient_AllowedHint"
    $lblIPsHint.Location = [System.Drawing.Point]::new(15, 82)
    $lblIPsHint.AutoSize = $true
    $lblIPsHint.ForeColor = [System.Drawing.Color]::Gray
    $lblIPsHint.Font = [System.Drawing.Font]::new("Segoe UI", 8)
    $grpAllowedIPs.Controls.Add($lblIPsHint)
    
    # === Keepalive group ===
    $grpKeepalive = [System.Windows.Forms.GroupBox]::new()
    $grpKeepalive.Text = Get-String -Key "EditClient_Keepalive"
    $grpKeepalive.Location = [System.Drawing.Point]::new(15, 325)
    $grpKeepalive.Size = [System.Drawing.Size]::new(455, 60)
    $dialog.Controls.Add($grpKeepalive)
    
    $numKeepalive = [System.Windows.Forms.NumericUpDown]::new()
    $numKeepalive.Value = [int]($currentKeepalive -replace '\D', '')
    $numKeepalive.Minimum = 0
    $numKeepalive.Maximum = 65535
    $numKeepalive.Location = [System.Drawing.Point]::new(15, 25)
    $numKeepalive.Size = [System.Drawing.Size]::new(80, 23)
    $grpKeepalive.Controls.Add($numKeepalive)
    
    $lblKeepaliveHint = [System.Windows.Forms.Label]::new()
    $lblKeepaliveHint.Text = Get-String -Key "EditClient_KeepaliveHint"
    $lblKeepaliveHint.Location = [System.Drawing.Point]::new(110, 28)
    $lblKeepaliveHint.AutoSize = $true
    $lblKeepaliveHint.ForeColor = [System.Drawing.Color]::Gray
    $lblKeepaliveHint.Font = [System.Drawing.Font]::new("Segoe UI", 8)
    $grpKeepalive.Controls.Add($lblKeepaliveHint)
    
    # === Buttons ===
    $btnSave = [System.Windows.Forms.Button]::new()
    $btnSave.Text = Get-String -Key "EditClient_Save"
    $btnSave.Location = [System.Drawing.Point]::new(185, 400)
    $btnSave.Size = [System.Drawing.Size]::new(160, 32)
    $btnSave.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $dialog.Controls.Add($btnSave)
    
    $btnCancel = [System.Windows.Forms.Button]::new()
    $btnCancel.Text = Get-String -Key "EditClient_Cancel"
    $btnCancel.Location = [System.Drawing.Point]::new(355, 400)
    $btnCancel.Size = [System.Drawing.Size]::new(85, 32)
    $btnCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCancel.Add_Click({ $dialog.Close() })
    $dialog.Controls.Add($btnCancel)
    
    # === Save handler ===
    $btnSave.Add_Click({
        $btnSave.Enabled = $false
        $btnSave.Text = Get-String -Key "EditClient_Saving"
        [System.Windows.Forms.Application]::DoEvents()

        try {
            $cm    = $script:App.ClientManager
            $cName = $clientName
            $oldDNS = $currentDNS;       $newDNS = $txtDNS.Text.Trim()
            $oldEP  = $currentEndpoint;  $newEP  = $txtEndpoint.Text.Trim()
            $oldIPs = $currentAllowedIPs; $newIPs = $txtAllowedIPs.Text.Trim()
            $oldKA  = $currentKeepalive; $newKA  = ([int]$numKeepalive.Value).ToString()

            $pending = [System.Collections.Generic.List[hashtable]]::new()
            if ($newDNS -ne $oldDNS) { $pending.Add(@{ Param = 'DNS';                 Old = $oldDNS; New = $newDNS }) }
            if ($newEP  -ne $oldEP)  { $pending.Add(@{ Param = 'Endpoint';            Old = $oldEP;  New = $newEP  }) }
            if ($newIPs -ne $oldIPs) { $pending.Add(@{ Param = 'AllowedIPs';          Old = $oldIPs; New = $newIPs }) }
            if ($newKA  -ne $oldKA)  { $pending.Add(@{ Param = 'PersistentKeepalive'; Old = $oldKA;  New = $newKA  }) }

            $items = [System.Collections.Generic.List[hashtable]]::new()
            foreach ($ch in $pending) {
                try {
                    $r = $cm.ModifyClient($cName, $ch.Param, $ch.New)
                    $okProp = $r.PSObject.Properties['ok']
                    if ($okProp -and $okProp.Value) {
                        $items.Add(@{ Param = $ch.Param; Old = $ch.Old; New = $ch.New; Ok = $true; Error = $null })
                    }
                    else {
                        $eProp = $r.PSObject.Properties['error']
                        $items.Add(@{ Param = $ch.Param; Old = $ch.Old; New = $ch.New; Ok = $false;
                                      Error = $(if ($eProp) { $eProp.Value } else { 'unknown error' }) })
                    }
                }
                catch {
                    $items.Add(@{ Param = $ch.Param; Old = $ch.Old; New = $ch.New; Ok = $false; Error = $_.Exception.Message })
                }
            }
            $outcome = $items

            $changes = @(); $errors = @()
            foreach ($it in @($outcome)) {
                if ($it.Ok) { $changes += "$($it.Param): '$($it.Old)' → '$($it.New)'" }
                else        { $errors  += "$($it.Param): $($it.Error)" }
            }

            $report = ""
            if ($changes.Count -gt 0) {
                $report += (Get-String -Key "EditClient_Saved") + "`n"
                foreach ($c in $changes) { $report += "  ✓ $c`n" }
            }
            if ($errors.Count -gt 0) {
                $report += "`n" + (Get-String -Key "EditClient_Errors") + "`n"
                foreach ($e in $errors) { $report += "  ✗ $e`n" }
            }
            if ($changes.Count -eq 0 -and $errors.Count -eq 0) { 
                $report = Get-String -Key "EditClient_NoChanges" 
            }
            $report += "`n" + (Get-String -Key "EditClient_RegenHint")

            $icon = if ($errors.Count -gt 0) { [System.Windows.Forms.MessageBoxIcon]::Warning }
                    else                    { [System.Windows.Forms.MessageBoxIcon]::Information }
            [System.Windows.Forms.MessageBox]::Show(
                $report,
                (Get-String -Key "EditClient_Result"),
                "OK",
                $icon)

            if ($changes.Count -gt 0) {
                $dialog.Close()
                Refresh-ClientsList
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "EditClient_ErrorSaving") + "`n$($_.Exception.Message)",
                (Get-String -Key "Msg_Error"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        finally {
            $btnSave.Enabled = $true
            $btnSave.Text = Get-String -Key "EditClient_Save"
        }
    })
    
    $dialog.ShowDialog($script:MainForm) | Out-Null
    $dialog.Dispose()
}