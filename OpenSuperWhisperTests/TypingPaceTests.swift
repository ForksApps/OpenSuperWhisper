import XCTest

@testable import OpenSuperWhisper

/// Pacing for synthetic typing.
///
/// Unpaced, the chunks of a long dictation are posted inside a millisecond, and an app that
/// re-renders its input area per keystroke loses track: reported as existing text duplicated two
/// or three times with the new speech wedged inside (#85). Typing also has to stay synchronous,
/// because the caller presses Return once it returns, so the pause has a ceiling on what it may
/// cost in total.
final class TypingPaceTests: XCTestCase {

    private func pause(_ count: Int) -> useconds_t {
        TextInserter.chunkPause(forChunkCount: count)
    }

    func testASingleChunkWaitsForNothing() {
        XCTAssertEqual(pause(1), 0, "there is no next chunk to pace against")
        XCTAssertEqual(pause(0), 0)
    }

    func testOrdinaryDictationGetsTheFullPause() {
        // 400 characters is 20 chunks: 19 gaps at 2ms, well inside the ceiling.
        XCTAssertEqual(pause(20), TextInserter.chunkPauseMicroseconds)
    }

    /// The whole point: a gap exists between chunks.
    func testTwoChunksArePaced() {
        XCTAssertGreaterThan(pause(2), 0)
    }

    /// Typing blocks the main thread, so an enormous dictation must not freeze the app. It
    /// trades pacing for responsiveness rather than the other way round.
    func testTotalPauseIsCapped() {
        for count in [10, 100, 1_000, 10_000] {
            let total = useconds_t(count - 1) * pause(count)
            XCTAssertLessThanOrEqual(total, TextInserter.maxTotalPauseMicroseconds,
                                     "\(count) chunks would stall the main thread for \(total)µs")
        }
    }

    /// The cap must not be reached by ordinary use: a 2000-character dictation should still be
    /// fully paced.
    func testTheCapDoesNotBiteOnRealisticDictations() {
        let chunks = TextInserter.chunks(of: String(repeating: "a", count: 2_000)).count
        XCTAssertEqual(pause(chunks), TextInserter.chunkPauseMicroseconds)
    }

    /// More chunks never means a longer wait per gap, or the cap could be jumped.
    func testPauseNeverGrowsWithChunkCount() {
        var previous = TextInserter.chunkPauseMicroseconds
        for count in stride(from: 2, through: 2_000, by: 37) {
            let current = pause(count)
            XCTAssertLessThanOrEqual(current, previous)
            previous = current
        }
    }

    // MARK: - Chunking itself, which the pause is derived from

    /// 20 UTF-16 units is what one keyboard event carries reliably.
    func testChunksAreAtMostTwentyUnits() {
        for chunk in TextInserter.chunks(of: String(repeating: "x", count: 205)) {
            XCTAssertLessThanOrEqual(chunk.count, 20)
        }
    }

    func testChunksRebuildTheOriginalText() {
        let text = "Il a dit « bonjour » puis il est parti, deux fois."
        let rebuilt = String(utf16CodeUnits: TextInserter.chunks(of: text).flatMap { $0 },
                             count: TextInserter.chunks(of: text).flatMap { $0 }.count)

        XCTAssertEqual(rebuilt, text)
    }

    /// A surrogate pair split across two events would type a broken character.
    func testEmojiAreNotSplitAcrossChunks() {
        let text = String(repeating: "😀", count: 30)
        for chunk in TextInserter.chunks(of: text) {
            XCTAssertEqual(chunk.count % 2, 0, "a surrogate pair was cut in half")
        }
    }

    func testEmptyTextTypesNothing() {
        XCTAssertTrue(TextInserter.chunks(of: "").isEmpty)
    }
}
