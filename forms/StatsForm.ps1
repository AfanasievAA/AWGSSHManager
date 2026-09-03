#requires -Version 7.5
# =============================================================================
#  StatsForm.ps1 — Traffic statistics dialog
#  Version: 0.2
#  Description: Displays traffic statistics for all clients with
#               received/sent bytes, last handshake time, and status.
# =============================================================================

function Show-StatsForm {
    param($ClientManager, [System.Windows.Forms.Form]$ParentForm)
    
    $dialog = [System.Windows.Forms.Form]::new()
    $dialog.Text = Get-String -Key "Stats_Title"
    $dialog.Size = [System.Drawing.Size]::new(700, 500)
    $dialog.StartPosition = "CenterParent"
    $dialog.Font = [System.Drawing.Font]::new("Segoe UI", 9)
    
    # === Header ===
    $lblHeader = [System.Windows.Forms.Label]::new()
    $lblHeader.Text = Get-String -Key "Stats_Header"
    $lblHeader.Font = [System.Drawing.Font]::new("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $lblHeader.Location = [System.Drawing.Point]::new(15, 15)
    $lblHeader.AutoSize = $true
    $dialog.Controls.Add($lblHeader)
    
    # === DataGridView ===
    $dgvStats = [System.Windows.Forms.DataGridView]::new()
    $dgvStats.Location = [System.Drawing.Point]::new(15, 50)
    $dgvStats.Size = [System.Drawing.Size]::new(650, 350)
    $dgvStats.AllowUserToAddRows = $false
    $dgvStats.ReadOnly = $true
    $dgvStats.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $dgvStats.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $dgvStats.RowHeadersVisible = $false
    
    $statsColumns = @(
        @{Name="Name"; HeaderTextKey="Stats_Column_Client"; AutoSizeMode="Fill"},
        @{Name="IP"; HeaderTextKey="Stats_Column_IP"; AutoSizeMode="AllCells"},
        @{Name="Rx"; HeaderTextKey="Stats_Column_Rx"; AutoSizeMode="AllCells"},
        @{Name="Tx"; HeaderTextKey="Stats_Column_Tx"; AutoSizeMode="AllCells"},
        @{Name="Total"; HeaderTextKey="Stats_Column_Total"; AutoSizeMode="AllCells"},
        @{Name="Handshake"; HeaderTextKey="Stats_Column_Handshake"; AutoSizeMode="AllCells"},
        @{Name="Status"; HeaderTextKey="Stats_Column_Status"; AutoSizeMode="AllCells"}
    )
    
    foreach ($col in $statsColumns) {
        $column = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
        $column.Name = $col.Name
        $column.HeaderText = Get-String -Key $col.HeaderTextKey
        $column.AutoSizeMode = $col.AutoSizeMode
        $dgvStats.Columns.Add($column)
    }
    $dialog.Controls.Add($dgvStats)
    
    # === Buttons ===
    $btnRefresh = [System.Windows.Forms.Button]::new()
    $btnRefresh.Text = Get-String -Key "Stats_Refresh"
    $btnRefresh.Location = [System.Drawing.Point]::new(15, 415)
    $btnRefresh.Size = [System.Drawing.Size]::new(120, 32)
    $btnRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $dialog.Controls.Add($btnRefresh)
    
    $btnClose = [System.Windows.Forms.Button]::new()
    $btnClose.Text = Get-String -Key "Stats_Close"
    $btnClose.Location = [System.Drawing.Point]::new(580, 415)
    $btnClose.Size = [System.Drawing.Size]::new(85, 32)
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClose.Add_Click({ $dialog.Close() })
    $dialog.Controls.Add($btnClose)
    
    # === Total stats ===
    $lblTotal = [System.Windows.Forms.Label]::new()
    $lblTotal.Text = (Get-String -Key "Stats_Total" -Params "0 B", "0 B")
    $lblTotal.Location = [System.Drawing.Point]::new(150, 420)
    $lblTotal.AutoSize = $true
    $lblTotal.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $dialog.Controls.Add($lblTotal)
    
    function Load-Stats {
        $dgvStats.Rows.Clear()
        $totalRx = 0L
        $totalTx = 0L
        
        try {
            $cm = $ClientManager
            $stats = $cm.GetClientStats()
            
            foreach ($stat in $stats) {
                $rxVal = Get-AWGConfigProperty -Object $stat -Name 'rx'
                $txVal = Get-AWGConfigProperty -Object $stat -Name 'tx'
                $rxText = if ($rxVal) { Format-Bytes -Bytes ([long]$rxVal) } else { "0 B" }
                $txText = if ($txVal) { Format-Bytes -Bytes ([long]$txVal) } else { "0 B" }
                $totalBytes = ([long]$rxVal + [long]$txVal)
                $totalText = Format-Bytes -Bytes $totalBytes
                
                $lastHs = Get-AWGConfigProperty -Object $stat -Name 'last_handshake'
                $handshakeText = if ($lastHs -and [long]$lastHs -gt 0) {
                    try {
                        $handshakeTime = [DateTimeOffset]::FromUnixTimeSeconds([long]$lastHs)
                        $timeAgo = [DateTimeOffset]::Now - $handshakeTime
                        
                        if ($timeAgo.TotalMinutes -lt 1) {
                            Get-String -Key "Stats_Handshake_Now"
                        }
                        elseif ($timeAgo.TotalHours -lt 1) {
                            Get-String -Key "Stats_Handshake_Min" -Params ([int]$timeAgo.TotalMinutes)
                        }
                        elseif ($timeAgo.TotalDays -lt 1) {
                            Get-String -Key "Stats_Handshake_Hour" -Params ([int]$timeAgo.TotalHours)
                        }
                        else {
                            Get-String -Key "Stats_Handshake_Day" -Params ([int]$timeAgo.TotalDays)
                        }
                    }
                    catch {
                        $lastHs
                    }
                }
                else {
                    Get-String -Key "Stats_Handshake_Never"
                }
                
                $stName = Get-AWGConfigProperty -Object $stat -Name 'name'
                $stIp   = Get-AWGConfigProperty -Object $stat -Name 'ip'
                # Use machine-stable status_code: server 'status' text is locale-dependent
                $stStat = (Get-AWGStatusDisplay -StatusCode ([string](Get-AWGConfigProperty -Object $stat -Name 'status_code'))).Text
                
                [void]$dgvStats.Rows.Add(
                    $stName,
                    $stIp,
                    $rxText,
                    $txText,
                    $totalText,
                    $handshakeText,
                    $stStat
                )
                
                $totalRx += [long]$rxVal
                $totalTx += [long]$txVal
            }
            
            $lblTotal.Text = (Get-String -Key "Stats_Total" -Params (Format-Bytes -Bytes $totalRx), (Format-Bytes -Bytes $totalTx))
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-String -Key "Error_StatsLoad" -Params $_.Exception.Message),
                (Get-String -Key "Msg_Error"),
                "OK",
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
    
    $btnRefresh.Add_Click({ Load-Stats })
    
    $dialog.Add_Shown({ Load-Stats })
    
    $dialog.ShowDialog($ParentForm) | Out-Null
    $dialog.Dispose()
}