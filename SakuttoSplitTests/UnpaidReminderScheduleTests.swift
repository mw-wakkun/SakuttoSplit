//
//  UnpaidReminderScheduleTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import XCTest
@testable import SakuttoSplit

final class UnpaidReminderScheduleTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.locale = Locale(identifier: "ja_JP")
        self.calendar = calendar
    }

    func testFireDate_19_00_IsSameDay22_00() throws {
        let now = try date(hour: 19, minute: 0)
        let fire = UnpaidReminderSchedule.fireDate(now: now, calendar: calendar)

        XCTAssertEqual(fire, try date(hour: 22, minute: 0))
    }

    func testFireDate_22_00_ShiftsToNextDay10_00() throws {
        let now = try date(hour: 22, minute: 0)
        let fire = UnpaidReminderSchedule.fireDate(now: now, calendar: calendar)

        XCTAssertEqual(fire, try date(day: 16, hour: 10, minute: 0))
    }

    func testFireDate_08_00_IsSameDay11_00() throws {
        let now = try date(hour: 8, minute: 0)
        let fire = UnpaidReminderSchedule.fireDate(now: now, calendar: calendar)

        XCTAssertEqual(fire, try date(hour: 11, minute: 0))
    }

    func testFireDate_07_30_IsSameDay10_30() throws {
        let now = try date(hour: 7, minute: 30)
        let fire = UnpaidReminderSchedule.fireDate(now: now, calendar: calendar)

        XCTAssertEqual(fire, try date(hour: 10, minute: 30))
    }

    func testFireDate_09_00_DoesNotShift() throws {
        let now = try date(hour: 9, minute: 0)
        let fire = UnpaidReminderSchedule.fireDate(now: now, calendar: calendar)

        XCTAssertEqual(fire, try date(hour: 12, minute: 0))
    }

    func testDelay_IsThreeHours() {
        XCTAssertEqual(UnpaidReminderSchedule.delay, 3 * 60 * 60)
    }

    private func date(day: Int = 15, hour: Int, minute: Int) throws -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return try XCTUnwrap(calendar.date(from: components))
    }
}
