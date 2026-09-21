#include "../src/automation_input.h"
#include <cassert>
#include <cstdio>

int main() {
    om::AutomationInput input;
    const POINT a{200, 300}, b{-800, 250}, c{-900, 400};
    input.Configure(1, b, a);
    bool wake = false, more = false;
    om::AutomationClick click;

    input.BeginOwnMove(a);
    input.EndOwnMove(a, a);
    assert(input.Capture(a, false, RI_MOUSE_LEFT_BUTTON_DOWN, 0, wake) && wake);
    assert(input.Take(click, more));
    assert(click.seat == 1 && click.point.x == b.x && click.point.y == b.y);

    // A direct warp followed immediately by a click must not wait for polling.
    assert(input.Capture(c, false, RI_MOUSE_LEFT_BUTTON_UP, 0, wake));
    assert(input.Take(click, more) && click.point.x == c.x && click.point.y == c.y);
    // Explicit moves can deliberately return to the same coordinate as ours.
    input.Capture(a, true, 0, 0, wake);
    input.Capture(a, false, RI_MOUSE_RIGHT_BUTTON_DOWN, 0, wake);
    input.BeginOwnMove(b);
    input.EndOwnMove(b, b);
    input.Capture(b, false, RI_MOUSE_RIGHT_BUTTON_UP, 0, wake);
    assert(input.Take(click, more) && more && click.point.x == a.x);
    assert(input.Take(click, more) && !more && click.point.x == a.x);

    input.Configure(-1, b, a);
    assert(!input.Capture(c, false, RI_MOUSE_LEFT_BUTTON_DOWN, 0, wake));
    assert(!input.Take(click, more));
    input.Configure(1, b, a);
    for (int i = 0; i < 129; ++i) input.Capture(a, false, RI_MOUSE_LEFT_BUTTON_DOWN, 0, wake);
    assert(input.Faulted());
    input.Configure(0, a, a);
    assert(!input.Faulted() && !input.Take(click, more));

    om::AutomationButtons buttons;
    assert(!buttons.Filter(RI_MOUSE_LEFT_BUTTON_DOWN, true));
    assert(!buttons.Filter(RI_MOUSE_LEFT_BUTTON_UP, false));
    assert(!buttons.Held());
    for (USHORT down = 1; down <= RI_MOUSE_BUTTON_5_DOWN; down <<= 2) {
        assert(buttons.Filter(down, false) == down);
        assert(buttons.Held());
        assert(buttons.Filter(down, false) == 0);
        assert(buttons.Filter(static_cast<USHORT>(down << 1), false) == (down << 1));
        assert(!buttons.Held());
    }
    assert(!buttons.Filter(RI_MOUSE_WHEEL, true));
    assert(buttons.Filter(RI_MOUSE_HWHEEL, false) == RI_MOUSE_HWHEEL);
    buttons.Filter(RI_MOUSE_LEFT_BUTTON_DOWN | RI_MOUSE_RIGHT_BUTTON_DOWN, false);
    assert(buttons.Cancel() == (RI_MOUSE_LEFT_BUTTON_UP | RI_MOUSE_RIGHT_BUTTON_UP));
    assert(!buttons.Filter(RI_MOUSE_LEFT_BUTTON_UP, false));
    std::puts("PASS: click coordinates, own warps, direct warps, ordered queue, disabled mode, overflow, all button pairs, conflict filtering, cancellation.");
}
