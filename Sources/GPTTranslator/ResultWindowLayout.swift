import Foundation

/// Screen-independent geometry for the floating result panel. Coordinates use
/// AppKit's global desktop space, where a window's top edge is its maximum Y.
enum ResultWindowLayout {
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
