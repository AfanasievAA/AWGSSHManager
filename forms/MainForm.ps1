#requires -Version 7.5
# =============================================================================
#  MainForm.ps1 — Main application window
#  Version: 0.2
#  Description: Main application window with server profile management,
#               client list view, and all action buttons.
# =============================================================================

function New-MainForm {
    param([Parameter(Mandatory)][hashtable]$AppContext)

    # Initialize all script-scope variables
    $script:App               = $AppContext
    $script:MainForm          = $null
    $script:cboProfile        = $null
    $script:dgvClients        = $null
    $script:lblConnStatus     = $null
    $script:statusLabel       = $null
    $script:statusProgressBar = $null
    $script:IsBusy            = $false
    $script:cboLanguage       = $null
    $script:btnConnect        = $null

    # =========================================================================
    # Form
    # =========================================================================
    $form = [System.Windows.Forms.Form]::new()
    $form.Text = Get-String -Key "App_Title"
    $form.Size = [System.Drawing.Size]::new(1180, 680)
    $form.MinimumSize = [System.Drawing.Size]::new(1000, 600)
    $form.StartPosition = "CenterScreen"
    $form.Font = [System.Drawing.Font]::new("Segoe UI", 9)

    $script:MainForm = $form

    # =========================================================================
    # ToolStrip (top panel)
    # =========================================================================
    $toolStrip = [System.Windows.Forms.ToolStrip]::new()
    $toolStrip.GripStyle = [System.Windows.Forms.ToolStripGripStyle]::Hidden
    $toolStrip.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::System

    # --- Server label ---
    $lblProfile = [System.Windows.Forms.ToolStripLabel]::new()
    $lblProfile.Text = Get-String -Key "Server_Label"
    $lblProfile.Tag = "Server_Label"
    [void]$toolStrip.Items.Add($lblProfile)

    # --- Profile combobox ---
    $script:cboProfile = [System.Windows.Forms.ToolStripComboBox]::new()
    $script:cboProfile.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $script:cboProfile.Width = 250
    [void]$toolStrip.Items.Add($script:cboProfile)

    # --- Connect button ---
    $script:btnConnect = [System.Windows.Forms.ToolStripButton]::new()
    $script:btnConnect.Text = Get-String -Key "Server_Connect"
    $script:btnConnect.Tag = "Server_Connect"
    $script:btnConnect.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
    [void]$toolStrip.Items.Add($script:btnConnect)

    [void]$toolStrip.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())

    # --- New Profile button ---
    $btnAddProfile = [System.Windows.Forms.ToolStripButton]::new()
    $btnAddProfile.Text = Get-String -Key "Server_NewProfile"
    $btnAddProfile.Tag = "Server_NewProfile"
    $btnAddProfile.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
    [void]$toolStrip.Items.Add($btnAddProfile)

    # --- Edit Profile button ---
    $btnEditProfile = [System.Windows.Forms.ToolStripButton]::new()
    $btnEditProfile.Text = Get-String -Key "Server_EditProfile"
    $btnEditProfile.Tag = "Server_EditProfile"
    $btnEditProfile.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
    [void]$toolStrip.Items.Add($btnEditProfile)

    # --- Delete Profile button ---
    $btnDeleteProfile = [System.Windows.Forms.ToolStripButton]::new()
    $btnDeleteProfile.Text = Get-String -Key "Server_DeleteProfile"
    $btnDeleteProfile.Tag = "Server_DeleteProfile"
    $btnDeleteProfile.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
    [void]$toolStrip.Items.Add($btnDeleteProfile)

    [void]$toolStrip.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())

    # --- Language selection (right-aligned) ---
    # Language combobox first (right-aligned)
    $script:cboLanguage = [System.Windows.Forms.ToolStripComboBox]::new()
    $script:cboLanguage.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $script:cboLanguage.Width = 120
    $script:cboLanguage.Alignment = [System.Windows.Forms.ToolStripItemAlignment]::Right
    
    $langs = Get-LanguageList
    foreach ($code in $langs.Keys) {
        [void]$script:cboLanguage.Items.Add($langs[$code])
    }
    
    $current = Get-CurrentLanguage
    if ($langs.ContainsKey($current)) {
        $script:cboLanguage.SelectedItem = $langs[$current]
    }
    else {
        $script:cboLanguage.SelectedIndex = 0
    }
    [void]$toolStrip.Items.Add($script:cboLanguage)

    # Language label (right-aligned, placed after combobox so it appears to the left)
    $lblLang = [System.Windows.Forms.ToolStripLabel]::new()
    $lblLang.Text = (Get-String -Key "Language") + ":"
    $lblLang.Tag = "Language"
    $lblLang.Alignment = [System.Windows.Forms.ToolStripItemAlignment]::Right
    [void]$toolStrip.Items.Add($lblLang)

    # --- Connection status ---
    $script:lblConnStatus = [System.Windows.Forms.ToolStripLabel]::new()
    $script:lblConnStatus.Text = Get-String -Key "Server_Disconnected"
    $script:lblConnStatus.Tag = "Server_Disconnected"
    $script:lblConnStatus.ForeColor = [System.Drawing.Color]::Gray
    $script:lblConnStatus.Alignment = [System.Windows.Forms.ToolStripItemAlignment]::Right
    [void]$toolStrip.Items.Add($script:lblConnStatus)

    # =========================================================================
    # StatusStrip (bottom panel)
    # =========================================================================
    $statusStrip = [System.Windows.Forms.StatusStrip]::new()

    $script:statusLabel = [System.Windows.Forms.ToolStripStatusLabel]::new()
    $script:statusLabel.Text = Get-String -Key "App_Ready"
    $script:statusLabel.Tag = "App_Ready"
    $script:statusLabel.Spring = $true
    $script:statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    [void]$statusStrip.Items.Add($script:statusLabel)

    $script:statusProgressBar = [System.Windows.Forms.ToolStripProgressBar]::new()
    $script:statusProgressBar.Visible = $false
    $script:statusProgressBar.Width = 150
    [void]$statusStrip.Items.Add($script:statusProgressBar)

    # =========================================================================
    # Left panel: DataGridView with clients
    # =========================================================================
    $leftPanel = [System.Windows.Forms.Panel]::new()
    $leftPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $leftPanel.Padding = [System.Windows.Forms.Padding]::new(5)

    $script:dgvClients = [System.Windows.Forms.DataGridView]::new()
    $script:dgvClients.Dock = [System.Windows.Forms.DockStyle]::Fill
    $script:dgvClients.AllowUserToAddRows = $false
    $script:dgvClients.AllowUserToDeleteRows = $false
    $script:dgvClients.ReadOnly = $true
    $script:dgvClients.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $script:dgvClients.MultiSelect = $false
    $script:dgvClients.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $script:dgvClients.BackgroundColor = [System.Drawing.Color]::White
    $script:dgvClients.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $script:dgvClients.RowHeadersVisible = $false
    $script:dgvClients.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
    $script:dgvClients.EnableHeadersVisualStyles = $false
    $script:dgvClients.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $script:dgvClients.ColumnHeadersDefaultCellStyle.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

    # --- Columns ---
    $columnDefs = @(
        @{ Name = 'Name';    HeaderTextKey = 'Column_Name';    MinimumWidth = 120; AutoSizeMode = 'Fill'     }
        @{ Name = 'IP';      HeaderTextKey = 'Column_IP';      MinimumWidth = 90;  AutoSizeMode = 'AllCells' }
        @{ Name = 'IPv6';    HeaderTextKey = 'Column_IPv6';    MinimumWidth = 110; AutoSizeMode = 'AllCells' }
        @{ Name = 'Status';  HeaderTextKey = 'Column_Status';  MinimumWidth = 95;  AutoSizeMode = 'AllCells' }
        @{ Name = 'Expires'; HeaderTextKey = 'Column_Expires'; MinimumWidth = 110; AutoSizeMode = 'AllCells' }
        @{ Name = 'Rx';      HeaderTextKey = 'Column_Rx';      MinimumWidth = 85;  AutoSizeMode = 'AllCells' }
        @{ Name = 'Tx';      HeaderTextKey = 'Column_Tx';      MinimumWidth = 85;  AutoSizeMode = 'AllCells' }
    )

    foreach ($def in $columnDefs) {
        $column = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
        $column.Name = $def.Name
        $column.HeaderText = Get-String -Key $def.HeaderTextKey
        $column.Tag = $def.HeaderTextKey  # Store localization key
        $column.AutoSizeMode = $def.AutoSizeMode
        $column.MinimumWidth = $def.MinimumWidth
        $column.ReadOnly = $true
        [void]$script:dgvClients.Columns.Add($column)
    }

    # --- Status and expiration coloring ---
    $script:dgvClients.Add_CellFormatting({
        param($sender, $e)
        try {
            if ($e.RowIndex -lt 0 -or $e.RowIndex -ge $sender.Rows.Count) { return }
            $row = $sender.Rows[$e.RowIndex]
            if ($null -eq $row.Tag -or -not ($row.Tag -is [hashtable])) { return }
            $tag = $row.Tag

            $statusCol = $sender.Columns['Status']
            if ($null -ne $statusCol -and $e.ColumnIndex -eq $statusCol.Index) {
                $display = Get-AWGStatusDisplay -StatusCode ([string]$tag['StatusCode'])
                $colors  = Get-AWGStatusColor -Level $display.Level
                $e.CellStyle.ForeColor = $colors['ForeColor']
                $e.CellStyle.BackColor = $colors['BackColor']
                return
            }

            $expiresCol = $sender.Columns['Expires']
            if ($null -ne $expiresCol -and $e.ColumnIndex -eq $expiresCol.Index -and $tag['IsExpired']) {
                $e.CellStyle.ForeColor = [System.Drawing.Color]::Red
            }
        }
        catch {
            # Ignore formatting errors
        }
    })

    [void]$leftPanel.Controls.Add($script:dgvClients)

    # --- Context menu ---
    $contextMenu = [System.Windows.Forms.ContextMenuStrip]::new()

    $menuRefresh = [System.Windows.Forms.ToolStripMenuItem]::new((Get-String -Key "Actions_Refresh"))
    $menuRefresh.Tag = "Actions_Refresh"
    $menuRefresh.Add_Click({ Refresh-ClientsList })
    [void]$contextMenu.Items.Add($menuRefresh)

    [void]$contextMenu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())

    $menuAdd = [System.Windows.Forms.ToolStripMenuItem]::new((Get-String -Key "Actions_AddClient"))
    $menuAdd.Tag = "Actions_AddClient"
    $menuAdd.Add_Click({ Show-AddClientForm })
    [void]$contextMenu.Items.Add($menuAdd)

    $menuEdit = [System.Windows.Forms.ToolStripMenuItem]::new((Get-String -Key "Actions_EditClient"))
    $menuEdit.Tag = "Actions_EditClient"
    $menuEdit.Add_Click({ Show-EditClientForm })
    [void]$contextMenu.Items.Add($menuEdit)

    $menuRemove = [System.Windows.Forms.ToolStripMenuItem]::new((Get-String -Key "Actions_DeleteClient"))
    $menuRemove.Tag = "Actions_DeleteClient"
    $menuRemove.Add_Click({ Remove-SelectedClient })
    [void]$contextMenu.Items.Add($menuRemove)

    [void]$contextMenu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())

    $menuView = [System.Windows.Forms.ToolStripMenuItem]::new((Get-String -Key "Actions_ViewConfig"))
    $menuView.Tag = "Actions_ViewConfig"
    $menuView.Add_Click({ Show-ViewConfigForm })
    [void]$contextMenu.Items.Add($menuView)

    $menuExport = [System.Windows.Forms.ToolStripMenuItem]::new((Get-String -Key "Actions_DownloadConfig"))
    $menuExport.Tag = "Actions_DownloadConfig"
    $menuExport.Add_Click({ Export-SelectedClientConfig })
    [void]$contextMenu.Items.Add($menuExport)

    $menuRegen = [System.Windows.Forms.ToolStripMenuItem]::new((Get-String -Key "Actions_Regenerate"))
    $menuRegen.Tag = "Actions_Regenerate"
    $menuRegen.Add_Click({ Regen-SelectedClient })
    [void]$contextMenu.Items.Add($menuRegen)

    $script:dgvClients.ContextMenuStrip = $contextMenu

    # Double-click to view config
    $script:dgvClients.Add_CellDoubleClick({
        param($sender, $e)
        if ($e.RowIndex -ge 0) { Show-ViewConfigForm }
    })

    # =========================================================================
    # Right panel: action buttons
    # =========================================================================
    $rightPanel = [System.Windows.Forms.Panel]::new()
    $rightPanel.Dock = [System.Windows.Forms.DockStyle]::Right
    $rightPanel.Width = 200
    $rightPanel.Padding = [System.Windows.Forms.Padding]::new(10, 10, 10, 10)

    # --- Actions title ---
    $lblActions = [System.Windows.Forms.Label]::new()
    $lblActions.Text = Get-String -Key "Actions_Title"
    $lblActions.Tag = "Actions_Title"
    $lblActions.Font = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblActions.Location = [System.Drawing.Point]::new(10, 10)
    $lblActions.AutoSize = $true
    [void]$rightPanel.Controls.Add($lblActions)

    # --- Action buttons definition ---
    $actionDefs = @(
        @{ TextKey = "Actions_Refresh";       Handler = { Refresh-ClientsList } }
        @{ TextKey = "Actions_AddClient";     Handler = { Show-AddClientForm } }
        @{ TextKey = "Actions_EditClient";    Handler = { Show-EditClientForm } }
        @{ TextKey = "Actions_DeleteClient";  Handler = { Remove-SelectedClient } }
        @{ IsSeparator = $true }
        @{ TextKey = "Actions_ViewConfig";    Handler = { Show-ViewConfigForm } }
        @{ TextKey = "Actions_DownloadConfig"; Handler = { Export-SelectedClientConfig } }
        @{ TextKey = "Actions_Regenerate";    Handler = { Regen-SelectedClient } }
        @{ IsSeparator = $true }
        @{ TextKey = "Actions_Stats";         Handler = { Show-StatsDialog } }
        @{ TextKey = "Actions_Backup";        Handler = { Export-ServerConfig } }
        @{ TextKey = "Actions_RestoreBackup"; Handler = { Import-ServerConfig } }
        @{ TextKey = "Actions_Restart";       Handler = { Restart-AWGService } }
    )

    $yPos = 45
    foreach ($def in $actionDefs) {
        if ($def.ContainsKey('IsSeparator') -and $def.IsSeparator) {
            $sep = [System.Windows.Forms.Label]::new()
            $sep.Text = "───────────────────"
            $sep.Location = [System.Drawing.Point]::new(10, $yPos)
            $sep.AutoSize = $true
            $sep.ForeColor = [System.Drawing.Color]::LightGray
            [void]$rightPanel.Controls.Add($sep)
            $yPos += 24
            continue
        }

        $btn = [System.Windows.Forms.Button]::new()
        $btn.Text = Get-String -Key $def.TextKey
        $btn.Tag = $def.TextKey  # Store localization key
        $btn.Location = [System.Drawing.Point]::new(10, $yPos)
        $btn.Size = [System.Drawing.Size]::new(180, 32)
        $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btn.FlatAppearance.BorderSize = 1
        $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
        $btn.Add_Click($def.Handler)
        [void]$rightPanel.Controls.Add($btn)
        $yPos += 42
    }

    # =========================================================================
    # Add controls to form
    # =========================================================================
    [void]$form.Controls.Add($toolStrip)
    [void]$form.Controls.Add($statusStrip)
    [void]$form.Controls.Add($rightPanel)
    [void]$form.Controls.Add($leftPanel)

    # =========================================================================
    # Event handlers
    # =========================================================================

    # --- Language change ---
    $script:cboLanguage.Add_SelectedIndexChanged({
        $langs = Get-LanguageList
        $selectedText = [string]$script:cboLanguage.SelectedItem
        $newLang = $null
        foreach ($code in $langs.Keys) {
            if ($langs[$code] -eq $selectedText) {
                $newLang = $code
                break
            }
        }
        if ($newLang -and $newLang -ne (Get-CurrentLanguage)) {
            Set-Language -LanguageCode $newLang
            Update-AllUI-Texts
        }
    })

    # --- Connect / Disconnect ---
    $script:btnConnect.Add_Click({
        # If connected -> Disconnect
        if ($null -ne $script:App.SSHManager -and $script:App.SSHManager.IsConnected()) {
            Disconnect-FromServer
            return
        }

        # If not connected -> Connect
        if ($null -eq $script:cboProfile -or $script:cboProfile.SelectedIndex -lt 0) {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Msg_SelectProfile"),
                (Get-String -Key "Msg_Warning"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $profileName  = [string]$script:cboProfile.SelectedItem
        $serverProfile = @($script:App.Profiles) |
            Where-Object { $_.Name -eq $profileName } |
            Select-Object -First 1

        if ($null -eq $serverProfile) {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Msg_ProfileNotFound" -Params $profileName),
                (Get-String -Key "Msg_Error"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        Connect-ToServer -ServerProfile $serverProfile
    })

    # --- New profile ---
    $btnAddProfile.Add_Click({
        Show-ProfileForm -ParentForm $script:MainForm -ProfileManager $script:App.ProfileManager -Mode "Add"
        $script:App.Profiles = $script:App.ProfileManager.LoadAllProfiles()
        Initialize-ProfileComboBox
    })

    # --- Edit profile ---
    $btnEditProfile.Add_Click({
        if ($null -eq $script:cboProfile -or $script:cboProfile.SelectedIndex -lt 0) {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Msg_SelectProfileEdit"),
                (Get-String -Key "Msg_Warning"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $profileName = [string]$script:cboProfile.SelectedItem
        $existing = @($script:App.Profiles) |
            Where-Object { $_.Name -eq $profileName } |
            Select-Object -First 1

        if ($null -eq $existing) {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Msg_ProfileNotFound" -Params $profileName),
                (Get-String -Key "Msg_Error"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        Show-ProfileForm -ParentForm $script:MainForm -ProfileManager $script:App.ProfileManager -Mode "Edit" -ExistingProfile $existing
        $script:App.Profiles = $script:App.ProfileManager.LoadAllProfiles()
        Initialize-ProfileComboBox
    })

    # --- Delete profile ---
    $btnDeleteProfile.Add_Click({
        if ($null -eq $script:cboProfile -or $script:cboProfile.SelectedIndex -lt 0) {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Msg_SelectProfileEdit"),
                (Get-String -Key "Msg_Warning"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $profileName = [string]$script:cboProfile.SelectedItem

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Profile_DeleteConfirm" -Params $profileName),
            (Get-String -Key "Msg_Confirm"),
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        # Disconnect if currently connected to this profile
        if ($null -ne $script:App.SSHManager -and $script:App.SSHManager.IsConnected()) {
            Disconnect-FromServer
        }

        try {
            $script:App.ProfileManager.DeleteProfile($profileName)
            $script:App.Profiles = $script:App.ProfileManager.LoadAllProfiles()
            Initialize-ProfileComboBox
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Error_ProfileDelete" -Params $_.Exception.Message),
                (Get-String -Key "Msg_Error"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })

    # --- Prevent form closing during busy state ---
    $form.Add_FormClosing({
        param($sender, $e)
        if ($script:IsBusy) {
            $e.Cancel = $true
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Msg_Busy"),
                (Get-String -Key "Msg_OperationInProgress"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })

    # =========================================================================
    # Initialization and return
    # =========================================================================
    $null = Initialize-ProfileComboBox

    return @{
        Form         = $form
        DataGridView = $script:dgvClients
        ComboBox     = $script:cboProfile
        StatusLabel  = $script:statusLabel
        ProgressBar  = $script:statusProgressBar
    }
}

# =============================================================================
#  Update-AllUI-Texts — updates all UI texts after language change
#  Uses Tag properties to store localization keys
# =============================================================================
function Update-AllUI-Texts {
    if ($null -eq $script:MainForm) { return }
    
    # Update main form title
    $script:MainForm.Text = Get-String -Key "App_Title"
    
    # Update all controls recursively
    Update-ControlsText -Control $script:MainForm
}

# =============================================================================
#  Update-ControlsText — recursive function to update all controls with Tag
# =============================================================================
function Update-ControlsText {
    param(
        [System.Windows.Forms.Control]$Control
    )
    
    if ($null -eq $Control) { return }
    
    # Process current control
    if ($Control.Tag -and $Control.Tag -is [string]) {
        $key = [string]$Control.Tag
        if ($script:Strings.ContainsKey($key)) {
            $Control.Text = Get-String -Key $key
        }
    }
    
    # Process child controls
    foreach ($child in $Control.Controls) {
        Update-ControlsText -Control $child
    }

    # Update DataGridView column headers
    if ($Control -is [System.Windows.Forms.DataGridView]) {
        foreach ($col in $Control.Columns) {
            if ($col.Tag -and $col.Tag -is [string]) {
                $key = [string]$col.Tag
                if ($script:Strings.ContainsKey($key)) {
                    $col.HeaderText = Get-String -Key $key
                }
            }
        }
    }

    # Update ContextMenuStrip items
    if ($Control -is [System.Windows.Forms.Control] -and $null -ne $Control.ContextMenuStrip) {
        foreach ($subItem in $Control.ContextMenuStrip.Items) {
            if ($subItem.Tag -and $subItem.Tag -is [string]) {
                $key = [string]$subItem.Tag
                if ($script:Strings.ContainsKey($key)) {
                    $subItem.Text = Get-String -Key $key
                }
            }
        }
    }

    # Process ToolStrip and StatusStrip (they are not in Controls collection)
    if ($Control -is [System.Windows.Forms.Form]) {
        foreach ($item in $Control.Controls) {
            if ($item -is [System.Windows.Forms.ToolStrip]) {
                foreach ($subItem in $item.Items) {
                    if ($subItem.Tag -and $subItem.Tag -is [string]) {
                        $key = [string]$subItem.Tag
                        if ($script:Strings.ContainsKey($key)) {
                            $subItem.Text = Get-String -Key $key
                        }
                    }
                }
            }
            if ($item -is [System.Windows.Forms.StatusStrip]) {
                foreach ($subItem in $item.Items) {
                    if ($subItem.Tag -and $subItem.Tag -is [string]) {
                        $key = [string]$subItem.Tag
                        if ($script:Strings.ContainsKey($key)) {
                            $subItem.Text = Get-String -Key $key
                        }
                    }
                }
            }
            if ($item -is [System.Windows.Forms.ContextMenuStrip]) {
                foreach ($subItem in $item.Items) {
                    if ($subItem.Tag -and $subItem.Tag -is [string]) {
                        $key = [string]$subItem.Tag
                        if ($script:Strings.ContainsKey($key)) {
                            $subItem.Text = Get-String -Key $key
                        }
                    }
                }
            }
        }
    }
}

# =============================================================================
#  HELPER FUNCTIONS
# =============================================================================

function Initialize-ProfileComboBox {
    if ($null -eq $script:cboProfile) { return }

    $script:cboProfile.Items.Clear()
    foreach ($p in @($script:App.Profiles)) {
        [void]$script:cboProfile.Items.Add($p.Name)
    }
    if ($script:cboProfile.Items.Count -gt 0) {
        $script:cboProfile.SelectedIndex = 0
    }
}

function Update-ConnectionStatus {
    param([string]$Status, [System.Drawing.Color]$Color)

    if ($null -ne $script:lblConnStatus) {
        $script:lblConnStatus.Text = "  ● $Status"
        $script:lblConnStatus.ForeColor = $Color
        $script:lblConnStatus.Invalidate()
    }
}

function Set-BusyState {
    param([bool]$Busy, [string]$Message = "")

    if ($null -ne $script:statusProgressBar) {
        $script:statusProgressBar.Visible = $Busy
        if ($Busy) {
            $script:statusProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
        }
    }
    if ($null -ne $script:statusLabel) {
        $script:statusLabel.Text = if ($Message) { $Message } else { (Get-String -Key "App_Ready") }
    }
    if ($Busy) {
        [void][System.Windows.Forms.Application]::DoEvents()
    }
}
function Set-ControlsEnabled {
    param($Controls, [bool]$Enabled)
    foreach ($ctrl in $Controls) {
        if ($ctrl -is [System.Windows.Forms.ToolStrip]) {
            foreach ($item in $ctrl.Items) { $item.Enabled = $Enabled }
        }
        else {
            $ctrl.Enabled = $Enabled
        }
        if ($ctrl.Controls -and $ctrl.Controls.Count -gt 0) {
            Set-ControlsEnabled -Controls $ctrl.Controls -Enabled $Enabled
        }
    }
}

function Connect-ToServer {
    param($ServerProfile)

    Update-ConnectionStatus -Status (Get-String -Key "App_Connecting") -Color ([System.Drawing.Color]::Orange)
    Set-BusyState -Busy $true -Message ((Get-String -Key "App_Connecting") + " $($ServerProfile.Host)...")

    try {
        $script:App.SSHManager    = [SSHManager]::new($ServerProfile)
        $script:App.ClientManager = [ClientManager]::new($script:App.SSHManager)

        $ssh = $script:App.SSHManager
        $testResult = $ssh.InvokeCommand("list --json")

        if (-not $testResult.Success) {
            $script:App.SSHManager    = $null
            $script:App.ClientManager = $null
            
            # Check if manage_amneziawg.sh is missing
            if ($testResult.ExitCode -eq 127 -or $testResult.Error -match 'manage_amneziawg.sh: No such file or directory') {
                throw (Get-String -Key "Error_AWGNotFound")
            } else {
                throw (Get-String -Key "Error_ConnectFailed" -Params $testResult.ExitCode, $testResult.Error)
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($testResult.Output)) {
            $null = $testResult.Output | ConvertFrom-Json -ErrorAction Stop
        }

        Update-ConnectionStatus -Status (Get-String -Key "App_ConnectedTo" -Params $ServerProfile.Name) -Color ([System.Drawing.Color]::Green)
        Set-BusyState -Busy $false -Message ((Get-String -Key "App_ConnectedTo" -Params $ServerProfile.Name))

        # Change button to Disconnect
        $script:btnConnect.Text = Get-String -Key "Server_Disconnect"
        $script:btnConnect.Tag = "Server_Disconnect"

        Refresh-ClientsList
    }
    catch {
        Update-ConnectionStatus -Status (Get-String -Key "App_Error") -Color ([System.Drawing.Color]::Red)
        Set-BusyState -Busy $false -Message (Get-String -Key "App_Error")

        # Generate detailed error log
        $logDir = Join-Path $env:APPDATA "AmneziaWGAdmin"
        if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $logPath = Join-Path $logDir "AWGAdmin_error.log"
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logContent = "[$timestamp] Error in Connect-ToServer`n"
        $logContent += "PowerShell Version: $($PSVersionTable.PSVersion)`n"
        $logContent += "OS: $([System.Environment]::OSVersion.VersionString)`n`n"
        
        $ex = $_.Exception
        $level = 0
        while ($null -ne $ex) {
            $logContent += "[Exception Level $level]`n"
            $logContent += "Type:    $($ex.GetType().FullName)`n"
            $logContent += "Message:  $($ex.Message)`n"
            if ($ex.StackTrace) {
                $logContent += "StackTrace:`n$($ex.StackTrace)`n`n"
            }
            $ex = $ex.InnerException
            $level++
        }
        
        try {
            Add-Content -LiteralPath $logPath -Value $logContent -Encoding UTF8
        } catch { }

        # Show custom dialog instead of standard MessageBox
        Show-CustomErrorDialog -Title (Get-String -Key "Msg_Error") -Message $_.Exception.Message
    }
}

function Disconnect-FromServer {
    if ($null -ne $script:App.SSHManager) {
        try { $script:App.SSHManager.Disconnect() } catch { }
    }
    
    $script:App.SSHManager = $null
    $script:App.ClientManager = $null
    
    # Change button back to Connect
    if ($null -ne $script:btnConnect) {
        $script:btnConnect.Text = Get-String -Key "Server_Connect"
        $script:btnConnect.Tag = "Server_Connect"
    }
    
    Update-ConnectionStatus -Status (Get-String -Key "Server_Disconnected") -Color ([System.Drawing.Color]::Gray)
    Set-BusyState -Busy $false -Message (Get-String -Key "App_Ready")
    
    if ($null -ne $script:dgvClients) {
        $script:dgvClients.Rows.Clear()
    }
}

function Show-CustomErrorDialog {
    param([string]$Title, [string]$Message)
    
    $dialog = [System.Windows.Forms.Form]::new()
    $dialog.Text = $Title
    $dialog.Size = [System.Drawing.Size]::new(500, 350)
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.Font = [System.Drawing.Font]::new("Segoe UI", 9)

    $txtError = [System.Windows.Forms.TextBox]::new()
    $txtError.Multiline = $true
    $txtError.ReadOnly = $true
    $txtError.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $txtError.Text = $Message
    $txtError.Location = [System.Drawing.Point]::new(10, 10)
    $txtError.Size = [System.Drawing.Size]::new(465, 250)
    $txtError.Font = [System.Drawing.Font]::new("Consolas", 9)
    $dialog.Controls.Add($txtError)

    $btnCopy = [System.Windows.Forms.Button]::new()
    $btnCopy.Text = Get-String -Key "ViewConfig_Copy"
    $btnCopy.Location = [System.Drawing.Point]::new(10, 270)
    $btnCopy.Size = [System.Drawing.Size]::new(100, 32)
    $btnCopy.Add_Click({
        [System.Windows.Forms.Clipboard]::SetText($txtError.Text)
        $btnCopy.Text = Get-String -Key "ViewConfig_CopyDone"
        $timer = [System.Windows.Forms.Timer]::new()
        $timer.Interval = 1500
        $timer.Add_Tick({
            $btnCopy.Text = Get-String -Key "ViewConfig_Copy"
            $this.Stop()
            $this.Dispose()
        })
        $timer.Start()
    })
    $dialog.Controls.Add($btnCopy)

    $btnClose = [System.Windows.Forms.Button]::new()
    $btnClose.Text = Get-String -Key "ViewConfig_Close"
    $btnClose.Location = [System.Drawing.Point]::new(390, 270)
    $btnClose.Size = [System.Drawing.Size]::new(85, 32)
    $btnClose.Add_Click({ $dialog.Close() })
    $dialog.Controls.Add($btnClose)

    $dialog.ShowDialog($script:MainForm) | Out-Null
    $dialog.Dispose()
}

function Refresh-ClientsList {
    if ($null -eq $script:App.ClientManager) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_ConnectFirst"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    if ($null -eq $script:dgvClients) { return }

    Set-BusyState -Busy $true -Message ((Get-String -Key "App_Connecting") + " clients...")

    try {
        $cm = $script:App.ClientManager
        $clients = $cm.GetClients()

        $stats = $null
        try {
            $stats = $cm.GetClientStats()
        }
        catch { }

        $statsByName = @{}
        if ($stats) {
            foreach ($s in @($stats)) {
                $sName = [string](Get-AWGConfigProperty -Object $s -Name 'name')
                $statsByName[$sName] = $s
            }
        }

        $script:dgvClients.Rows.Clear()

        foreach ($client in @($clients)) {
            $name       = [string](Get-AWGConfigProperty -Object $client -Name 'name')
            $ip         = Get-AWGConfigProperty -Object $client -Name 'ip'
            $ipv6       = Get-AWGConfigProperty -Object $client -Name 'client_ipv6'
            $statusCode = Get-AWGConfigProperty -Object $client -Name 'status_code'
            $expiresAt  = Get-AWGConfigProperty -Object $client -Name 'expires_at'

            $st = $statsByName[$name]
            $rxText = "—"; $txText = "—"
            if ($null -ne $st) {
                $rx = Get-AWGConfigProperty -Object $st -Name 'rx'
                $tx = Get-AWGConfigProperty -Object $st -Name 'tx'
                if ($rx) { $rxText = Format-Bytes -Bytes ([long]$rx) }
                if ($tx) { $txText = Format-Bytes -Bytes ([long]$tx) }
            }

            $expiryInfo    = Get-AWGExpiryStatus -ExpiresAt $expiresAt
            # Override server status if expired locally
            if ($expiryInfo.IsExpired) {
                $statusCode = 'expired'
            }
            $statusDisplay = Get-AWGStatusDisplay -StatusCode ([string]$statusCode)
            $expiresText   = [string]$expiryInfo['Text']

            $ipText   = if ($ip)   { [string]$ip }   else { "—" }
            $ipv6Text = if ($ipv6 -and [string]$ipv6 -ne 'null') { [string]$ipv6 } else { "—" }

            $idx = $script:dgvClients.Rows.Add(
                $name,
                $ipText,
                $ipv6Text,
                $statusDisplay.Text,
                $expiresText,
                $rxText,
                $txText
            )

            $script:dgvClients.Rows[$idx].Tag = @{
                StatusCode = [string]$statusCode
                IsExpired  = [bool]$expiryInfo['IsExpired']
            }
        }

        Set-BusyState -Busy $false -Message "Loaded clients: $(@($clients).Count)"
    }
    catch {
        Set-BusyState -Busy $false -Message "Load error"
        [System.Windows.Forms.MessageBox]::Show(
            "Error getting client list:`n$($_.Exception.Message)",
            (Get-String -Key "Msg_Error"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Remove-SelectedClient {
    if ($null -eq $script:dgvClients -or $script:dgvClients.SelectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_SelectClient"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $clientName = [string]$script:dgvClients.SelectedRows[0].Cells['Name'].Value

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        (Get-String -Key "Delete_Confirm" -Params $clientName),
        (Get-String -Key "Msg_Confirm"),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)

    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    Set-BusyState -Busy $true -Message ((Get-String -Key "Delete_Deleting" -Params $clientName))

    try {
        $cm = $script:App.ClientManager
        $result = $cm.RemoveClient($clientName)

        $ok = Get-AWGConfigProperty -Object $result -Name 'ok'
        if ($ok) {
            Set-BusyState -Busy $false -Message ((Get-String -Key "Delete_Deleted" -Params $clientName))
            Refresh-ClientsList
        }
        else {
            $errText = Get-AWGConfigProperty -Object $result -Name 'error'
            throw (Get-String -Key "Error_ServerReturned" -Params $errText)
        }
    }
    catch {
        Set-BusyState -Busy $false -Message "Delete error"
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Error_ClientDelete" -Params $_.Exception.Message),
            (Get-String -Key "Msg_Error"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Export-SelectedClientConfig {
    if ($null -eq $script:dgvClients -or $script:dgvClients.SelectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_SelectClient"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    if ($null -eq $script:App.SSHManager) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_ConnectFirst"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $clientName = [string]$script:dgvClients.SelectedRows[0].Cells['Name'].Value

    $saveDialog = [System.Windows.Forms.SaveFileDialog]::new()
    $saveDialog.Filter = "AmneziaWG Configuration (*.conf)|*.conf|All files (*.*)|*.*"
    $saveDialog.FileName = "$clientName.conf"
    $saveDialog.Title = Get-String -Key "Export_SaveConfig"

    if ($saveDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    Set-BusyState -Busy $true -Message (Get-String -Key "Export_Downloading")

    try {
        $sshMgr = $script:App.SSHManager
        $localFile = $saveDialog.FileName
        $success = $sshMgr.DownloadConfig($clientName, $localFile)

        if ($success) {
            Set-BusyState -Busy $false -Message ((Get-String -Key "Export_Downloaded" -Params $saveDialog.FileName))
            [System.Windows.Forms.MessageBox]::Show(
                "Configuration saved:`n$($saveDialog.FileName)",
                (Get-String -Key "Msg_Info"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        else {
            throw (Get-String -Key "Error_ConfigExport")
        }
    }
    catch {
        Set-BusyState -Busy $false -Message "Download error"
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Error_ConfigDownload" -Params $_.Exception.Message),
            (Get-String -Key "Msg_Error"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Regen-SelectedClient {
    if ($null -eq $script:dgvClients -or $script:dgvClients.SelectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_SelectClient"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $clientName = [string]$script:dgvClients.SelectedRows[0].Cells['Name'].Value

    $answer = [System.Windows.Forms.MessageBox]::Show(
        (Get-String -Key "Regen_Confirm" -Params $clientName),
        (Get-String -Key "Regen_Confirm"),
        [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
        [System.Windows.Forms.MessageBoxIcon]::Question)

    if ($answer -eq [System.Windows.Forms.DialogResult]::Cancel) { return }
    $useResetRoutes = ($answer -eq [System.Windows.Forms.DialogResult]::Yes)

    Set-BusyState -Busy $true -Message ((Get-String -Key "Regen_Regenerating" -Params $clientName))

    try {
        $cm = $script:App.ClientManager
        $result = $cm.RegenClient($clientName, $useResetRoutes)

        $ok = Get-AWGConfigProperty -Object $result -Name 'ok'
        if ($ok) {
            Set-BusyState -Busy $false -Message "Configuration regenerated"
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Regen_Regenerated" -Params $clientName),
                (Get-String -Key "Msg_Info"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        else {
            $errText = Get-AWGConfigProperty -Object $result -Name 'error'
            throw (Get-String -Key "Error_ServerReturned" -Params $errText)
        }
    }
    catch {
        Set-BusyState -Busy $false -Message "Regeneration error"
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Error_ClientRegen" -Params $_.Exception.Message),
            (Get-String -Key "Msg_Error"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Show-StatsDialog {
    if ($null -eq $script:App.ClientManager) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_ConnectFirst"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    Show-StatsForm -ClientManager $script:App.ClientManager -ParentForm $script:MainForm
}

function Export-ServerConfig {
    if ($null -eq $script:App.ClientManager) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_ConnectFirst"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        (Get-String -Key "Backup_Confirm"),
        (Get-String -Key "Backup_Confirm"),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)

    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $saveDialog = [System.Windows.Forms.SaveFileDialog]::new()
    $saveDialog.Filter = "AmneziaWG Archive (*.tar.gz)|*.tar.gz|All files (*.*)|*.*"
    $saveDialog.FileName = "awg_backup_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').tar.gz"
    $saveDialog.Title = "Save backup location"

    if ($saveDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    try {
        $cm = $script:App.ClientManager
        $backupResult = $cm.CreateBackup()

        if (-not $backupResult.Success) {
            throw $backupResult.Error
        }

        if ($backupResult.Json) {
            $okProp = $backupResult.Json.PSObject.Properties['ok']
            if ($okProp -and -not $okProp.Value) {
                $errProp = $backupResult.Json.PSObject.Properties['error']
                $errText = if ($errProp) { $errProp.Value } else { (Get-String -Key "Error_ServerUnknown") }
                throw (Get-String -Key "Error_ServerReturned" -Params $errText)
            }
        }

        $ssh = $script:App.SSHManager
        $archivePath = $ssh.GetLatestBackupPath()

        $localPath = $saveDialog.FileName
        $success = $ssh.DownloadFile($archivePath, $localPath)

        if (-not $success) {
            throw (Get-String -Key "Error_BackupDownload")
        }

        $sizeText = "—"
        try {
            $f = Get-Item -LiteralPath $localPath -ErrorAction Stop
            $sizeText = Format-Bytes -Bytes $f.Length
        } catch { }

        Set-BusyState -Busy $false -Message "Backup saved"

        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Backup_Saved" -Params $localPath, $sizeText, $archivePath),
            (Get-String -Key "Msg_Info"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        Set-BusyState -Busy $false -Message "Backup error"
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Error_BackupCreate" -Params $_.Exception.Message),
            (Get-String -Key "Msg_Error"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Import-ServerConfig {
    if ($null -eq $script:App.ClientManager) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_ConnectFirst"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        (Get-String -Key "Restore_Confirm"),
        (Get-String -Key "Msg_Confirm"),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)

    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $openDialog = [System.Windows.Forms.OpenFileDialog]::new()
    $openDialog.Filter = "AmneziaWG Archive (*.tar.gz)|*.tar.gz|All files (*.*)|*.*"
    $openDialog.Title = "Select backup file to restore"
    $openDialog.InitialDirectory = [System.Environment]::GetFolderPath("MyDocuments")

    if ($openDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    $localPath = $openDialog.FileName
    $remotePath = "/root/awg/backups/restore_upload_$(Get-Date -Format 'yyyyMMddHHmmss').tar.gz"

    Set-BusyState -Busy $true -Message (Get-String -Key "Restore_Uploading")

    try {
        $ssh = $script:App.SSHManager
        $uploadSuccess = $ssh.UploadFile($localPath, $remotePath)

        if (-not $uploadSuccess) {
            throw (Get-String -Key "Error_BackupDownload")
        }

        Set-BusyState -Busy $true -Message (Get-String -Key "Restore_Restoring")

        $cm = $script:App.ClientManager
        $result = $cm.RestoreBackup($remotePath)

        $ok = Get-AWGConfigProperty -Object $result -Name 'ok'
        if ($ok) {
            Set-BusyState -Busy $false -Message "Restored"
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Restore_Restored"),
                (Get-String -Key "Msg_Info"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Information)
            
            Refresh-ClientsList
        }
        else {
            $errText = Get-AWGConfigProperty -Object $result -Name 'error'
            throw (Get-String -Key "Error_ServerReturned" -Params $errText)
        }
    }
    catch {
        Set-BusyState -Busy $false -Message "Restore error"
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Restore_Error" -Params $_.Exception.Message),
            (Get-String -Key "Msg_Error"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Restart-AWGService {    $confirm = [System.Windows.Forms.MessageBox]::Show(
        (Get-String -Key "Restart_Confirm"),
        (Get-String -Key "Restart_Confirm"),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)

    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    Set-BusyState -Busy $true -Message (Get-String -Key "Restart_Restarting")

    try {
        $cm = $script:App.ClientManager
        $result = $cm.RestartService()

        $ok = Get-AWGConfigProperty -Object $result -Name 'ok'
        if ($ok) {
            Set-BusyState -Busy $false -Message "Service restarted"
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Restart_Restarted"),
                (Get-String -Key "Msg_Info"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        else {
            $errText = Get-AWGConfigProperty -Object $result -Name 'error'
            throw (Get-String -Key "Error_ServerReturned" -Params $errText)
        }
    }
    catch {
        Set-BusyState -Busy $false -Message "Restart error"
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Error_ServiceRestart" -Params $_.Exception.Message),
            (Get-String -Key "Msg_Error"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}