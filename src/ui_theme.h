// SPDX-License-Identifier: MIT
#pragma once
#include <windows.h>
#include <commctrl.h>
#include <algorithm>
#include <new>
#pragma comment(lib, "comctl32.lib")
#pragma comment(linker, "\"/manifestdependency:type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")

namespace om::ui {

inline UINT dpi = 96;
inline HFONT body = nullptr, small = nullptr, strong = nullptr, title = nullptr, icons = nullptr;
inline HFONT mouseIcon = nullptr, statusIcon = nullptr;
inline HBRUSH surfaceBrush = nullptr;
inline COLORREF surface, text, muted, line, border, hover;
inline bool highContrast = false, motion = true;
inline int Px(int value) { return MulDiv(value, dpi, 96); }

inline COLORREF Mix(COLORREF a, COLORREF b, float amount) {
    auto mix = [amount](int x, int y) { return static_cast<BYTE>(x + (y - x) * amount); };
    return RGB(mix(GetRValue(a), GetRValue(b)), mix(GetGValue(a), GetGValue(b)), mix(GetBValue(a), GetBValue(b)));
}

inline void DestroyFonts() {
    for (HFONT font : {body, small, strong, title, icons, mouseIcon, statusIcon}) if (font) DeleteObject(font);
    body = small = strong = title = icons = mouseIcon = statusIcon = nullptr;
}

inline void Refresh(UINT newDpi) {
    dpi = newDpi ? newDpi : 96;
    DestroyFonts();
    auto font = [](int size, int weight, const wchar_t* family) {
        return CreateFontW(-Px(size), 0, 0, 0, weight, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
            CLEARTYPE_QUALITY, DEFAULT_PITCH, family);
    };
    body = font(14, FW_NORMAL, L"Segoe UI");
    small = font(12, FW_NORMAL, L"Segoe UI");
    strong = font(16, FW_SEMIBOLD, L"Segoe UI");
    title = font(23, FW_SEMIBOLD, L"Segoe UI");
    icons = font(19, FW_NORMAL, L"Segoe MDL2 Assets");
    mouseIcon = font(30, FW_NORMAL, L"Segoe MDL2 Assets");
    statusIcon = font(14, FW_NORMAL, L"Segoe MDL2 Assets");
    HIGHCONTRASTW hc{sizeof(hc)};
    highContrast = SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(hc), &hc, 0) && (hc.dwFlags & HCF_HIGHCONTRASTON);
    BOOL animate = TRUE;
    SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &animate, 0);
    motion = animate && !highContrast;
    surface = highContrast ? GetSysColor(COLOR_WINDOW) : RGB(247, 248, 250);
    text = highContrast ? GetSysColor(COLOR_WINDOWTEXT) : RGB(31, 38, 48);
    muted = highContrast ? text : RGB(92, 103, 119);
    line = highContrast ? text : RGB(221, 225, 231);
    border = highContrast ? text : RGB(139, 150, 166);
    hover = highContrast ? GetSysColor(COLOR_BTNFACE) : RGB(233, 237, 243);
    if (surfaceBrush) DeleteObject(surfaceBrush);
    surfaceBrush = CreateSolidBrush(surface);
}

inline void Shutdown() {
    DestroyFonts();
    if (surfaceBrush) DeleteObject(surfaceBrush);
    surfaceBrush = nullptr;
}

class Buffer {
public:
    Buffer(HDC target, RECT rect) : target_(target), rect_(rect) {
        dc = CreateCompatibleDC(target);
        bitmap_ = CreateCompatibleBitmap(target, std::max(1L, rect.right - rect.left), std::max(1L, rect.bottom - rect.top));
        old_ = SelectObject(dc, bitmap_);
        SetWindowOrgEx(dc, rect.left, rect.top, nullptr);
    }
    ~Buffer() {
        BitBlt(target_, rect_.left, rect_.top, rect_.right - rect_.left,
            rect_.bottom - rect_.top, dc, rect_.left, rect_.top, SRCCOPY);
        SelectObject(dc, old_);
        DeleteObject(bitmap_);
        DeleteDC(dc);
    }
    HDC dc;
private:
    HDC target_;
    RECT rect_;
    HBITMAP bitmap_;
    HGDIOBJ old_;
};

inline void Fill(HDC dc, RECT rect, COLORREF color) {
    SetDCBrushColor(dc, color);
    FillRect(dc, &rect, reinterpret_cast<HBRUSH>(GetStockObject(DC_BRUSH)));
}

inline void Label(HDC dc, const wchar_t* value, RECT rect, HFONT font, COLORREF color,
                  UINT flags = DT_LEFT | DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS) {
    const int saved = SaveDC(dc);
    SelectObject(dc, font);
    SetBkMode(dc, TRANSPARENT);
    SetTextColor(dc, color);
    DrawTextW(dc, value, -1, &rect, flags | DT_NOPREFIX);
    RestoreDC(dc, saved);
}

inline void Rule(HDC dc, int left, int right, int y) { Fill(dc, {left, y, right, y + 1}, line); }

struct ButtonState {
    bool hot = false;
    float from = 0, value = 0;
    ULONGLONG started = 0;
    COLORREF accent = RGB(56, 101, 175);
};

inline LRESULT CALLBACK ButtonProc(HWND, UINT, WPARAM, LPARAM, UINT_PTR, DWORD_PTR);

inline ButtonState* State(HWND hwnd) {
    DWORD_PTR data = 0;
    return GetWindowSubclass(hwnd, ButtonProc, 1, &data) ? reinterpret_cast<ButtonState*>(data) : nullptr;
}

inline void DrawButton(HDC dc, RECT rect, HWND hwnd, const wchar_t* label,
                       bool selected, COLORREF accent, const wchar_t* glyph = nullptr) {
    const auto* state = State(hwnd);
    const float hot = state ? state->value : 0;
    const bool pressed = (SendMessageW(hwnd, BM_GETSTATE, 0, 0) & BST_PUSHED) != 0;
    COLORREF bg = Mix(surface, hover, hot);
    COLORREF fg = text, stroke = border;
    if (selected) {
        bg = highContrast ? GetSysColor(COLOR_HIGHLIGHT) : Mix(surface, accent, .10f + hot * .05f);
        fg = highContrast ? GetSysColor(COLOR_HIGHLIGHTTEXT) : Mix(accent, text, .30f);
        stroke = highContrast ? fg : Mix(accent, text, .10f);
    }
    if (pressed) bg = Mix(bg, text, .07f);
    if (!IsWindowEnabled(hwnd)) fg = muted;
    const int saved = SaveDC(dc);
    Fill(dc, rect, surface);
    SetDCBrushColor(dc, bg);
    SetDCPenColor(dc, stroke);
    SelectObject(dc, GetStockObject(DC_BRUSH));
    SelectObject(dc, GetStockObject(DC_PEN));
    RoundRect(dc, rect.left, rect.top, rect.right, rect.bottom, Px(10), Px(10));
    RECT copy = rect;
    if (glyph) {
        RECT icon{rect.left + Px(10), rect.top, rect.left + Px(31), rect.bottom};
        Label(dc, glyph, icon, icons, fg, DT_CENTER | DT_SINGLELINE | DT_VCENTER);
        copy.left += Px(34);
        copy.right -= Px(6);
    }
    Label(dc, label, copy, body, fg, DT_CENTER | DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);
    if (GetFocus() == hwnd && !(SendMessageW(hwnd, WM_QUERYUISTATE, 0, 0) & UISF_HIDEFOCUS)) {
        RECT focus = rect;
        InflateRect(&focus, -Px(3), -Px(3));
        SetTextColor(dc, text);
        SetBkColor(dc, bg);
        DrawFocusRect(dc, &focus);
    }
    RestoreDC(dc, saved);
}

inline LRESULT CALLBACK ButtonProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp, UINT_PTR id, DWORD_PTR data) {
    auto* state = reinterpret_cast<ButtonState*>(data);
    auto setHot = [&](bool hot) {
        if (state->hot == hot) return;
        state->hot = hot;
        state->from = state->value;
        state->started = GetTickCount64();
        if (motion) SetTimer(hwnd, 7, 16, nullptr);
        else { state->value = hot ? 1.f : 0.f; InvalidateRect(hwnd, nullptr, FALSE); }
    };
    switch (msg) {
    case WM_MOUSEMOVE: {
        setHot(true);
        TRACKMOUSEEVENT track{sizeof(track), TME_LEAVE, hwnd, 0};
        TrackMouseEvent(&track);
        break;
    }
    case WM_MOUSELEAVE: setHot(false); break;
    case WM_TIMER:
        if (wp == 7) {
            const float t = std::min(1.f, static_cast<float>(GetTickCount64() - state->started) / 160.f);
            const float remain = 1.f - t;
            const float ease = 1.f - remain * remain * remain * remain;
            state->value = state->from + ((state->hot ? 1.f : 0.f) - state->from) * ease;
            InvalidateRect(hwnd, nullptr, FALSE);
            if (t >= 1.f) KillTimer(hwnd, 7);
            return 0;
        }
        break;
    case WM_ERASEBKGND: return 1;
    case WM_PAINT:
    case WM_PRINTCLIENT:
        if ((GetWindowLongPtrW(hwnd, GWL_STYLE) & BS_TYPEMASK) != BS_OWNERDRAW) {
            PAINTSTRUCT paint{};
            HDC target = msg == WM_PAINT ? BeginPaint(hwnd, &paint) : reinterpret_cast<HDC>(wp);
            RECT rect{};
            GetClientRect(hwnd, &rect);
            {
                Buffer buffer(target, rect);
                wchar_t label[128]{};
                GetWindowTextW(hwnd, label, 128);
                const bool selected = SendMessageW(hwnd, BM_GETCHECK, 0, 0) == BST_CHECKED;
                DrawButton(buffer.dc, rect, hwnd, label, selected, state->accent);
            }
            if (msg == WM_PAINT) EndPaint(hwnd, &paint);
            return 0;
        }
        break;
    case WM_NCDESTROY:
        KillTimer(hwnd, 7);
        RemoveWindowSubclass(hwnd, ButtonProc, id);
        delete state;
        return DefSubclassProc(hwnd, msg, wp, lp);
    }
    const LRESULT result = DefSubclassProc(hwnd, msg, wp, lp);
    if (msg == BM_SETCHECK || msg == BM_SETSTATE || msg == WM_SETFOCUS || msg == WM_KILLFOCUS || msg == WM_ENABLE)
        InvalidateRect(hwnd, nullptr, FALSE);
    return result;
}

inline bool StyleButton(HWND hwnd, COLORREF accent = RGB(56, 101, 175)) {
    auto* state = new(std::nothrow) ButtonState;
    if (!state) return false;
    state->accent = accent;
    if (!SetWindowSubclass(hwnd, ButtonProc, 1, reinterpret_cast<DWORD_PTR>(state))) { delete state; return false; }
    SendMessageW(hwnd, WM_SETFONT, reinterpret_cast<WPARAM>(body), FALSE);
    return true;
}

} // namespace om::ui
