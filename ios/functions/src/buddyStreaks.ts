export interface BuddyStreak {
  current: number;
  longest: number;
  lastMutualDate?: string;
}

/**
 * Advances a pair's streak for one mutual local date. Local dates are calendar
 * dates (`YYYY-MM-DD`), so use UTC solely to avoid a host timezone affecting the
 * day-after comparison.
 */
export function advanceStreak(previous: BuddyStreak, mutualDate: string): BuddyStreak {
  const { current, longest, lastMutualDate } = previous;

  if (mutualDate === lastMutualDate) return { current, longest, lastMutualDate };
  if (lastMutualDate === undefined || mutualDate > dayAfter(lastMutualDate)) {
    return { current: 1, longest: Math.max(longest, 1), lastMutualDate: mutualDate };
  }
  if (mutualDate < lastMutualDate) return { current, longest, lastMutualDate };

  const nextCurrent = current + 1;
  return {
    current: nextCurrent,
    longest: Math.max(longest, nextCurrent),
    lastMutualDate: mutualDate,
  };
}

function dayAfter(localDate: string): string {
  const [year, month, day] = localDate.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day + 1));
  return [date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate()]
    .map((part, index) => (index === 0 ? String(part).padStart(4, "0") : String(part).padStart(2, "0")))
    .join("-");
}
