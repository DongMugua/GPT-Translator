import Foundation
import Testing
@testable import GPTTranslator

struct ResultWindowLayoutTests {
    private let desktop = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test func testPinnedTopLeftSurvivesDifferentTranslationSizes() {
        let pinned = CGPoint(x: 320, y: 760)
        for size in [CGSize(width: 390, height: 180), CGSize(width: 560, height: 580), CGSize(width: 410, height: 230)] {
            let frame = ResultWindowLayout.frame(preserving: pinned, size: size, visibleFrame: desktop)
            #expect(frame.minX == pinned.x)
            #expect(frame.maxY == pinned.y)
        }
    }

    @Test func testDraggedAnchorIsUsedForSubsequentTranslations() {
        let draggedTopLeft = CGPoint(x: -1140, y: 620)
        let leftDisplay = CGRect(x: -1280, y: 0, width: 1280, height: 800)
        let frame = ResultWindowLayout.frame(
            preserving: draggedTopLeft, size: CGSize(width: 420, height: 350), visibleFrame: leftDisplay
        )
        #expect(frame.minX == draggedTopLeft.x)
        #expect(frame.maxY == draggedTopLeft.y)
    }

    @Test func testEdgeClampingDoesNotOverwritePreferredPinnedPosition() {
        let pinned = CGPoint(x: 980, y: 350)
        let large = ResultWindowLayout.frame(preserving: pinned, size: CGSize(width: 560, height: 580), visibleFrame: desktop)
        #expect(large.maxX == desktop.maxX - 8)
        #expect(large.minY == desktop.minY + 8)
        let small = ResultWindowLayout.frame(preserving: pinned, size: CGSize(width: 390, height: 180), visibleFrame: desktop)
        #expect(small.minX == pinned.x)
        #expect(small.maxY == pinned.y)
    }

    @Test func testOversizedPanelRemainsInsideVisibleScreen() {
        let visible = CGRect(x: 1440, y: -600, width: 800, height: 580)
        let frame = ResultWindowLayout.frame(
            preserving: CGPoint(x: 3000, y: 1500), size: CGSize(width: 1200, height: 900), visibleFrame: visible
        )
        #expect(frame == visible.insetBy(dx: 8, dy: 8))
    }

    @Test func testPinnedPanelUsesItsDisplayRegardlessOfMouseDisplay() {
        let left = CGRect(x: -1280, y: 0, width: 1280, height: 800)
        let panel = CGRect(x: -1150, y: 230, width: 500, height: 400)
        #expect(ResultWindowLayout.screenIndex(for: panel, in: [desktop, left]) == 1)
        // A straddling panel belongs to the display with more of its area.
        let straddling = CGRect(x: -100, y: 200, width: 500, height: 400)
        #expect(ResultWindowLayout.screenIndex(for: straddling, in: [desktop, left]) == 0)
    }

    @Test func testDisconnectedDisplayUsesNearestRemainingScreen() {
        let above = CGRect(x: 0, y: 900, width: 1440, height: 900)
        let detachedPanel = CGRect(x: 1800, y: 1100, width: 420, height: 300)
        #expect(ResultWindowLayout.screenIndex(for: detachedPanel, in: [desktop, above]) == 1)
        #expect(ResultWindowLayout.screenIndex(for: detachedPanel, in: []) == nil)
    }

    @Test func testUnpinnedPlacementFollowsPointerAndClampsAtEdges() {
        let size = CGSize(width: 420, height: 300)
        let first = ResultWindowLayout.frame(near: CGPoint(x: 100, y: 800), size: size, visibleFrame: desktop)
        let second = ResultWindowLayout.frame(near: CGPoint(x: 500, y: 700), size: size, visibleFrame: desktop)
        #expect(first.minX == 112)
        #expect(first.maxY == 786)
        #expect(second.minX == 512)
        #expect(second.maxY == 686)
        let corner = ResultWindowLayout.frame(near: CGPoint(x: 1440, y: 0), size: size, visibleFrame: desktop)
        #expect(corner.maxX == 1432)
        #expect(corner.minY == 8)
    }
}
