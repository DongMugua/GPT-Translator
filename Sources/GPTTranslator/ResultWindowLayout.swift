import Foundation

/// Screen-independent geometry for the floating result panel. Coordinates use
/// AppKit's global desktop space, where a window's top edge is its maximum Y.
enum ResultWindowLayout {
    static let defaultContentWidth: CGFloat = 500
    static let minimumContentSize = CGSize(width: 320, height: 140)

    /// All inputs and the result are content sizes, excluding AppKit's title bar.
    /// Text never chooses the width. A user's height is a viewport limit; content
    /// beyond that limit stays accessible in the vertical scroll view.
    static func contentSize(
        preferredWidth: CGFloat,
        naturalHeight: CGFloat?,
        userHeightLimit: CGFloat?,
        currentHeight: CGFloat,
        isLoading: Bool,
        availableSize: CGSize
    ) -> CGSize {
        let availableWidth = max(availableSize.width, 1)
        let availableHeight = max(availableSize.height, 1)
        let minimumHeight = min(minimumContentSize.height, availableHeight)
        let width = min(max(preferredWidth, min(minimumContentSize.width, availableWidth)), availableWidth)
        let heightLimit = min(max(userHeightLimit ?? availableHeight, minimumHeight), availableHeight)
        var height = max(naturalHeight ?? currentHeight, minimumHeight)
        // A fresh loading placeholder must not collapse the previous result.
        if isLoading { height = max(height, currentHeight) }
        return CGSize(width: width, height: min(height, heightLimit))
    }

    static func availableContentSize(
        in visibleFrame: CGRect,
        titleBarHeight: CGFloat,
        pinnedTopLeft: CGPoint? = nil
    ) -> CGSize {
        let bounds = visibleFrame.insetBy(dx: 8, dy: 8)
        let frameHeight: CGFloat
        if let pinnedTopLeft {
            // Grow downward from the pin. When space below runs out, scroll
            // instead of moving the pin upward to accommodate more content.
            frameHeight = min(bounds.height, max(minimumContentSize.height + titleBarHeight, pinnedTopLeft.y - bounds.minY))
        } else {
            frameHeight = bounds.height
        }
        return CGSize(width: max(bounds.width, 1), height: max(frameHeight - titleBarHeight, 1))
    }

    static func frame(near pointer: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGRect {
        frame(
            preserving: CGPoint(x: pointer.x + 12, y: pointer.y - 14),
            size: size,
            visibleFrame: visibleFrame
        )
    }

    static func frame(preserving topLeft: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGRect {
        let bounds = visibleFrame.insetBy(dx: 8, dy: 8)
        let fittedSize = CGSize(
            width: min(size.width, max(bounds.width, 1)),
            height: min(size.height, max(bounds.height, 1))
        )
        let x = min(max(topLeft.x, bounds.minX), bounds.maxX - fittedSize.width)
        let top = min(max(topLeft.y, bounds.minY + fittedSize.height), bounds.maxY)
        return CGRect(x: x, y: top - fittedSize.height, width: fittedSize.width, height: fittedSize.height)
    }

    /// Prefer the screen containing most of the panel. If that display has been
    /// disconnected, choose the nearest remaining screen instead of the mouse's.
    static func screenIndex(for windowFrame: CGRect, in screenFrames: [CGRect]) -> Int? {
        guard !screenFrames.isEmpty else { return nil }
        let areas = screenFrames.map { screen -> CGFloat in
            let intersection = screen.intersection(windowFrame)
            return intersection.isNull ? 0 : intersection.width * intersection.height
        }
        if let index = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[index] > 0 {
            return index
        }
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        func distance(to screen: CGRect) -> CGFloat {
            let dx = max(screen.minX - center.x, 0, center.x - screen.maxX)
            let dy = max(screen.minY - center.y, 0, center.y - screen.maxY)
            return dx * dx + dy * dy
        }
        return screenFrames.indices.min { distance(to: screenFrames[$0]) < distance(to: screenFrames[$1]) }
    }
}
