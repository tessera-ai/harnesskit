import XCTest

@testable import Tessera

final class WorkoutKitTests: XCTestCase {

    // MARK: - MockWorkoutScheduler returns canonical fixture

    func testMockSchedulerReturnsCanonicalResponse() async throws {
        let scheduler = MockWorkoutScheduler()
        let result = try await scheduler.schedule(
            exercises: CanonicalRun.exercises,
            time: CanonicalRun.scheduleTime,
            durationMin: CanonicalRun.scheduleDurationMin
        )
        XCTAssertTrue(result.scheduled)
        XCTAssertEqual(result.workoutId, "wk_a1b2c3")
    }

    // MARK: - Tool parses JSON args and returns canonical fixture

    func testToolParsesCanonicalArgs() async throws {
        let tool = WorkoutKitScheduleTool()
        let result = try await tool.invokeJSON(CanonicalRun.workoutkitArgsJSON)

        // Must contain the canonical fixture values.
        XCTAssertTrue(result.contains("\"scheduled\":true"))
        XCTAssertTrue(result.contains("\"workoutId\":\"wk_a1b2c3\""))
    }

    func testToolParsesMinimalArgs() async throws {
        let tool = WorkoutKitScheduleTool()
        let args = #"{"exercises":[],"time":"07:30","durationMin":30}"#
        let result = try await tool.invokeJSON(args)

        // Mock scheduler ignores args — always returns canonical fixture.
        XCTAssertTrue(result.contains("\"scheduled\":true"))
    }

    // MARK: - ScheduledWorkout Codable round-trip

    func testScheduledWorkoutRoundTrip() throws {
        let original = ScheduledWorkout(scheduled: true, workoutId: "wk_test")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScheduledWorkout.self, from: data)
        XCTAssertEqual(decoded.scheduled, original.scheduled)
        XCTAssertEqual(decoded.workoutId, original.workoutId)
    }

    // MARK: - Invalid JSON throws

    func testToolThrowsOnInvalidJSON() async {
        let tool = WorkoutKitScheduleTool()
        do {
            _ = try await tool.invokeJSON("not json")
            XCTFail("Expected error for invalid JSON")
        } catch {
            // Expected — JSON decoding failure.
        }
    }

    // MARK: - Hero-shot backward compatibility

    func testWorkoutKitScheduleReturnsScheduledTrue() async throws {
        let tool = WorkoutKit.schedule
        let result = try await tool.invokeJSON(CanonicalRun.workoutkitArgsJSON)
        XCTAssertTrue(result.contains("\"scheduled\":true"))
        XCTAssertTrue(result.contains("\"workoutId\":\"wk_a1b2c3\""))
    }
    // MARK: - TimeParser

    func testTimeParserValidTimes() {
        let t0600 = TimeParser.parse("06:00")
        XCTAssertEqual(t0600?.hour, 6)
        XCTAssertEqual(t0600?.minute, 0)

        let t2359 = TimeParser.parse("23:59")
        XCTAssertEqual(t2359?.hour, 23)
        XCTAssertEqual(t2359?.minute, 59)

        let t0000 = TimeParser.parse("00:00")
        XCTAssertEqual(t0000?.hour, 0)
        XCTAssertEqual(t0000?.minute, 0)
    }

    func testTimeParserRejectsInvalidHour() {
        XCTAssertNil(TimeParser.parse("24:00"))
        XCTAssertNil(TimeParser.parse("25:00"))
        XCTAssertNil(TimeParser.parse("-1:00"))
    }

    func testTimeParserRejectsInvalidMinute() {
        XCTAssertNil(TimeParser.parse("12:60"))
        XCTAssertNil(TimeParser.parse("12:90"))
    }

    func testTimeParserRejectsMalformed() {
        XCTAssertNil(TimeParser.parse("abc"))
        XCTAssertNil(TimeParser.parse("7"))
        XCTAssertNil(TimeParser.parse(""))
        XCTAssertNil(TimeParser.parse("::"))
    }

    func testTimeParserDefaultConstants() {
        XCTAssertEqual(TimeParser.defaultHour, 18)
        XCTAssertEqual(TimeParser.defaultMinute, 0)
    }
}
