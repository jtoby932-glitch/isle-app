import XCTest
@testable import Isle

final class PlannerTests: XCTestCase {
    let monday = 20261123

    func testHabitWithDaysTimeAndDuration() {
        let p = QuickParser.parse("gym tue thu sat 7am 45m", today: monday)
        XCTAssertEqual(p.name, "Gym")
        XCTAssertTrue(p.isHabit)
        XCTAssertEqual(p.weekdays, [1, 3, 5])
        XCTAssertEqual(p.startMinutes, 7 * 60)
        XCTAssertEqual(p.minutes, 45)
    }

    func testSingleDayTaskGoesToNextOccurrence() {
        let p = QuickParser.parse("dentist fri 2pm", today: monday)
        XCTAssertFalse(p.isHabit)
        XCTAssertEqual(p.dayKey, 20261127)
        XCTAssertEqual(p.startMinutes, 14 * 60)
    }

    func testHoursAndDaily() {
        let p = QuickParser.parse("read daily 8:30am 15m", today: monday)
        XCTAssertTrue(p.isHabit)
        XCTAssertEqual(p.weekdays.count, 7)
        XCTAssertEqual(p.startMinutes, 8 * 60 + 30)
        let q = QuickParser.parse("finish draft wed 2h", today: monday)
        XCTAssertEqual(q.minutes, 120)
        XCTAssertEqual(q.name, "Finish draft")
    }

    func testDayKeys() {
        XCTAssertEqual(Day.weekday(monday), 0)
        XCTAssertEqual(Day.add(monday, days: 8), 20261201)
        XCTAssertEqual(Day.weekStart(20261129), monday)
    }

    func testLevels() {
        XCTAssertEqual(Rewards.level(forGrowth: 0), 1)
        XCTAssertEqual(Rewards.level(forGrowth: 100), 2)
        XCTAssertEqual(Rewards.level(forGrowth: 299), 2)
        XCTAssertEqual(Rewards.level(forGrowth: 300), 3)
    }

    func testSynthProducesAudio() {
        let tick = Synth.render("tick", pack: "wood")
        XCTAssertGreaterThan(tick.count, 1000)
        XCTAssertLessThanOrEqual(tick.map { abs($0) }.max() ?? 2, 1)
        XCTAssertFalse(Synth.ambient("rain").isEmpty)
    }
}
