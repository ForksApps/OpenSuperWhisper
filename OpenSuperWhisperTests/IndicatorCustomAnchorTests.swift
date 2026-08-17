import XCTest

@testable import OpenSuperWhisper

/// Where the bubble was dropped has to survive a restart, so it goes through UserDefaults as
/// text. These cover that round trip and the states around it, which is the part that can be
/// wrong without anyone noticing until the bubble reappears in the wrong place.
final class IndicatorCustomAnchorTests: XCTestCase {

    private var original: CGPoint?

    override func setUp() {
        super.setUp()
        original = AppPreferences.shared.indicatorCustomAnchor
    }

    override func tearDown() {
        AppPreferences.shared.indicatorCustomAnchor = original
        super.tearDown()
    }

    func testAnchorSurvivesTheRoundTrip() {
        AppPreferences.shared.indicatorCustomAnchor = CGPoint(x: 812.5, y: 431)

        let stored = AppPreferences.shared.indicatorCustomAnchor
        XCTAssertEqual(stored?.x ?? 0, 812.5, accuracy: 0.001)
        XCTAssertEqual(stored?.y ?? 0, 431, accuracy: 0.001)
    }

    /// A second monitor puts the bubble at a negative x, and a dropped bubble there must come back
    /// there rather than jumping to the main screen.
    func testNegativeCoordinatesSurvive() {
        AppPreferences.shared.indicatorCustomAnchor = CGPoint(x: -1440.25, y: -300)

        let stored = AppPreferences.shared.indicatorCustomAnchor
        XCTAssertEqual(stored?.x ?? 0, -1440.25, accuracy: 0.001)
        XCTAssertEqual(stored?.y ?? 0, -300, accuracy: 0.001)
    }

    func testNeverDraggedReadsAsNothing() {
        AppPreferences.shared.indicatorCustomAnchor = nil

        XCTAssertNil(AppPreferences.shared.indicatorCustomAnchor)
    }

    /// Zero is a real screen point, so it must not be mistaken for "no anchor stored".
    func testTheOriginIsAnAnchorLikeAnyOther() {
        AppPreferences.shared.indicatorCustomAnchor = .zero

        XCTAssertNotNil(AppPreferences.shared.indicatorCustomAnchor)
        XCTAssertEqual(AppPreferences.shared.indicatorCustomAnchor?.x ?? 1, 0, accuracy: 0.001)
    }

    /// The bubble is click-through unless something needs it not to be. Dragging needs it not to
    /// be, so this mode is the one place the trade is accepted, and the presets must not inherit it.
    func testOnlyTheDraggableModeGivesUpClickThrough() {
        let needs = IndicatorWindowManager.needsMouseEvents

        XCTAssertTrue(needs("custom", false, false))
        XCTAssertFalse(needs("cursor", false, false))
        XCTAssertFalse(needs("notch", false, false))
        XCTAssertFalse(needs("bottom", false, false))
    }

    func testOnBubbleButtonsStillNeedClicksOnAnyPosition() {
        let needs = IndicatorWindowManager.needsMouseEvents

        XCTAssertTrue(needs("cursor", true, false))
        XCTAssertTrue(needs("notch", false, true))
    }
}
