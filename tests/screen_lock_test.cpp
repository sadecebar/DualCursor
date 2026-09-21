// SPDX-License-Identifier: MIT
#include "../src/screen_lock.h"
#include <cassert>
#include <cstdio>

static void ExpectPoint(POINT actual, LONG x, LONG y) {
    assert(actual.x == x && actual.y == y);
}

int main() {
    using namespace om;
    std::vector<ScreenInfo> screens = {
        {L"DISPLAY1", {0, 0, 1920, 1080}, 1},
        {L"DISPLAY2", {-1280, -200, 0, 824}, 2},
        {L"DISPLAY3", {0, -1080, 1920, 0}, 3}
    };
    const RECT desktop{-1280, -1080, 1920, 1080};
    ScreenLock first, second;
    ExpectPoint(first.Constrain({-300, -500}, screens, desktop), -300, -500);

    first.Toggle(screens[0]);
    ExpectPoint(first.Constrain({-400, -300}, screens, desktop), 0, 0);
    ExpectPoint(first.Constrain({4000, 5000}, screens, desktop), 1919, 1079);
    ExpectPoint(first.Constrain({650, 450}, screens, desktop), 650, 450);
    // The last pixel belongs to this display; right/bottom are exclusive.
    ExpectPoint(first.Constrain({1920, 1080}, screens, desktop), 1919, 1079);

    second.Toggle(screens[1]);
    ExpectPoint(second.Constrain({50, 1000}, screens, desktop), -1, 823);
    ExpectPoint(second.Constrain({-2000, -700}, screens, desktop), -1280, -200);
    ExpectPoint(first.Constrain({-800, -100}, screens, desktop), 0, 0);

    first.Toggle(screens[2]);
    ExpectPoint(first.Constrain({100, 100}, screens, desktop), 100, -1);
    first.Toggle(screens[2]);
    assert(first.device.empty());
    ExpectPoint(first.Constrain({100, 100}, screens, desktop), 100, 100);

    // Moving/reordering displays must retain a lock by device identity.
    screens = {screens[2], screens[1], screens[0]};
    screens[1].bounds = {-1600, 0, 0, 900};
    second.Refresh(screens);
    ExpectPoint(second.Constrain({-1500, -100}, screens, desktop), -1500, 0);
    assert(second.Selected(screens)->number == 2);

    // Disconnect releases the lock; reconnect does not silently lock again.
    screens.erase(screens.begin() + 1);
    second.Refresh(screens);
    assert(second.device.empty());
    screens.push_back({L"DISPLAY2", {-1600, 0, 0, 900}, 2});
    second.Refresh(screens);
    ExpectPoint(second.Constrain({100, 100}, screens, desktop), 100, 100);
    screens.clear();
    first.Refresh(screens);
    ExpectPoint(first.Constrain({9999, -9999}, screens, desktop), 1919, -1080);
    std::puts("Screen lock tests passed.");
}
