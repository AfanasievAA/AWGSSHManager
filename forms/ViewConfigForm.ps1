#requires -Version 7.5
# =============================================================================
#  ViewConfigForm.ps1 — View client .conf and QR code
#  Version: 0.1
#  Description: Displays client configuration text and QR codes.
#               Supports both WireGuard-compatible and Amnezia VPN QR types.
# =============================================================================

function Show-ViewConfigForm {
    if ($script:dgvClients.SelectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_SelectClient"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    if ($null -eq $script:App.ClientManager) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String -Key "Msg_ConnectFirst"),
            (Get-String -Key "Msg_Warning"),
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $clientName = [string]$script:dgvClients.SelectedRows[0].Cells['Name'].Value

    # Temp directory for QR PNG files
    $tempDir = Join-Path $env:TEMP "AWGAdmin"
    if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }
    $tempQr = Join-Path $tempDir ("qr_{0}_{1}.png" -f $clientName, ([guid]::NewGuid().ToString('N').Substring(0, 8)))

    $dialog = [System.Windows.Forms.Form]::new()
    $dialog.Text = Get-String -Key "ViewConfig_Title" -Params $clientName
    $dialog.Size = [System.Drawing.Size]::new(860, 600)
    $dialog.StartPosition = "CenterParent"
    $dialog.Font = [System.Drawing.Font]::new("Segoe UI", 9)

    # === Header ===
    $lblHeader = [System.Windows.Forms.Label]::new()
    $lblHeader.Text = Get-String -Key "ViewConfig_Client" -Params $clientName
    $lblHeader.Font = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblHeader.Location = [System.Drawing.Point]::new(12, 12)
    $lblHeader.AutoSize = $true
    [void]$dialog.Controls.Add($lblHeader)

    # === Split container ===
    $split = [System.Windows.Forms.SplitContainer]::new()
    $split.Location = [System.Drawing.Point]::new(12, 40)
    $split.Size = [System.Drawing.Size]::new(820, 440)
    $split.SplitterDistance = 500
    $split.FixedPanel = [System.Windows.Forms.FixedPanel]::Panel2
    [void]$dialog.Controls.Add($split)

    # --- Left: .conf ---
    $txtConfig = [System.Windows.Forms.TextBox]::new()
    $txtConfig.Multiline = $true
    $txtConfig.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $txtConfig.ReadOnly = $true
    $txtConfig.Font = [System.Drawing.Font]::new("Consolas", 10)
    $txtConfig.Dock = [System.Windows.Forms.DockStyle]::Fill
    $txtConfig.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 250)
    $txtConfig.WordWrap = $false
    $txtConfig.Text = Get-String -Key "ViewConfig_Loading"
    [void]$split.Panel1.Controls.Add($txtConfig)

    # --- Right: QR ---
    $qrPanel = [System.Windows.Forms.Panel]::new()
    $qrPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $qrPanel.Padding = [System.Windows.Forms.Padding]::new(8)
    [void]$split.Panel2.Controls.Add($qrPanel)

    $lblQrKind = [System.Windows.Forms.Label]::new()
    $lblQrKind.Text = Get-String -Key "ViewConfig_QrKind"
    $lblQrKind.Location = [System.Drawing.Point]::new(8, 0)
    $lblQrKind.AutoSize = $true
    [void]$qrPanel.Controls.Add($lblQrKind)

    $cboQrKind = [System.Windows.Forms.ComboBox]::new()
    $cboQrKind.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$cboQrKind.Items.Add((Get-String -Key "ViewConfig_QrWireGuard"))
    [void]$cboQrKind.Items.Add((Get-String -Key "ViewConfig_QrAmnezia"))
    $cboQrKind.SelectedIndex = 0
    $cboQrKind.Location = [System.Drawing.Point]::new(8, 28)
    $cboQrKind.Size = [System.Drawing.Size]::new(290, 23)
    [void]$qrPanel.Controls.Add($cboQrKind)

    $pnlPicture = [System.Windows.Forms.Panel]::new()
    $pnlPicture.Location = [System.Drawing.Point]::new(8, 58)
    $pnlPicture.Size = [System.Drawing.Size]::new(290, 300)
    $pnlPicture.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $pnlPicture.BackColor = [System.Drawing.Color]::White
    [void]$qrPanel.Controls.Add($pnlPicture)

    $picQr = [System.Windows.Forms.PictureBox]::new()
    $picQr.Dock = [System.Windows.Forms.DockStyle]::Fill
    $picQr.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    [void]$pnlPicture.Controls.Add($picQr)

    $lblQrHint = [System.Windows.Forms.Label]::new()
    $lblQrHint.Text = Get-String -Key "ViewConfig_QrHint"
    $lblQrHint.Location = [System.Drawing.Point]::new(8, 364)
    $lblQrHint.Size = [System.Drawing.Size]::new(292, 50)
    $lblQrHint.ForeColor = [System.Drawing.Color]::Gray
    $lblQrHint.Font = [System.Drawing.Font]::new("Segoe UI", 8)
    [void]$qrPanel.Controls.Add($lblQrHint)

    # === Buttons ===
    $btnCopy = [System.Windows.Forms.Button]::new()
    $btnCopy.Text = Get-String -Key "ViewConfig_Copy"
    $btnCopy.Location = [System.Drawing.Point]::new(12, 495)
    $btnCopy.Size = [System.Drawing.Size]::new(160, 32)
    [void]$dialog.Controls.Add($btnCopy)

    $btnSaveConf = [System.Windows.Forms.Button]::new()
    $btnSaveConf.Text = Get-String -Key "ViewConfig_SaveConf"
    $btnSaveConf.Location = [System.Drawing.Point]::new(180, 495)
    $btnSaveConf.Size = [System.Drawing.Size]::new(150, 32)
    [void]$dialog.Controls.Add($btnSaveConf)

    $btnSaveQr = [System.Windows.Forms.Button]::new()
    $btnSaveQr.Text = Get-String -Key "ViewConfig_SaveQr"
    $btnSaveQr.Location = [System.Drawing.Point]::new(338, 495)
    $btnSaveQr.Size = [System.Drawing.Size]::new(140, 32)
    [void]$dialog.Controls.Add($btnSaveQr)

    $btnClose = [System.Windows.Forms.Button]::new()
    $btnClose.Text = Get-String -Key "ViewConfig_Close"
    $btnClose.Location = [System.Drawing.Point]::new(745, 495)
    $btnClose.Size = [System.Drawing.Size]::new(90, 32)
    $btnClose.Add_Click({ $dialog.Close() })
    [void]$dialog.Controls.Add($btnClose)

    # === QR loading ===
    function Load-Qr {
        $kind = if ($cboQrKind.SelectedIndex -eq 1) { 'vpnuri' } else { 'png' }

        if ($picQr.Image) { $picQr.Image.Dispose(); $picQr.Image = $null }
        if ($picQr.Tag)   { $picQr.Tag.Dispose();   $picQr.Tag   = $null }
        
        # Draw "Loading..." text while waiting for download
        $picQr.BackColor = [System.Drawing.Color]::White
        $loadingBmp = [System.Drawing.Bitmap]::new($pnlPicture.Width, $pnlPicture.Height)
        $g = [System.Drawing.Graphics]::FromImage($loadingBmp)
        $g.Clear([System.Drawing.Color]::White)
        $font = [System.Drawing.Font]::new("Segoe UI", 14)
        $sf = [System.Drawing.StringFormat]::new()
        $sf.Alignment = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $g.DrawString("Loading...", $font, [System.Drawing.Brushes]::Gray, [System.Drawing.RectangleF]::new(0, 0, $loadingBmp.Width, $loadingBmp.Height), $sf)
        $picQr.Image = $loadingBmp
        $g.Dispose()
        $font.Dispose()
        $sf.Dispose()
        
        [void][System.Windows.Forms.Application]::DoEvents()

        $sshMgr = $script:App.SSHManager
        $cName  = $clientName
        $dst    = $tempQr

        $ok = $sshMgr.DownloadQR($cName, $dst, $kind)

        if ($ok -and (Test-Path -LiteralPath $tempQr)) {
            $ms = [System.IO.MemoryStream]::new([System.IO.File]::ReadAllBytes($tempQr))
            $picQr.Image = [System.Drawing.Image]::FromStream($ms)
            $picQr.Tag   = $ms
            $picQr.BackColor = [System.Drawing.Color]::White
        }
        else {
            $picQr.BackColor = [System.Drawing.Color]::White
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "ViewConfig_QRNotFound") + "`n`n" + (Get-String -Key "ViewConfig_QRNotFoundDetail"),
                (Get-String -Key "Msg_Warning"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    }

    $cboQrKind.Add_SelectedIndexChanged({ Load-Qr })

    # === Load config and QR ===
    $dialog.Add_Shown({
        $cm = $script:App.ClientManager
        try {
            $txtConfig.Text = $cm.GetClientConfig($clientName)
        }
        catch {
            $txtConfig.Text = Get-String -Key "ViewConfig_LoadError"
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Error_ConfigLoad" -Params $_.Exception.Message),
                (Get-String -Key "Msg_Error"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        Load-Qr
    })

    # === Copy .conf ===
    $btnCopy.Add_Click({
        if ($txtConfig.Text -and $txtConfig.Text -ne (Get-String -Key "ViewConfig_Loading") -and 
            $txtConfig.Text -ne (Get-String -Key "ViewConfig_LoadError")) {
            [System.Windows.Forms.Clipboard]::SetText($txtConfig.Text)
            $btnCopy.Text = Get-String -Key "ViewConfig_CopyDone"
            $timer = [System.Windows.Forms.Timer]::new()
            $timer.Interval = 1500
            $timer.Add_Tick({
                $btnCopy.Text = Get-String -Key "ViewConfig_Copy"
                $this.Stop()
                $this.Dispose()
            })
            $timer.Start()
        }
    })

    # === Save .conf ===
    $btnSaveConf.Add_Click({
        if ($txtConfig.Text -and $txtConfig.Text -notin @((Get-String -Key "ViewConfig_Loading"), (Get-String -Key "ViewConfig_LoadError"))) {
            $sd = [System.Windows.Forms.SaveFileDialog]::new()
            $sd.Filter = "AmneziaWG Configuration (*.conf)|*.conf|All files (*.*)|*.*"
            $sd.FileName = "$clientName.conf"
            if ($sd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                try {
                    $txtConfig.Text | Set-Content -LiteralPath $sd.FileName -Encoding UTF8 -NoNewline
                    [System.Windows.Forms.MessageBox]::Show(
                        (Get-String -Key "ViewConfig_FileSaved") + " $($sd.FileName)",
                        (Get-String -Key "Msg_Info"),
                        "OK",
                        [System.Windows.Forms.MessageBoxIcon]::Information)
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show(
                        (Get-String -Key "Error_ConfigSave" -Params $_.Exception.Message),
                        (Get-String -Key "Msg_Error"),
                        "OK",
                        [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
        }
    })

    # === Save QR ===
    $btnSaveQr.Add_Click({
        if ($picQr.Image -and (Test-Path -LiteralPath $tempQr)) {
            $sd = [System.Windows.Forms.SaveFileDialog]::new()
            $sd.Filter = "PNG Image (*.png)|*.png"
            $sd.FileName = "$clientName" + $(if ($cboQrKind.SelectedIndex -eq 1) { ".vpnuri.png" } else { ".png" })
            if ($sd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                try {
                    Copy-Item -LiteralPath $tempQr -Destination $sd.FileName -Force
                    [System.Windows.Forms.MessageBox]::Show(
                        (Get-String -Key "ViewConfig_FileSaved") + " $($sd.FileName)",
                        (Get-String -Key "Msg_Info"),
                        "OK",
                        [System.Windows.Forms.MessageBoxIcon]::Information)
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show(
                        (Get-String -Key "Error_ConfigSave" -Params $_.Exception.Message),
                        (Get-String -Key "Msg_Error"),
                        "OK",
                        [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Error_QRNotLoaded"),
                (Get-String -Key "Msg_Warning"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })

    # === Cleanup temp files ===
    $dialog.Add_FormClosed({
        if ($picQr.Image) { $picQr.Image.Dispose() }
        if ($picQr.Tag)   { $picQr.Tag.Dispose() }
        Remove-Item -LiteralPath $tempQr -Force -ErrorAction SilentlyContinue
    })

    $dialog.ShowDialog($script:MainForm) | Out-Null
    $dialog.Dispose()
}