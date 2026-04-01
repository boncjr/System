Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "System Monitor"
$form.Size = New-Object System.Drawing.Size(520,420)
$form.MinimumSize = New-Object System.Drawing.Size(400,300)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.DoubleBuffered = $true   # smoother updates

# Font (fallback included)
try {
    $font = New-Object System.Drawing.Font("0xProto Nerd Font", 11)
} catch {
    $font = New-Object System.Drawing.Font("Consolas", 11)
}

# ---- DRAG ANYWHERE FIX (works on all controls) ----
$dragging = $false
$startPoint = New-Object System.Drawing.Point

function Enable-Drag($control) {
    $control.Add_MouseDown({
        $script:dragging = $true
        $script:startPoint = [System.Windows.Forms.Cursor]::Position
    })
    $control.Add_MouseMove({
        if ($script:dragging) {
            $current = [System.Windows.Forms.Cursor]::Position
            $dx = $current.X - $script:startPoint.X
            $dy = $current.Y - $script:startPoint.Y
            $form.Location = New-Object System.Drawing.Point(
                $form.Location.X + $dx,
                $form.Location.Y + $dy
            )
            $script:startPoint = $current
        }
    })
    $control.Add_MouseUp({
        $script:dragging = $false
    })
}

Enable-Drag $form

# ---- LABEL FACTORY ----
function New-Label($y) {
    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize = $false
    $label.Width = 460
    $label.Height = 25
    $label.Location = New-Object System.Drawing.Point(20,$y)
    $label.ForeColor = [System.Drawing.Color]::White
    $label.Font = $font
    $label.Anchor = "Top,Left,Right"
    $form.Controls.Add($label)

    Enable-Drag $label  # makes labels draggable too

    return $label
}

# ---- LABELS ----
$cpuLabel = New-Label 20
$cpuUsageLabel = New-Label 50

$ramTotalLabel = New-Label 100
$ramUsedLabel = New-Label 130
$ramFreeLabel = New-Label 160

$gpuLabel = New-Label 210
$gpuUsageLabel = New-Label 240

# ---- SYSTEM STATS ----
function Update-Stats {
    # CPU
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cpuName = $cpu.Name
    $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $cpuUsage = [math]::Round($cpuUsage,1)

    # RAM
    $os = Get-CimInstance Win32_OperatingSystem
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB,2)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB,2)
    $usedRAM = [math]::Round($totalRAM - $freeRAM,2)

    # GPU
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $gpuName = $gpu.Name

    try {
        $gpuUsage = (Get-Counter '\GPU Engine(*)\Utilization Percentage').CounterSamples |
            Where-Object {$_.InstanceName -like "*engtype_3D*"} |
            Measure-Object CookedValue -Sum |
            Select-Object -ExpandProperty Sum
        $gpuUsage = [math]::Round($gpuUsage,1)
    } catch {
        $gpuUsage = "N/A"
    }

    # ---- SET TEXT (each on its own line) ----
    $cpuLabel.Text = "CPU: $cpuName"
    $cpuUsageLabel.Text = "CPU Usage: $cpuUsage %"

    $ramTotalLabel.Text = "RAM Total: $totalRAM GB"
    $ramUsedLabel.Text = "RAM Used: $usedRAM GB"
    $ramFreeLabel.Text = "RAM Free: $freeRAM GB"

    $gpuLabel.Text = "GPU: $gpuName"
    $gpuUsageLabel.Text = "GPU Usage: $gpuUsage %"
}

# ---- TIMER ----
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({ Update-Stats })

$timer.Start()
Update-Stats()

$form.ShowDialog()
