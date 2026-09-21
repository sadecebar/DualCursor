// SPDX-License-Identifier: MIT
#pragma once
#include "automation_cursor.h"
#include <array>
#include <cstdint>
#include <mutex>

namespace om {

struct AutomationClick {
    int seat = -1;
    POINT point{};
    USHORT flags = 0, data = 0;
};

// The hook only records coordinates and queues buttons. Never hold this lock
// across a cursor API, SendInput, focus change, or synchronous window message.
class AutomationInput {
public:
    void Configure(int seat, POINT target, POINT actual) {
        std::lock_guard<std::mutex> lock(mutex_);
        seat_ = seat;
        target_ = target;
        cursor_.Reset(actual);
        head_ = count_ = 0;
        fault_ = false;
        ownMoving_ = false;
        ++revision_;
    }

    void BeginOwnMove(POINT expected) {
        std::lock_guard<std::mutex> lock(mutex_);
        ownMoving_ = true;
        expected_ = expected;
    }

    void EndOwnMove(POINT actual, POINT expected) {
        std::lock_guard<std::mutex> lock(mutex_);
        cursor_.OwnMove(actual, expected);
        ownMoving_ = false;
    }

    void Poll(POINT actual) {
        std::lock_guard<std::mutex> lock(mutex_);
        Observe(actual, false);
    }

    bool Target(POINT& point, uint64_t& seen) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (seat_ < 0 || seen == revision_) return false;
        point = target_;
        seen = revision_;
        return true;
    }

    // Returns true when routing is enabled, even on overflow.
    // Explicit injected moves are authoritative, unlike a click's system
    // position, which might still be the position of the other physical mouse.
    bool Capture(POINT point, bool move, USHORT flags, USHORT data, bool& wake) {
        std::lock_guard<std::mutex> lock(mutex_);
        wake = false;
        if (seat_ < 0) return false;
        Observe(point, move);
        if (!flags) return true;
        if (count_ == queue_.size()) { fault_ = true; return true; }
        wake = count_ == 0;
        queue_[(head_ + count_) % queue_.size()] = {seat_, target_, flags, data};
        ++count_;
        return true;
    }

    bool Take(AutomationClick& click, bool& more) {
        std::lock_guard<std::mutex> lock(mutex_);
        more = false;
        if (!count_) return false;
        click = queue_[head_];
        head_ = (head_ + 1) % queue_.size();
        --count_;
        more = count_ != 0;
        return true;
    }

    bool Faulted() {
        std::lock_guard<std::mutex> lock(mutex_);
        return fault_;
    }

private:
    void Observe(POINT point, bool explicitMove) {
        if (seat_ < 0) { cursor_.Reset(point); return; }
        if (!explicitMove && ownMoving_ &&
            point.x >= expected_.x - 1 && point.x <= expected_.x + 1 &&
            point.y >= expected_.y - 1 && point.y <= expected_.y + 1) return;
        if (explicitMove || cursor_.Observe(point)) {
            cursor_.Reset(point);
            target_ = point;
            ++revision_;
        }
    }

    std::mutex mutex_;
    AutomationCursor cursor_;
    std::array<AutomationClick, 128> queue_{};
    size_t head_ = 0, count_ = 0;
    int seat_ = -1;
    POINT target_{}, expected_{};
    uint64_t revision_ = 0;
    bool fault_ = false, ownMoving_ = false;
};

// RI_MOUSE button DOWN bits, with the corresponding UP one bit to the left.
// Keep automation's press/release pairs distinct even on the same seat.
class AutomationButtons {
public:
    USHORT Filter(USHORT flags, bool physicalHeld) {
        USHORT result = 0;
        for (USHORT down = 1; down <= RI_MOUSE_BUTTON_5_DOWN; down <<= 2) {
            const USHORT up = static_cast<USHORT>(down << 1);
            if (flags & down) {
                if (physicalHeld) blocked_ |= down;
                else if (!(blocked_ & down) && !(held_ & down)) {
                    held_ |= down;
                    result |= down;
                }
            }
            if (flags & up) {
                if (held_ & down) result |= up;
                held_ &= ~down;
                blocked_ &= ~down;
            }
        }
        if (!physicalHeld) result |= flags & (RI_MOUSE_WHEEL | RI_MOUSE_HWHEEL);
        return result;
    }
    bool Held() const { return held_ != 0; }
    USHORT Cancel() {
        const USHORT up = static_cast<USHORT>(held_ << 1);
        held_ = blocked_ = 0;
        return up;
    }
private:
    USHORT held_ = 0, blocked_ = 0;
};

} // namespace om
