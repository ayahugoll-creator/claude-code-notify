# Claude Code Notify - Windows Edition
# Usage: powershell -File notify-if-away.ps1 -Event Stop|PermissionRequest
# Reads stdin JSON for last_assistant_message (Stop event only).

param(
    [Parameter(Mandatory=$true)]
    [string]$Event,

    [string]$Sound = "default"
)

# Parse stdin for summary (Stop hook provides last_assistant_message)
$summaryText = ""
$rawInput = $input | Out-String
if ($Event -eq "Stop" -and $rawInput) {
    try {
        $data = $rawInput | ConvertFrom-Json
        $msg = $data.last_assistant_message
        if ($msg) {
            $summaryText = if ($msg.Length -gt 120) { $msg.Substring(0, 120) + "..." } else { $msg }
        }
    } catch { }
}

# ---- Session marker for window matching ----
$markerFile = "$env:TEMP\claude-cc-notify-$PID"
$sessionId = ""
if (Test-Path $markerFile) {
    $sessionId = Get-Content $markerFile
} else {
    # First run: save current console window title as session marker
    $sessionId = [System.Console]::Title
    if (-not $sessionId) { $sessionId = "claude-$PID" }
    Set-Content -Path $markerFile -Value $sessionId
}

# ---- Foreground window detection ----
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Win32Notify {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
}
"@

$foreHwnd = [Win32Notify]::GetForegroundWindow()
$foreSb = New-Object System.Text.StringBuilder(256)
[Win32Notify]::GetWindowText($foreHwnd, $foreSb, 256) | Out-Null
$foreTitle = $foreSb.ToString()

# If foreground window title matches our session → user is looking → skip
if ($foreTitle -eq $sessionId -and $sessionId) {
    exit 0
}

# ---- Notification ----
$eventLabel = if ($Event -eq "PermissionRequest") { "Needs your approval" } else { "Finished" }
$notifyTitle = "Claude Code"
$notifyBody = if ($summaryText) { "$eventLabel`: $summaryText" } else { $eventLabel }

# Try BurntToast first, fall back to simple toast via PowerShell
$burntToast = Get-Module -ListAvailable -Name BurntToast 2>$null
if ($burntToast) {
    Import-Module BurntToast -ErrorAction SilentlyContinue
    $btn = New-BTButton -Content "Jump to Claude Code" -Arguments "activate"
    New-BurntToastNotification -Text $notifyTitle, $notifyBody -Button $btn -Silent
} else {
    # Native toast via AppID (requires shortcut registration first time)
    $toastScript = @"
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

\$template = @'
<toast activationType="foreground" launch="activate">
    <visual>
        <binding template="ToastGeneric">
            <text>$notifyTitle</text>
            <text>$($notifyBody -replace '"','\"')</text>
        </binding>
    </visual>
    <actions>
        <action content="Jump to Claude Code" arguments="activate" activationType="foreground"/>
    </actions>
</toast>
'@

\$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
\$xml.LoadXml(\$template)
\$toast = New-Object Windows.UI.Notifications.ToastNotification \$xml
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Microsoft.WindowsTerminal").Show(\$toast)
"@
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$toastScript`"" -WindowStyle Hidden
}

# ---- Click handler: jump to window ----
# Save HWND for click-to-jump handler
$hwndFile = "$env:TEMP\claude-cc-notify-hwnd-$PID"
$consoleHwnd = [Win32Notify]::GetConsoleWindow()
if ($consoleHwnd -ne [IntPtr]::Zero) {
    $consoleHwnd.ToInt64() | Out-File $hwndFile
}
