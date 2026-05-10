/**
 * Pure helpers for Classic tournament slot ids (two per UTC day: 07:00 and 23:00).
 */

import {DateTime} from "luxon";

/** Slot suffix for classic tournaments anchored to 07:00 or 23:00 UTC. */
export type ClassicSlotKey = "07utc" | "23utc";

/**
 * Builds `classic_{YYYY-MM-DD}_{07utc|23utc}` from a Date that falls exactly
 * on 07:00 or 23:00 UTC (minute/second/ms zero).
 */
export function classicSlotIdFromStartUtc(startUtc: Date): string {
  const dt = DateTime.fromJSDate(startUtc).toUTC();
  if (dt.minute !== 0 || dt.second !== 0 || dt.millisecond !== 0) {
    throw new Error("startUtc must be on the hour (minute/second/ms zero) in UTC");
  }
  const h = dt.hour;
  if (h !== 7 && h !== 23) {
    throw new Error("startUtc must be exactly 07:00 or 23:00 UTC");
  }
  const key: ClassicSlotKey = h === 7 ? "07utc" : "23utc";
  return `classic_${dt.toFormat("yyyy-MM-dd")}_${key}`;
}

/**
 * Builds `live_{YYYY-MM-DD}_{07utc|23utc}` — same slot timing as Classic, Live prefix.
 */
export function liveSlotIdFromStartUtc(startUtc: Date): string {
  const dt = DateTime.fromJSDate(startUtc).toUTC();
  if (dt.minute !== 0 || dt.second !== 0 || dt.millisecond !== 0) {
    throw new Error("startUtc must be on the hour (minute/second/ms zero) in UTC");
  }
  const h = dt.hour;
  if (h !== 7 && h !== 23) {
    throw new Error("startUtc must be exactly 07:00 or 23:00 UTC");
  }
  const key: ClassicSlotKey = h === 7 ? "07utc" : "23utc";
  return `live_${dt.toFormat("yyyy-MM-dd")}_${key}`;
}

/**
 * Returns true iff the instant is exactly 07:00 or 23:00 UTC on the clock
 * (minute, second, and millisecond zero).
 */
export function isClassicSlotHourUtc(d: Date): boolean {
  const dt = DateTime.fromJSDate(d).toUTC();
  if (dt.minute !== 0 || dt.second !== 0 || dt.millisecond !== 0) {
    return false;
  }
  return dt.hour === 7 || dt.hour === 23;
}

/**
 * Snap a UTC instant to the nearest classic slot start (07:00 or 23:00 UTC).
 */
function snapToNearestClassicSlotUtc(dt: DateTime): DateTime {
  const utc = dt.toUTC();
  let best: DateTime | null = null;
  let bestDiff = Infinity;
  for (let d = -1; d <= 1; d++) {
    const dayStart = utc.plus({days: d}).startOf("day");
    for (const hour of [7, 23]) {
      const cand = dayStart.set({
        hour,
        minute: 0,
        second: 0,
        millisecond: 0,
      });
      const diff = Math.abs(cand.toMillis() - utc.toMillis());
      if (diff < bestDiff) {
        bestDiff = diff;
        best = cand;
      }
    }
  }
  if (!best) {
    throw new Error("snapToNearestClassicSlotUtc: no candidate");
  }
  return best;
}

/**
 * Computes the target classic slot for scheduled jobs.
 *
 * - `leadHours === 24`: slot whose **start** is 24 hours after `now` (generation T-24h).
 * - `leadHours === 12`: slot whose **start** is 12 hours after `now` (visibility T-12h).
 * - `leadHours === -24`: slot whose **start** was 24 hours before `now` (finalize when the
 *   24h window ending at `now` closes).
 *
 * The anchor instant (`now` ± lead) is snapped to the nearest 07:00 or 23:00 UTC.
 */
export function nextClassicSlotStartFromNow(
  now: Date,
  leadHours: 24 | 12 | -24,
): {slotId: string; startUtc: Date} {
  let anchor = DateTime.fromJSDate(now).toUTC();
  if (leadHours === 24) {
    anchor = anchor.plus({hours: 24});
  } else if (leadHours === 12) {
    anchor = anchor.plus({hours: 12});
  } else {
    anchor = anchor.minus({hours: 24});
  }
  const snapped = snapToNearestClassicSlotUtc(anchor);
  const startUtc = snapped.toJSDate();
  const slotId = classicSlotIdFromStartUtc(startUtc);
  return {slotId, startUtc};
}
