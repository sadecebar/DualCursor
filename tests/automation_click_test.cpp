// Integration test. Requires an engine built with DUALCURSOR_TESTING.
#include <windows.h>
#include <windowsx.h>
#include <cstdio>
#include <stdexcept>
#include <string>

int downs[2]{}, ups[2]{}, rights[2]{}, middles[2]{}, wheels[2]{};
HWND engine = nullptr, fixture = nullptr;
POINT a{}, b{};

void Check(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

LRESULT CALLBACK FixtureProc(HWND h, UINT msg, WPARAM wp, LPARAM lp) {
    const int side = GET_X_LPARAM(lp) < 300 ? 0 : 1;
    switch (msg) {
    case WM_LBUTTONDOWN: ++downs[side]; return 0;
    case WM_LBUTTONUP: ++ups[side]; return 0;
    case WM_RBUTTONDOWN: ++rights[side]; return 0;
    case WM_MBUTTONDOWN: ++middles[side]; return 0;
    case WM_MOUSEWHEEL: {
        POINT p{GET_X_LPARAM(lp), GET_Y_LPARAM(lp)};
        ScreenToClient(h, &p);
        ++wheels[p.x < 300 ? 0 : 1];
        return 0;
    }
    case WM_PAINT: {
        PAINTSTRUCT ps{};
        HDC dc = BeginPaint(h, &ps);
        RECT left{0, 0, 300, 200}, right{300, 0, 600, 200};
        FillRect(dc, &left, GetSysColorBrush(COLOR_WINDOW));
        FillRect(dc, &right, GetSysColorBrush(COLOR_BTNFACE));
        DrawTextW(dc, L"Mouse 1 - manual", -1, &left, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        DrawTextW(dc, L"Mouse 2 - automation", -1, &right, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        EndPaint(h, &ps);
        return 0;
    }
    }
    return DefWindowProcW(h, msg, wp, lp);
}

void Pump(DWORD ms = 100) {
    const ULONGLONG until = GetTickCount64() + ms;
    do {
        MSG msg{};
        while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        Sleep(2);
    } while (GetTickCount64() < until);
}

DWORD_PTR Send(HWND h, UINT msg, WPARAM wp = 0, LPARAM lp = 0) {
    DWORD_PTR result = 0;
    Check(SendMessageTimeoutW(h, msg, wp, lp, SMTO_ABORTIFHUNG, 2000, &result) != 0, "Engine did not respond");
    return result;
}

void Physical(int seat, POINT point, USHORT flags = 0) {
    Check(Send(engine, WM_APP + 20, MAKEWPARAM(seat, flags), MAKELPARAM(point.x, point.y)) == 1,
          "Not a DUALCURSOR_TESTING engine");
    Pump(30);
}

void Select(int selection) {
    HWND choice = GetDlgItem(engine, 202);
    Send(choice, CB_SETCURSEL, selection);
    Send(engine, WM_COMMAND, MAKEWPARAM(202, CBN_SELCHANGE), reinterpret_cast<LPARAM>(choice));
    Pump(30);
}

INPUT Button(DWORD flag, DWORD data = 0) {
    INPUT in{};
    in.type = INPUT_MOUSE;
    in.mi.dwFlags = flag;
    in.mi.mouseData = data;
    return in;
}

INPUT At(POINT point, DWORD flags) {
    INPUT in = Button(flags | MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK);
    in.mi.dx = static_cast<LONG>((static_cast<long long>(point.x - GetSystemMetrics(SM_XVIRTUALSCREEN)) * 65535) / (GetSystemMetrics(SM_CXVIRTUALSCREEN) - 1));
    in.mi.dy = static_cast<LONG>((static_cast<long long>(point.y - GetSystemMetrics(SM_YVIRTUALSCREEN)) * 65535) / (GetSystemMetrics(SM_CYVIRTUALSCREEN) - 1));
    return in;
}

void Inject(DWORD flag, DWORD data = 0) {
    INPUT in = Button(flag, data);
    Check(SendInput(1, &in, sizeof(in)) == 1, "Injection failed");
    Pump(100);
}

void MacroClick() {
    INPUT in[]{Button(MOUSEEVENTF_LEFTDOWN), Button(MOUSEEVENTF_LEFTUP)};
    Check(SendInput(2, in, sizeof(INPUT)) == 2, "Click injection failed");
    Pump(100);
}

int wmain(int argc, wchar_t** argv) {
    if (argc != 2) { std::puts("Usage: automation_click_test.exe path-to-test-engine.exe"); return 2; }
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    if (FindWindowW(L"DualCursor.Engine", L"DualCursor")) {
        std::puts("Close DualCursor first. Do not use the mice during this test.");
        return 2;
    }
    POINT before{};
    GetCursorPos(&before);
    PROCESS_INFORMATION process{};
    int result = 1;
    try {
        std::wstring command = L"\"" + std::wstring(argv[1]) + L"\" --seconds=60 --verbose";
        STARTUPINFOW startup{};
        startup.cb = sizeof(startup);
        startup.dwFlags = STARTF_USESHOWWINDOW;
        startup.wShowWindow = SW_HIDE;
        Check(CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &startup, &process), "Engine start failed");
        Pump(1800);
        engine = FindWindowW(L"DualCursor.Engine", L"DualCursor");
        DWORD pid = 0;
        GetWindowThreadProcessId(engine, &pid);
        Check(pid == process.dwProcessId, "Engine window missing");
        WNDCLASSW cls{};
        cls.lpfnWndProc = FixtureProc;
        cls.hInstance = GetModuleHandleW(nullptr);
        cls.lpszClassName = L"DualCursor.ClickFixture";
        cls.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        RegisterClassW(&cls);
        fixture = CreateWindowExW(WS_EX_TOPMOST, cls.lpszClassName, L"DualCursor input test",
            WS_POPUP | WS_VISIBLE, 100, 100, 600, 200, nullptr, nullptr, cls.hInstance, nullptr);
        Check(fixture != nullptr, "Fixture failed");
        a = {150, 100}; b = {450, 100};
        ClientToScreen(fixture, &a); ClientToScreen(fixture, &b);
        SetForegroundWindow(fixture);
        Pump(350);
        Check(WindowFromPoint(a) == fixture && WindowFromPoint(b) == fixture, "Fixture is covered");
        Select(2);
        Physical(0, a);

        // Direct SetCursorPos + click, with no wait for the 16ms observer.
        SetCursorPos(b.x, b.y);
        MacroClick();
        Check(downs[0] == 0 && downs[1] == 1 && ups[1] == 1, "Immediate warp/click went to wrong target");

        // Reproduce the report: cursor ownership keeps returning to Mouse 1,
        // but a positionless automation click must remain assigned to Mouse 2.
        for (int i = 0; i < 20; ++i) {
            Physical(0, a, RI_MOUSE_LEFT_BUTTON_DOWN);
            Physical(0, a, RI_MOUSE_LEFT_BUTTON_UP);
            MacroClick();
        }
        Check(downs[0] == 20 && ups[0] == 20, "Automation leaked into manual clicks");
        Check(downs[1] == 21 && ups[1] == 21, "Automation clicks were lost or duplicated");

        // Manual hold: reject BOTH halves of the automation gesture.
        Physical(0, a, RI_MOUSE_LEFT_BUTTON_DOWN);
        MacroClick();
        Check(downs[1] == 21 && ups[1] == 21, "Automation interrupted manual hold");
        Physical(0, a, RI_MOUSE_LEFT_BUTTON_UP);
        Check(ups[0] == 21, "Manual release was stolen");

        // Automation hold: even physical input assigned to that SAME seat
        // must not release or move its accepted press.
        Inject(MOUSEEVENTF_LEFTDOWN);
        Physical(1, a, RI_MOUSE_LEFT_BUTTON_DOWN);
        Physical(1, a, RI_MOUSE_LEFT_BUTTON_UP);
        Physical(0, a, RI_MOUSE_LEFT_BUTTON_DOWN);
        Physical(0, a, RI_MOUSE_LEFT_BUTTON_UP);
        Check(ups[1] == 21 && downs[0] == 21, "Physical input interrupted automation hold");
        Inject(MOUSEEVENTF_LEFTUP);
        Check(downs[1] == 22 && ups[1] == 22, "Automation release mismatch");

        Physical(0, a, RI_MOUSE_LEFT_BUTTON_DOWN);
        Physical(0, a, RI_MOUSE_LEFT_BUTTON_UP);
        Inject(MOUSEEVENTF_RIGHTDOWN); Inject(MOUSEEVENTF_RIGHTUP);
        Inject(MOUSEEVENTF_MIDDLEDOWN); Inject(MOUSEEVENTF_MIDDLEUP);
        Inject(MOUSEEVENTF_WHEEL, WHEEL_DELTA);
        Check(rights[0] == 0 && rights[1] == 1 && middles[0] == 0 && middles[1] == 1 &&
              wheels[0] == 0 && wheels[1] == 1, "Right/middle/wheel went to manual target");

        Inject(MOUSEEVENTF_LEFTDOWN);
        Select(0);
        Check(ups[1] == 23, "Disabling automation left a held button");
        Check(!(GetAsyncKeyState(VK_LBUTTON) & 0x8000), "Button stuck after disable");
        // With routing disabled the OS owns targeting. Keep position and
        // transition together, independent of physical input between calls.
        INPUT direct[]{At(a, MOUSEEVENTF_LEFTDOWN), At(a, MOUSEEVENTF_LEFTUP)};
        Check(SendInput(2, direct, sizeof(INPUT)) == 2, "Disabled injection failed");
        Pump(150);
        Check(downs[0] == 23 && ups[0] == 23, "Disabled mode is not pass-through");

        Select(2);
        // One batch with explicit move + click must preserve its own position.
        INPUT batch[]{At(b, MOUSEEVENTF_MOVE),
                      Button(MOUSEEVENTF_LEFTDOWN), Button(MOUSEEVENTF_LEFTUP)};
        Check(SendInput(3, batch, sizeof(INPUT)) == 3, "Batched injection failed");
        Pump(150);
        Check(downs[1] == 24 && ups[1] == 24 && downs[0] == 23, "Batched click routed incorrectly");
        std::printf("PASS: manual=%d/%d automation=%d/%d; no cross-target clicks, no duplicates; both hold guards, same-seat guard, wheel/buttons, disable, batched input.\n",
            downs[0], ups[0], downs[1], ups[1]);
        result = 0;
    } catch (const std::exception& e) {
        std::printf("FAIL: %s (manual=%d/%d automation=%d/%d)\n", e.what(), downs[0], ups[0], downs[1], ups[1]);
    }
    if (engine) PostMessageW(engine, WM_CLOSE, 0, 0);
    Pump(600);
    if (process.hProcess) {
        if (WaitForSingleObject(process.hProcess, 4000) == WAIT_TIMEOUT) {
            TerminateProcess(process.hProcess, 1);
            WaitForSingleObject(process.hProcess, 4000);
        }
        CloseHandle(process.hProcess); CloseHandle(process.hThread);
    }
    // The test owns every injected button; release them on failures as well.
    INPUT release[]{Button(MOUSEEVENTF_LEFTUP), Button(MOUSEEVENTF_RIGHTUP), Button(MOUSEEVENTF_MIDDLEUP)};
    SendInput(3, release, sizeof(INPUT));
    if (fixture) DestroyWindow(fixture);
    SetCursorPos(before.x, before.y);
    return result;
}
