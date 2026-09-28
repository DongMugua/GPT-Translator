import Foundation

/// Drag and multi-click selections need the same copy fallback in PDF readers
/// that do not expose AXSelectedText. Ordinary clicks remain AX-only so opening
/// a menu or clicking a button never synthesizes Command-C.
struct SelectionReadTrigger {
    let allowsClipboardFallback: Bool

    init(didDrag: Bool, clickCount: Int) {
        allowsClipboardFallback = didDrag || clickCount >= 2
    }

    func delay(doubleClickInterval: TimeInterval) -> TimeInterval {
        // Do not read stale text between the two clicks. The next mouse-down
        // cancels this task; a completed selection only needs a short settle.
        allowsClipboardFallback ? 0.18 : max(0.18, doubleClickInterval)
    }
}
