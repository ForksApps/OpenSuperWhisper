import XCTest
import ApplicationServices
@testable import OpenSuperWhisper

/// Unit tests for the pure editability decision used by the "notify when no
/// paste target" feature. The AX I/O itself is environment-dependent and is
/// verified manually; this covers the decision logic, which is biased toward
/// `true` so the app never warns spuriously.
final class PasteTargetDetectionTests: XCTestCase {

    func testNoFocusedElementIsNotEditable() {
        XCTAssertFalse(
            FocusUtils.classifyEditability(hasFocusedElement: false, valueIsSettable: false, role: nil),
            "Nothing focused → paste has no target")
    }

    func testSettableValueIsEditable() {
        // A settable value wins even over a non-editable-looking role.
        XCTAssertTrue(
            FocusUtils.classifyEditability(hasFocusedElement: true, valueIsSettable: true,
                                           role: kAXButtonRole as String))
    }

    func testTextFieldRoleIsEditable() {
        XCTAssertTrue(
            FocusUtils.classifyEditability(hasFocusedElement: true, valueIsSettable: false,
                                           role: kAXTextFieldRole as String))
    }

    func testTextAreaRoleIsEditable() {
        XCTAssertTrue(
            FocusUtils.classifyEditability(hasFocusedElement: true, valueIsSettable: false,
                                           role: kAXTextAreaRole as String))
    }

    func testButtonRoleIsNotEditable() {
        XCTAssertFalse(
            FocusUtils.classifyEditability(hasFocusedElement: true, valueIsSettable: false,
                                           role: kAXButtonRole as String))
    }

    func testStaticTextRoleIsNotEditable() {
        XCTAssertFalse(
            FocusUtils.classifyEditability(hasFocusedElement: true, valueIsSettable: false,
                                           role: kAXStaticTextRole as String))
    }

    func testUnknownRoleDefaultsToEditable() {
        // Bias toward not warning when we can't be sure.
        XCTAssertTrue(
            FocusUtils.classifyEditability(hasFocusedElement: true, valueIsSettable: false,
                                           role: "AXSomeUnknownRole"))
    }

    func testNilRoleWithFocusDefaultsToEditable() {
        XCTAssertTrue(
            FocusUtils.classifyEditability(hasFocusedElement: true, valueIsSettable: false, role: nil))
    }

    // MARK: - A question that failed is not an answer

    /// Reported by a user: dictation stopped inserting and only left the text on the clipboard,
    /// and stayed that way until Settings was opened and closed again. The accessibility query
    /// had failed, and a failure was being read as "there is no text field here".
    func testOnlyTheSystemSayingNothingIsFocusedCountsAsAbsence() {
        XCTAssertTrue(FocusUtils.reportsNothingFocused(.noValue))
        XCTAssertTrue(FocusUtils.reportsNothingFocused(.attributeUnsupported))
    }

    /// What a target that did not reply in time returns, and what the system-wide element
    /// returns in cases where asking the application directly works.
    func testATimedOutQueryIsNotAbsence() {
        XCTAssertFalse(FocusUtils.reportsNothingFocused(.cannotComplete))
    }

    func testOtherFailuresAreNotAbsence() {
        for error in [AXError.failure, .invalidUIElement, .notImplemented,
                      .apiDisabled, .invalidUIElementObserver] {
            XCTAssertFalse(FocusUtils.reportsNothingFocused(error),
                           "\(error) was treated as proof that no text field is focused")
        }
    }

    /// The fix relies on `nil` not tripping the caller's `== false` test, which is how typing
    /// proceeds when we cannot tell. Pinned here because the whole repair rests on it.
    func testUndeterminableDoesNotCountAsNoTarget() {
        let undeterminable: Bool? = nil
        let definitelyNoTarget: Bool? = false

        XCTAssertFalse(undeterminable == false)
        XCTAssertTrue(definitelyNoTarget == false)
    }
}
