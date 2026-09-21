#include "../src/automation_cursor.h"
#include <cassert>
#include <cstdio>

int main() {
    om::AutomationCursor cursor;
    assert(!cursor.Observe({100, 100}));
    assert(!cursor.Observe({100, 100}));
    assert(cursor.Observe({150, 120}));
    assert(!cursor.Observe({150, 120}));

    // Physical-seat warps must not move the automation seat.
    cursor.OwnMove({300, 200}, {300, 200});
    assert(!cursor.Observe({300, 200}));
    assert(cursor.Observe({150, 120}));

    // Once our warp has completed, even a one-pixel external move is real.
    cursor.OwnMove({300, 200}, {300, 200});
    assert(cursor.Observe({301, 200}));

    // A queued, tagged SendInput move can arrive later and be rounded.
    cursor.OwnMove({150, 120}, {400, 300});
    assert(!cursor.Observe({150, 120}));
    assert(!cursor.Observe({399, 301}));
    assert(cursor.Observe({410, 300}));

    cursor.OwnMove({410, 300}, {500, 300});
    assert(cursor.Observe({-1600, -200}));
    assert(cursor.Observe({500, 300}));
    cursor.Reset({-100, -100});
    assert(!cursor.Observe({-100, -100}));
    assert(cursor.Observe({-101, -100}));
    std::puts("PASS: automation movement, own warps, delayed input, reset, negative coordinates.");
}
