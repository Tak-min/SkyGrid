import assert from "node:assert/strict";
import test from "node:test";
import {
  isWithinQuietHours,
  localHourForTimezone,
  previousDayString,
} from "../lib/streakBreakReminders.js";

test("local hour follows the recipient timezone", () => {
  const instant = Date.parse("2026-09-17T11:00:00Z");
  assert.equal(localHourForTimezone(instant, "Asia/Tokyo"), 20);
  assert.equal(localHourForTimezone(instant, "Europe/London"), 12);
});

test("invalid timezones fail closed for reminder delivery", () => {
  const instant = Date.parse("2026-09-17T11:00:00Z");
  assert.equal(localHourForTimezone(instant, "Not/A-Timezone"), null);
  assert.equal(isWithinQuietHours("Not/A-Timezone", instant), true);
});

test("previous day remains calendar-safe across month boundaries", () => {
  assert.equal(previousDayString("2026-03-01"), "2026-02-28");
});
