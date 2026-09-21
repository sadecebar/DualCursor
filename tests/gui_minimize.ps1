param([string]$ExePath = "$PSScriptRoot\..\build\DualCursor-next.exe", [switch]$CaptionInput, [switch]$InjectedInput)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class MinimizeTest {
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct TitleBar {
        public uint Size; public Rect Bounds;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst=6)] public uint[] State;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst=6)] public Rect[] Parts;
    }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowW(string cls, string title);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr h, ref Point p);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(Point p);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int height, uint flags);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint x, uint y, uint data, UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint ms, out IntPtr result);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder text, int count);
    public static bool Responds(IntPtr h) {
        IntPtr result;
        return h != IntPtr.Zero && SendMessageTimeoutW(h, 0, IntPtr.Zero, IntPtr.Zero, 2, 1000, out result) != IntPtr.Zero;
    }
    public static string Text(IntPtr h) { var s = new StringBuilder(256); GetWindowTextW(h, s, 256); return s.ToString(); }
    public static void Click(IntPtr h) {
        IntPtr result;
        if (h == IntPtr.Zero || SendMessageTimeoutW(h, 0xF5, IntPtr.Zero, IntPtr.Zero, 2, 2000, out result) == IntPtr.Zero)
            throw new Exception("Button did not respond");
    }
    public static void FocusButton(IntPtr parent, int id, IntPtr button) {
        IntPtr result;
        // Reproduce the focus notification produced by a physical button click.
        if (SendMessageTimeoutW(parent, 0x111, new IntPtr((6 << 16) | id), button, 2, 2000, out result) == IntPtr.Zero)
            throw new Exception("Button focus did not respond");
    }
    private static IntPtr Pack(Point p) { return new IntPtr(unchecked((p.Y << 16) | (p.X & 65535))); }
    public static Point PressCaption(IntPtr h, bool injected, int hit) {
        SetThreadDpiAwarenessContext(new IntPtr(-4));
        int size = Marshal.SizeOf(typeof(TitleBar));
        IntPtr buffer = Marshal.AllocHGlobal(size);
        try {
            Marshal.WriteInt32(buffer, size);
            IntPtr result;
            if (SendMessageTimeoutW(h, 0x33F, IntPtr.Zero, buffer, 2, 2000, out result) == IntPtr.Zero)
                throw new Exception("Cannot read titlebar buttons");
            var title = (TitleBar)Marshal.PtrToStructure(buffer, typeof(TitleBar));
            var r = title.Parts[hit == 8 ? 2 : hit == 9 ? 3 : 5];
            var p = new Point { X = (r.Left+r.Right)/2, Y = (r.Top+r.Bottom)/2 };
            if (r.Right <= r.Left || r.Bottom <= r.Top)
                throw new Exception("Caption button bounds are empty");
            if (injected) {
                SetWindowPos(h, new IntPtr(-1), 0, 0, 0, 0, 0x43);
                SetForegroundWindow(h);
                if (WindowFromPoint(p) != h) throw new Exception("Caption button is covered by another window");
                SetCursorPos(p.X, p.Y);
                mouse_event(2, 0, 0, 0, UIntPtr.Zero);
            } else {
                PostMessageW(h, 0xA1, new IntPtr(hit), Pack(p));
            }
            return p;
        } finally { Marshal.FreeHGlobal(buffer); }
    }
    public static void ReleaseCaption(IntPtr h, Point p, bool injected) {
        if (injected) {
            SetCursorPos(p.X, p.Y);
            mouse_event(4, 0, 0, 0, UIntPtr.Zero);
            return;
        }
        ScreenToClient(h, ref p);
        PostMessageW(h, 0x202, IntPtr.Zero, Pack(p));
    }
}
'@

if ([MinimizeTest]::FindWindowW('DualCursor.Engine', 'DualCursor') -ne [IntPtr]::Zero) {
    throw 'Close the running DualCursor before this regression test.'
}
$logPath = Join-Path $env:APPDATA 'DualCursor\dualcursor.log'
$logLength = if (Test-Path $logPath) { (Get-Item $logPath).Length } else { 0 }
$app = Start-Process -FilePath (Resolve-Path $ExePath).Path -ArgumentList '--seconds=45','--verbose' -PassThru -WindowStyle Normal
$window = [IntPtr]::Zero
try {
    Start-Sleep -Seconds 2
    $window = [MinimizeTest]::FindWindowW('DualCursor.Engine', 'DualCursor')
    [uint32]$owner = 0
    [void][MinimizeTest]::GetWindowThreadProcessId($window, [ref]$owner)
    if ($owner -ne $app.Id -or ![MinimizeTest]::Responds($window)) { throw 'Main window missing or hung' }
    if ($InjectedInput) {
        # Caption test input is not a macro for the screen-locked second seat.
        $choice = [MinimizeTest]::GetDlgItem($window, 202)
        [IntPtr]$result = [IntPtr]::Zero
        [void][MinimizeTest]::SendMessageTimeoutW($choice, 0x14E, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$result)
        [void][MinimizeTest]::SendMessageTimeoutW($window, 0x111, [IntPtr]::new((1 -shl 16) -bor 202), $choice, 2, 1000, [ref]$result)
    }
    $list = [MinimizeTest]::GetDlgItem($window, 201)
    $buttons = @()
    for ($id = 300; ; $id++) {
        $button = [MinimizeTest]::GetDlgItem($list, $id)
        if ($button -eq [IntPtr]::Zero) { break }
        $buttons += $button
    }
    if ($buttons.Count -lt 2) { throw 'Missing screen buttons' }
    [MinimizeTest]::Click($buttons[0])
    [MinimizeTest]::Click($buttons[-1])
    [MinimizeTest]::FocusButton($window, 300 + $buttons.Count - 1, $buttons[-1])
    if ($CaptionInput) {
        $press = [MinimizeTest]::PressCaption($window, $InjectedInput.IsPresent, 8)
        Start-Sleep -Milliseconds 100
        $press.X -= 150
        [MinimizeTest]::ReleaseCaption($window, $press, $InjectedInput.IsPresent)
        Start-Sleep -Milliseconds 300
        if (![MinimizeTest]::Responds($window) -or [MinimizeTest]::IsIconic($window)) { throw 'Release outside did not cancel' }
    }
    for ($cycle = 0; $cycle -lt 3; $cycle++) {
        Write-Output "Minimize cycle $($cycle + 1)"
        if ($CaptionInput) {
            $press = [MinimizeTest]::PressCaption($window, $InjectedInput.IsPresent, 8)
            Start-Sleep -Seconds 4
            [MinimizeTest]::ReleaseCaption($window, $press, $InjectedInput.IsPresent)
        } else {
            [void][MinimizeTest]::PostMessageW($window, 0x112, [IntPtr]::new(0xF020), [IntPtr]::Zero)
        }
        Start-Sleep -Seconds 4
        if ($app.HasExited -or ![MinimizeTest]::Responds($window)) { throw 'App exited or hung while minimized' }
        if (![MinimizeTest]::IsIconic($window)) { throw 'Window did not minimize' }
        foreach ($seat in 1, 2) {
            $overlay = [MinimizeTest]::FindWindowW('DualCursor.CursorOverlay', "DualCursor mouse $seat")
            if (![MinimizeTest]::IsWindowVisible($overlay)) { throw "Pointer $seat disappeared on minimize" }
        }
        [void][MinimizeTest]::PostMessageW($window, 0x112, [IntPtr]::new(0xF120), [IntPtr]::Zero)
        Start-Sleep -Milliseconds 300
        if (![MinimizeTest]::Responds($window) -or [MinimizeTest]::IsIconic($window)) { throw 'Restore failed' }
        foreach ($button in $buttons[0], $buttons[-1]) {
            if (![MinimizeTest]::Text($button).StartsWith('Unlock')) { throw 'Minimize/restore lost the screen lock' }
        }
    }
    if ($CaptionInput) {
        foreach ($maximized in $true, $false) {
            $press = [MinimizeTest]::PressCaption($window, $InjectedInput.IsPresent, 9)
            Start-Sleep -Milliseconds 100
            [MinimizeTest]::ReleaseCaption($window, $press, $InjectedInput.IsPresent)
            Start-Sleep -Milliseconds 300
            if (![MinimizeTest]::Responds($window) -or [MinimizeTest]::IsZoomed($window) -ne $maximized) { throw 'Maximize/restore button failed' }
        }
    }
    $stream = [IO.File]::Open($logPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    [void]$stream.Seek($logLength, [IO.SeekOrigin]::Begin)
    $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8)
    $newLog = $reader.ReadToEnd()
    $reader.Dispose()
    if ($newLog -match '\[watchdog\]') { throw 'Watchdog released capture during minimize/restore' }
    if ($CaptionInput) {
        $press = [MinimizeTest]::PressCaption($window, $InjectedInput.IsPresent, 20)
        Start-Sleep -Milliseconds 100
        [MinimizeTest]::ReleaseCaption($window, $press, $InjectedInput.IsPresent)
    } else {
        [MinimizeTest]::Click([MinimizeTest]::GetDlgItem($window, 200))
    }
    if (!$app.WaitForExit(5000) -or $app.ExitCode -ne 0) { throw 'Normal close failed' }
    Write-Output 'PASS: three minimize/restore cycles; both overlays and screen locks retained; no watchdog fallback; normal close.'
} finally {
    if ($InjectedInput) { [MinimizeTest]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero) }
    if (!$app.HasExited) {
        if ($window -ne [IntPtr]::Zero) { [void][MinimizeTest]::PostMessageW($window, 0x10, [IntPtr]::Zero, [IntPtr]::Zero) }
        if (!$app.WaitForExit(3000)) {
            # Only the process launched by this test; its janitor restores input.
            $app.Kill()
            $app.WaitForExit()
        }
    }
}
