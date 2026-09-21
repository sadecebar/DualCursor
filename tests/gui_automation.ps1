param([string]$ExePath = "$PSScriptRoot\..\build\DualCursor-next.exe")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class AutomationTest {
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct IconInfo {
        public bool IsIcon; public uint X, Y; public IntPtr Mask, Color;
    }
    [StructLayout(LayoutKind.Sequential)] public struct MouseInput {
        public int X, Y; public uint Data, Flags, Time; public UIntPtr Extra;
    }
    [StructLayout(LayoutKind.Sequential)] public struct Input { public uint Type; public MouseInput Mouse; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct MonitorInfo {
        public int Size; public Rect Bounds, Work; public uint Flags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string Device;
    }
    public delegate bool MonitorCallback(IntPtr m, IntPtr dc, IntPtr r, IntPtr p);
    [DllImport("user32.dll")] public static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorCallback cb, IntPtr p);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool GetMonitorInfoW(IntPtr m, ref MonitorInfo i);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowW(string cls, string title);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder text, int size);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point p);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] public static extern uint SendInput(uint count, Input[] input, int size);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint x, uint y, uint data, UIntPtr extra);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] public static extern IntPtr LoadCursorW(IntPtr inst, IntPtr id);
    [DllImport("user32.dll")] public static extern bool GetIconInfo(IntPtr icon, out IconInfo info);
    [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr obj);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int height, uint flags);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint ms, out IntPtr result);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint m, IntPtr w, StringBuilder l, uint flags, uint ms, out IntPtr result);
    public static IntPtr Send(IntPtr h, uint m, int w, IntPtr l) {
        IntPtr result;
        if (h == IntPtr.Zero || SendMessageTimeoutW(h, m, new IntPtr(w), l, 2, 1500, out result) == IntPtr.Zero)
            throw new Exception("Window missing or unresponsive");
        return result;
    }
    public static Point Cursor() { Point p; if (!GetCursorPos(out p)) throw new Exception("GetCursorPos failed"); return p; }
    public static string Text(IntPtr h) {
        var text = new StringBuilder(256);
        IntPtr result;
        if (SendMessageTimeoutW(h, 0xD, new IntPtr(text.Capacity), text, 2, 1500, out result) == IntPtr.Zero)
            throw new Exception("Cannot read control text");
        return text.ToString();
    }
    public static Point Overlay(int seat, uint pid) {
        var h = FindWindowW("DualCursor.CursorOverlay", "DualCursor mouse " + seat);
        uint owner; GetWindowThreadProcessId(h, out owner);
        Rect r;
        if (owner != pid || !IsWindowVisible(h) || !GetWindowRect(h, out r)) throw new Exception("Overlay missing");
        IconInfo icon;
        if (!GetIconInfo(LoadCursorW(IntPtr.Zero, new IntPtr(32512)), out icon)) throw new Exception("Cursor hotspot missing");
        var p = new Point { X = r.Left + (int)icon.X, Y = r.Top + (int)icon.Y };
        if (icon.Mask != IntPtr.Zero) DeleteObject(icon.Mask);
        if (icon.Color != IntPtr.Zero) DeleteObject(icon.Color);
        return p;
    }
    public static MonitorInfo[] Screens() {
        var screens = new List<MonitorInfo>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (m,dc,r,p) => {
            var i = new MonitorInfo(); i.Size = Marshal.SizeOf(i);
            if (GetMonitorInfoW(m, ref i)) screens.Add(i);
            return true;
        }, IntPtr.Zero);
        screens.Sort((a,b) => int.Parse(a.Device.Substring(11)).CompareTo(int.Parse(b.Device.Substring(11))));
        return screens.ToArray();
    }
    public static void MoveInput(int x, int y) {
        var i = new Input { Type = 0 };
        i.Mouse.X = (int)(((long)x - GetSystemMetrics(76)) * 65535 / (GetSystemMetrics(78) - 1));
        i.Mouse.Y = (int)(((long)y - GetSystemMetrics(77)) * 65535 / (GetSystemMetrics(79) - 1));
        i.Mouse.Flags = 0xC001;
        if (SendInput(1, new[] { i }, Marshal.SizeOf(typeof(Input))) != 1) throw new Exception("SendInput failed");
    }
}
'@

function Assert-Point($Actual, $Expected, [string]$Message) {
    if ($Actual.X -ne $Expected.X -or $Actual.Y -ne $Expected.Y) {
        throw "$Message : got $($Actual.X),$($Actual.Y), expected $($Expected.X),$($Expected.Y)"
    }
}
function Select-Automation([int]$Seat) {
    [void][AutomationTest]::Send($choice, 0x14E, $Seat, [IntPtr]::Zero)
    [void][AutomationTest]::Send($window, 0x111, ((1 -shl 16) -bor 202), $choice)
}
function Save-Window([string]$Name) {
    $rect = New-Object AutomationTest+Rect
    [void][AutomationTest]::GetWindowRect($window, [ref]$rect)
    $bitmap = New-Object System.Drawing.Bitmap(($rect.Right-$rect.Left), ($rect.Bottom-$rect.Top))
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    try { if (![AutomationTest]::PrintWindow($window, $dc, 2)) { throw 'PrintWindow failed' } }
    finally { $graphics.ReleaseHdc($dc) }
    try { $bitmap.Save((Join-Path $PSScriptRoot "..\build\$Name"), [System.Drawing.Imaging.ImageFormat]::Png) }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}

[void][AutomationTest]::SetThreadDpiAwarenessContext([IntPtr]::new(-4))
if ([AutomationTest]::FindWindowW('DualCursor.Engine', 'DualCursor') -ne [IntPtr]::Zero) {
    throw 'Close DualCursor before this test. Do not move the physical mice during the test.'
}
$before = [AutomationTest]::Cursor()
$app = Start-Process -FilePath (Resolve-Path $ExePath).Path -ArgumentList '--seconds=30','--verbose' -PassThru -WindowStyle Hidden
$window = [IntPtr]::Zero
try {
    Start-Sleep -Seconds 2
    $window = [AutomationTest]::FindWindowW('DualCursor.Engine', 'DualCursor')
    [uint32]$owner = 0
    [void][AutomationTest]::GetWindowThreadProcessId($window, [ref]$owner)
    if ($owner -ne $app.Id) { throw 'Main window missing' }
    $choice = [AutomationTest]::GetDlgItem($window, 202)
    if ([AutomationTest]::Send($choice, 0x147, 0, [IntPtr]::Zero).ToInt32() -ne 2) { throw 'Default is not Mouse 2' }
    if ([AutomationTest]::Text($choice) -ne 'Mouse 2') { throw 'Automation label is not English' }
    if ([AutomationTest]::Text([AutomationTest]::GetDlgItem($window, 200)) -ne 'Close DualCursor') { throw 'Close label is not English' }
    $screens = [AutomationTest]::Screens()
    $bounds = $screens[-1].Bounds
    $x = [int](($bounds.Left + $bounds.Right) / 2)
    $y = [int](($bounds.Top + $bounds.Bottom) / 2)
    $blue = [AutomationTest]::Overlay(1, $app.Id)
    for ($step = 0; $step -lt 10; $step++) {
        [void][AutomationTest]::SetCursorPos($x + $step * 4, $y)
        Start-Sleep -Milliseconds 60
        Assert-Point ([AutomationTest]::Overlay(2, $app.Id)) ([AutomationTest]::Cursor()) 'Direct warp not visible'
        Assert-Point ([AutomationTest]::Overlay(1, $app.Id)) $blue 'Mouse 1 moved with automation'
    }
    [AutomationTest]::MoveInput($x + 70, $y + 40)
    Start-Sleep -Milliseconds 100
    Assert-Point ([AutomationTest]::Overlay(2, $app.Id)) ([AutomationTest]::Cursor()) 'SendInput not visible'
    [AutomationTest]::mouse_event(1, 20, 10, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 100
    Assert-Point ([AutomationTest]::Overlay(2, $app.Id)) ([AutomationTest]::Cursor()) 'Relative input not visible'

    # A genuine DualCursor warp of the active seat must not drag Mouse 2 along.
    $orange = [AutomationTest]::Overlay(2, $app.Id)
    $list = [AutomationTest]::GetDlgItem($window, 201)
    $ownLock = [AutomationTest]::GetDlgItem($list, 300)
    [void][AutomationTest]::Send($ownLock, 0xF5, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 100
    Assert-Point ([AutomationTest]::Overlay(2, $app.Id)) $orange 'Own warp misclassified as automation'
    [void][AutomationTest]::Send($ownLock, 0xF5, 0, [IntPtr]::Zero)

    Select-Automation 0
    [void][AutomationTest]::SetCursorPos($x, $y - 30)
    Start-Sleep -Milliseconds 100
    Assert-Point ([AutomationTest]::Overlay(2, $app.Id)) $orange 'Off still tracks automation'
    Select-Automation 1
    [void][AutomationTest]::SetCursorPos($x, $y - 60)
    Start-Sleep -Milliseconds 100
    Assert-Point ([AutomationTest]::Overlay(1, $app.Id)) ([AutomationTest]::Cursor()) 'Seat selection failed'
    Assert-Point ([AutomationTest]::Overlay(2, $app.Id)) $orange 'Selection moved wrong seat'
    Select-Automation 2

    [void][AutomationTest]::PostMessageW($window, 0x112, [IntPtr]::new(0xF020), [IntPtr]::Zero)
    Start-Sleep -Milliseconds 200
    if (![AutomationTest]::IsIconic($window)) { throw 'Did not minimize' }
    [void][AutomationTest]::SetCursorPos($x - 40, $y)
    Start-Sleep -Milliseconds 100
    Assert-Point ([AutomationTest]::Overlay(2, $app.Id)) ([AutomationTest]::Cursor()) 'Minimized automation froze'
    [void][AutomationTest]::PostMessageW($window, 0x112, [IntPtr]::new(0xF120), [IntPtr]::Zero)
    Start-Sleep -Milliseconds 200

    if ($screens.Count -gt 1) {
        $lock = [AutomationTest]::GetDlgItem($list, 300 + $screens.Count)
        [void][AutomationTest]::Send($lock, 0xF5, 0, [IntPtr]::Zero)
        [void][AutomationTest]::SetCursorPos($x + 90, $y + 90)
        Start-Sleep -Milliseconds 100
        $p = [AutomationTest]::Overlay(2, $app.Id)
        $b = $screens[0].Bounds
        if ($p.X -lt $b.Left -or $p.X -ge $b.Right -or $p.Y -lt $b.Top -or $p.Y -ge $b.Bottom) { throw 'Overlay escaped screen lock' }
        $real = [AutomationTest]::Cursor()
        if ($real.X -ne $x + 90 -or $real.Y -ne $y + 90) { throw 'Visual mirror warped system cursor' }
        [void][AutomationTest]::Send($lock, 0xF5, 0, [IntPtr]::Zero)
    }
    Save-Window 'automation.png'
    [void][AutomationTest]::SetWindowPos($window, [IntPtr]::Zero, 0, 0, 500, 270, 22)
    Save-Window 'automation-narrow.png'
    [void][AutomationTest]::Send([AutomationTest]::GetDlgItem($window, 200), 0xF5, 0, [IntPtr]::Zero)
    if (!$app.WaitForExit(5000) -or $app.ExitCode -ne 0) { throw 'Normal close failed' }
    Write-Output 'PASS: SetCursorPos, SendInput, relative input, other-seat isolation, own warp filtering, off, seat selection, minimized tracking, screen bounds and normal close.'
} finally {
    if (!$app.HasExited) {
        if ($window -ne [IntPtr]::Zero) { [void][AutomationTest]::PostMessageW($window, 0x10, [IntPtr]::Zero, [IntPtr]::Zero) }
        if (!$app.WaitForExit(3000)) { $app.Kill(); $app.WaitForExit() }
    }
    [void][AutomationTest]::SetCursorPos($before.X, $before.Y)
}
