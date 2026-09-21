param([string]$ExePath = "$PSScriptRoot\..\build\DualCursor-next.exe")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class ScreenLockUiTest {
    public delegate bool WindowCallback(IntPtr h, IntPtr p);
    public delegate bool MonitorCallback(IntPtr m, IntPtr dc, IntPtr r, IntPtr p);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct MonitorInfo {
        public int Size; public Rect Bounds, Work; public uint Flags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string Device;
    }
    [StructLayout(LayoutKind.Sequential)] public struct IconInfo {
        public bool IsIcon; public uint X, Y; public IntPtr Mask, Color;
    }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowW(string c, string t);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, WindowCallback callback, IntPtr p);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool RedrawWindow(IntPtr h, IntPtr rect, IntPtr region, uint flags);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int height, uint flags);
    [DllImport("user32.dll")] public static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorCallback callback, IntPtr p);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool GetMonitorInfoW(IntPtr m, ref MonitorInfo info);
    [DllImport("user32.dll")] public static extern IntPtr LoadCursorW(IntPtr inst, IntPtr id);
    [DllImport("user32.dll")] public static extern bool GetIconInfo(IntPtr icon, out IconInfo info);
    [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr obj);
    public static string Text(IntPtr h) { var text = new StringBuilder(256); GetWindowTextW(h, text, 256); return text.ToString(); }
    public static int ButtonCount(IntPtr h) {
        int count = 0;
        EnumChildWindows(h, (child,p) => { if (GetDlgCtrlID(child) >= 300) count++; return true; }, IntPtr.Zero);
        return count;
    }
    public static bool OverlayInside(uint pid, int seat, int number) {
        var h = FindWindowW("DualCursor.CursorOverlay", "DualCursor mouse " + seat);
        uint owner; GetWindowThreadProcessId(h, out owner);
        if (owner != pid) return false;
        Rect r; GetWindowRect(h, out r);
        IconInfo icon; GetIconInfo(LoadCursorW(IntPtr.Zero, new IntPtr(32512)), out icon);
        int x = r.Left + (int)icon.X, y = r.Top + (int)icon.Y;
        if (icon.Mask != IntPtr.Zero) DeleteObject(icon.Mask);
        if (icon.Color != IntPtr.Zero) DeleteObject(icon.Color);
        bool inside = false;
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (m,dc,b,p) => {
            var info = new MonitorInfo(); info.Size = Marshal.SizeOf(info);
            if (GetMonitorInfoW(m, ref info) && info.Device.EndsWith("DISPLAY" + number))
                inside = x >= info.Bounds.Left && x < info.Bounds.Right && y >= info.Bounds.Top && y < info.Bounds.Bottom;
            return true;
        }, IntPtr.Zero);
        return inside;
    }
}
'@

function Click-Button([IntPtr]$Handle) {
    if ($Handle -eq [IntPtr]::Zero) { throw 'Missing button' }
    [void][ScreenLockUiTest]::SendMessageW($Handle, 0xF5, [IntPtr]::Zero, [IntPtr]::Zero)
}
function Save-Window([IntPtr]$Handle, [string]$Name) {
    Start-Sleep -Milliseconds 100
    [void][ScreenLockUiTest]::RedrawWindow($Handle, [IntPtr]::Zero, [IntPtr]::Zero, 0x185)
    $rect = New-Object ScreenLockUiTest+Rect
    [void][ScreenLockUiTest]::GetWindowRect($Handle, [ref]$rect)
    $bitmap = New-Object System.Drawing.Bitmap(($rect.Right-$rect.Left), ($rect.Bottom-$rect.Top))
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    try {
        if (![ScreenLockUiTest]::PrintWindow($Handle, $dc, 2)) { throw 'Window rendering failed' }
    } finally { $graphics.ReleaseHdc($dc) }
    $bitmap.Save((Join-Path $PSScriptRoot "..\build\$Name"), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

if ([ScreenLockUiTest]::FindWindowW('DualCursor.Engine', 'DualCursor') -ne [IntPtr]::Zero) {
    throw 'Close the running DualCursor before this smoke test.'
}
$app = Start-Process -FilePath (Resolve-Path $ExePath).Path -ArgumentList '--seconds=30' -PassThru -WindowStyle Normal
$window = [IntPtr]::Zero
try {
    Start-Sleep -Seconds 2
    $window = [ScreenLockUiTest]::FindWindowW('DualCursor.Engine', 'DualCursor')
    [uint32]$owner = 0
    [void][ScreenLockUiTest]::GetWindowThreadProcessId($window, [ref]$owner)
    if ($owner -ne $app.Id) { throw 'Main window missing' }
    $list = [ScreenLockUiTest]::GetDlgItem($window, 201)
    $seats = [ScreenLockUiTest]::SendMessageW($list, 0x18B, [IntPtr]::Zero, [IntPtr]::Zero).ToInt32()
    $buttons = [ScreenLockUiTest]::ButtonCount($list)
    $screens = [int]($buttons / $seats)
    if ($screens -lt 1 -or $seats -lt 2 -or $buttons -ne $screens * $seats) { throw 'Unexpected monitor button count' }
    $first = [ScreenLockUiTest]::GetDlgItem($list, 300)
    $second = [ScreenLockUiTest]::GetDlgItem($list, 300 + $screens * 2 - 1)
    Click-Button $first
    if (![ScreenLockUiTest]::Text($first).StartsWith('Unlock')) { throw 'First seat did not lock' }
    if ([ScreenLockUiTest]::Text($second).StartsWith('Unlock')) { throw 'Other seat changed unexpectedly' }
    Click-Button $second
    $number = [int]([regex]::Match([ScreenLockUiTest]::Text($second), '\d+$').Value)
    if (![ScreenLockUiTest]::OverlayInside([uint32]$app.Id, 2, $number)) { throw 'Pointer outside locked display' }
    Click-Button $first
    if ([ScreenLockUiTest]::Text($first).StartsWith('Unlock')) { throw 'Second click did not release lock' }
    if (![ScreenLockUiTest]::Text($second).StartsWith('Unlock')) { throw 'Other seat lost its lock' }
    Click-Button $first
    $last = [ScreenLockUiTest]::GetDlgItem($list, 300 + $screens - 1)
    if ($screens -gt 1) {
        Click-Button $last
        if ([ScreenLockUiTest]::Text($first).StartsWith('Unlock')) { throw 'Previous display stayed selected' }
    }
    [void][ScreenLockUiTest]::SendMessageW($window, 0x7E, [IntPtr]::Zero, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 600
    $last = [ScreenLockUiTest]::GetDlgItem($list, 300 + $screens - 1)
    if (![ScreenLockUiTest]::Text($last).StartsWith('Unlock')) { throw 'Display refresh lost the lock' }
    Save-Window $window 'screen-lock.png'
    [void][ScreenLockUiTest]::SetWindowPos($window, [IntPtr]::Zero, 0, 0, 500, 360, 22)
    Save-Window $window 'screen-lock-narrow.png'
    [void][ScreenLockUiTest]::SetWindowPos($window, [IntPtr]::Zero, 0, 0, 500, 270, 22)
    [void][ScreenLockUiTest]::SendMessageW($list, 0x197, [IntPtr]::new(1), [IntPtr]::Zero)
    $second = [ScreenLockUiTest]::GetDlgItem($list, 300 + $screens * 2 - 1)
    $listRect = New-Object ScreenLockUiTest+Rect
    $buttonRect = New-Object ScreenLockUiTest+Rect
    [void][ScreenLockUiTest]::GetWindowRect($list, [ref]$listRect)
    [void][ScreenLockUiTest]::GetWindowRect($second, [ref]$buttonRect)
    if ($buttonRect.Top -lt $listRect.Top -or $buttonRect.Bottom -gt $listRect.Bottom) { throw 'Button failed to follow row scrolling' }
    Click-Button $second
    if ([ScreenLockUiTest]::Text($second).StartsWith('Unlock')) { throw 'Scrolled button did not release the correct seat' }
    if (![ScreenLockUiTest]::Text($last).StartsWith('Unlock')) { throw 'Scrolled button changed the other seat' }
    Click-Button ([ScreenLockUiTest]::GetDlgItem($window, 200))
    if (!$app.WaitForExit(10000) -or $app.ExitCode -ne 0) { throw 'Close button failed' }
    Write-Output "GUI tests passed: $seats seats, $screens screens; independent locks, toggle, switch, pointer bounds, display refresh, close."
} finally {
    if (!$app.HasExited) {
        if ($window -ne [IntPtr]::Zero) { [void][ScreenLockUiTest]::SendMessageW($window, 0x10, [IntPtr]::Zero, [IntPtr]::Zero) }
        [void]$app.WaitForExit(35000)
    }
}
