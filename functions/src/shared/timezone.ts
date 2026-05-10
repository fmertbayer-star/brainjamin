import {DateTime} from "luxon";

export function isValidTimezone(timezone: unknown): timezone is string {
  if (typeof timezone !== "string") {
    return false;
  }
  return DateTime.now().setZone(timezone).isValid;
}
