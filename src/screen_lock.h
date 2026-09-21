// SPDX-License-Identifier: MIT
#pragma once
#include <windows.h>
#include <string>
#include <vector>

namespace om {

struct ScreenInfo {
    std::wstring device;
    RECT bounds{};
    int number = 0;
};

// Keep the device name, since monitor handles and enumeration order can change.
struct ScreenLock {
    std::wstring device;

    const ScreenInfo* Selected(const std::vector<ScreenInfo>& screens) const {
        for (const auto& screen : screens)
            if (screen.device == device) return &screen;
        return nullptr;
    }

    void Toggle(const ScreenInfo& screen) {
        device = device == screen.device ? L"" : screen.device;
    }

    void Refresh(const std::vector<ScreenInfo>& screens) {
        if (!Selected(screens)) device.clear();
    }

    POINT Constrain(POINT point, const std::vector<ScreenInfo>& screens, RECT desktop) const {
        const auto* screen = Selected(screens);
        const RECT bounds = screen ? screen->bounds : desktop;
        if (bounds.right <= bounds.left || bounds.bottom <= bounds.top) return point;
        if (point.x < bounds.left) point.x = bounds.left;
        if (point.y < bounds.top) point.y = bounds.top;
        if (point.x >= bounds.right) point.x = bounds.right - 1;
        if (point.y >= bounds.bottom) point.y = bounds.bottom - 1;
        return point;
    }
};

} // namespace om
