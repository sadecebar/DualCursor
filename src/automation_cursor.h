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
        ownPositionKnown_ = false;
    }

    void OwnMove(POINT actual, POINT expected) {
        Reset(actual);
        ownObserved_ = actual;
        expected_ = expected;
        ownPositionKnown_ = true;
    }

    bool Observe(POINT actual) {
        if (!ready_) { Reset(actual); return false; }
        if (actual.x == last_.x && actual.y == last_.y) return false;
        last_ = actual;
        // Own warps can settle late or oscillate by one pixel. Keep their
        // rounding envelope until a genuinely different position is seen.
        // Explicit injected moves bypass this ambiguous polling path.
        const bool own = ownPositionKnown_ &&
            (Near(actual, expected_) || Near(actual, ownObserved_));
        if (!own) ownPositionKnown_ = false;
        return !own;
    }

private:
    static bool Near(POINT a, POINT b) {
        return a.x >= b.x - 1 && a.x <= b.x + 1 &&
               a.y >= b.y - 1 && a.y <= b.y + 1;
    }

    POINT last_{}, ownObserved_{};
    POINT expected_{};
    bool ready_ = false;
    bool ownPositionKnown_ = false;
};

} // namespace om
