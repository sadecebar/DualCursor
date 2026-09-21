// SPDX-License-Identifier: MIT
#pragma once
#include <windows.h>

namespace om {

// UI-thread observer: external cursor warps have no physical device identity.
// Sampling also covers SetCursorPos, which need not produce a mouse-hook event.
class AutomationCursor {
public:
    void Reset(POINT actual) {
        last_ = actual;
        ready_ = true;
        pendingOwn_ = false;
    }

    void OwnMove(POINT actual, POINT expected) {
        Reset(actual);
        expected_ = expected;
        pendingOwn_ = !Near(actual, expected);
    }

    bool Observe(POINT actual) {
        if (!ready_) { Reset(actual); return false; }
        if (actual.x == last_.x && actual.y == last_.y) return false;
        last_ = actual;
        // Absolute SendInput coordinates can round by one pixel. Its queued
        // move may become visible only after the caller recorded OwnMove.
        const bool own = pendingOwn_ && Near(actual, expected_);
        pendingOwn_ = false;
        return !own;
    }

private:
    static bool Near(POINT a, POINT b) {
        return a.x >= b.x - 1 && a.x <= b.x + 1 &&
               a.y >= b.y - 1 && a.y <= b.y + 1;
    }

    POINT last_{};
    POINT expected_{};
    bool ready_ = false;
    bool pendingOwn_ = false;
};

} // namespace om
