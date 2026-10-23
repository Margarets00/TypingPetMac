import AppKit
import XCTest
@testable import TypingPet

final class TodoBubbleTests: XCTestCase {
    func testScreenEdgesAndSmallScreenContainAllControls() {
        for screen in [CGRect(x: 0, y: 24, width: 1440, height: 876), CGRect(x: -1920, y: -200, width: 1920, height: 1080), CGRect(x: 0, y: 0, width: 300, height: 250)] {
            for x in [screen.minX, screen.midX, screen.maxX - 180] {
                for y in [screen.minY, screen.midY, screen.maxY - 140] {
                    let pet = CGRect(x: x, y: y, width: 180, height: 140)
                    let frame = TodoBubbleGeometry.frame(size: CGSize(width: 340, height: 430), pet: pet, visible: screen)
                    XCTAssertTrue(screen.contains(frame))
                    XCTAssertTrue(screen.contains(TodoBubbleGeometry.entryFrame(pet: pet, visible: screen)))
                }
            }
        }
    }
    func testBottomLeftPetUsesSpaceAbove() {
        let pet = CGRect(x: 12, y: 40, width: 180, height: 140)
        let frame = TodoBubbleGeometry.frame(size: CGSize(width: 340, height: 430), pet: pet, visible: CGRect(x: 0, y: 24, width: 1440, height: 876))
        XCTAssertEqual(frame.minY, pet.maxY + 10)
    }
    func testTailFacesThePetOnEverySide() {
        let screen = CGRect(x: 0, y: 24, width: 1440, height: 876)
        let content = CGSize(width: 320, height: 300)
        let bottomLeft = TodoBubbleGeometry.placement(content: content, tail: 10, pet: CGRect(x: 12, y: 40, width: 180, height: 140), visible: screen, gap: 2)
        XCTAssertEqual(bottomLeft.tailEdge, .bottom)
        XCTAssertEqual(bottomLeft.frame.height, 310)
        XCTAssertLessThan(bottomLeft.tailOffset, 0, "The bubble is clamped right, so the tail moves left toward the pet.")
        let left = TodoBubbleGeometry.placement(content: content, tail: 10, pet: CGRect(x: 12, y: 500, width: 180, height: 140), visible: screen, gap: 2)
        XCTAssertEqual(left.tailEdge, .leading)
        XCTAssertEqual(left.frame.width, 330)
        let right = TodoBubbleGeometry.placement(content: content, tail: 10, pet: CGRect(x: 1250, y: 500, width: 180, height: 140), visible: screen, gap: 2)
        XCTAssertEqual(right.tailEdge, .trailing)
        let topCorner = TodoBubbleGeometry.placement(content: content, tail: 10, pet: CGRect(x: 12, y: 750, width: 180, height: 140), visible: screen, gap: 2)
        XCTAssertEqual(topCorner.tailEdge, .leading, "A corner pet slides the side bubble down instead of overlapping.")
        let narrow = CGRect(x: 0, y: 24, width: 400, height: 876)
        let below = TodoBubbleGeometry.placement(content: content, tail: 10, pet: CGRect(x: 110, y: 750, width: 180, height: 140), visible: narrow, gap: 2)
        XCTAssertEqual(below.tailEdge, .top)
        XCTAssertTrue(narrow.contains(below.frame))
        for placement in [bottomLeft, left, right, topCorner] {
            XCTAssertTrue(screen.contains(placement.frame))
            let limit = (placement.tailEdge == .bottom || placement.tailEdge == .top ? placement.frame.width : placement.frame.height) / 2 - 28
            XCTAssertLessThanOrEqual(abs(placement.tailOffset), limit)
        }
    }
    func testZoomStepsSnapLikeABrowser() {
        XCTAssertEqual(TodoBubbleZoom.larger(than: 1), 1.1)
        XCTAssertEqual(TodoBubbleZoom.smaller(than: 1), 0.9)
        XCTAssertEqual(TodoBubbleZoom.larger(than: 2), 2)
        XCTAssertEqual(TodoBubbleZoom.smaller(than: 0.8), 0.8)
        XCTAssertEqual(TodoBubbleZoom.normalized(1.3), 1.25)
    }
    func testCanvasKeepsBubbleBesidePetAndOnScreen() {
        let screen = CGRect(x: 0, y: 24, width: 1440, height: 876)
        for pet in [CGRect(x: 12, y: 40, width: 220, height: 220), CGRect(x: 1200, y: 640, width: 220, height: 220), CGRect(x: 12, y: 680, width: 220, height: 220)] {
            for content in [CGSize(width: 320, height: 330), CGSize(width: 226, height: 77)] {
                let canvas = TodoBubbleGeometry.canvas(content: content, tail: 10, width: 320, maxHeight: 560, pet: pet, visible: screen)
                XCTAssertTrue(screen.contains(canvas.frame))
                XCTAssertTrue(canvas.frame.insetBy(dx: -0.5, dy: -0.5).contains(canvas.bubble))
                XCTAssertFalse(canvas.bubble.intersects(pet.insetBy(dx: 1, dy: 1)))
                XCTAssertGreaterThanOrEqual(canvas.maxContentHeight + 0.5, content.height)
            }
        }
    }
    @MainActor func testDisplayPreferencesPersistOutsideTheRecord() throws {
        let suite = "TypingPetTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("display-\(UUID()).json")
        var store = TodoStore(url: url, defaults: defaults)
        XCTAssertEqual(store.listStyle, .full)
        store.zoomIn(); store.setBubbleVisibility(.hover); store.setBubbleRestingOpacity(0.4); store.setBubbleHoverOpacity(0.7)
        store.setListStyle(.compact)
        store = TodoStore(url: url, defaults: defaults)
        XCTAssertEqual(store.listStyle, .compact)
        XCTAssertEqual(store.zoom, 1.1)
        XCTAssertEqual(store.bubbleVisibility, .hover)
        XCTAssertEqual(store.bubbleRestingOpacity, 0.4, accuracy: 0.0001)
        XCTAssertEqual(store.bubbleHoverOpacity, 0.7, accuracy: 0.0001)
    }
    @MainActor func testTodoPanelAcceptsFocusAndDoesNotPassClicks() {
        let panel = TodoPanel(contentRect: CGRect(x: 0, y: 0, width: 340, height: 430), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertFalse(panel.ignoresMouseEvents)
    }
}
