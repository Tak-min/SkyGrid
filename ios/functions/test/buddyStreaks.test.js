const test = require("node:test");
const assert = require("node:assert/strict");

const { advanceStreak } = require("../lib/buddyStreaks.js");

test("same mutual date is unchanged and therefore idempotent", () => {
  const previous = { current: 4, longest: 7, lastMutualDate: "2026-03-10" };
  const once = advanceStreak(previous, "2026-03-10");
  const twice = advanceStreak(once, "2026-03-10");

  assert.deepEqual(once, previous);
  assert.deepEqual(twice, once);
});

test("the day after increments across month and year boundaries", () => {
  assert.deepEqual(
    advanceStreak({ current: 2, longest: 2, lastMutualDate: "2026-01-31" }, "2026-02-01"),
    { current: 3, longest: 3, lastMutualDate: "2026-02-01" },
  );
  assert.deepEqual(
    advanceStreak({ current: 6, longest: 9, lastMutualDate: "2026-12-31" }, "2027-01-01"),
    { current: 7, longest: 9, lastMutualDate: "2027-01-01" },
  );
});

test("a gap or absent last mutual date resets current to one without lowering longest", () => {
  assert.deepEqual(
    advanceStreak({ current: 5, longest: 8, lastMutualDate: "2026-03-10" }, "2026-03-12"),
    { current: 1, longest: 8, lastMutualDate: "2026-03-12" },
  );
  assert.deepEqual(
    advanceStreak({ current: 5, longest: 8, lastMutualDate: undefined }, "2026-03-10"),
    { current: 1, longest: 8, lastMutualDate: "2026-03-10" },
  );
});

test("a fresh pair's first mutual day raises longest from zero to one", () => {
  assert.deepEqual(
    advanceStreak({ current: 0, longest: 0 }, "2026-03-10"),
    { current: 1, longest: 1, lastMutualDate: "2026-03-10" },
  );
});

test("an earlier mutual date never rewrites history", () => {
  const previous = { current: 5, longest: 8, lastMutualDate: "2026-03-10" };
  assert.deepEqual(advanceStreak(previous, "2026-03-09"), previous);
});
