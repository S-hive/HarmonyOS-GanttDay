import { GanttGeometry } from './GanttGeometry';
import { kDayViewMaxSpanMinutes } from './DayVisibleRange';
import { WallClock } from '../time/WallClock';

export class Span {
  start: number;
  end: number;

  constructor(start: number, end: number) {
    this.start = start;
    this.end = end;
  }
}

export class DayAxisBounds {
  day0: number;
  maxEnd: number;

  constructor(day0: number, maxEnd: number) {
    this.day0 = day0;
    this.maxEnd = maxEnd;
  }
}

export function dayAxisBounds(dayAny: number): DayAxisBounds {
  const day0 = WallClock.dayStart(dayAny);
  return new DayAxisBounds(day0, day0 + kDayViewMaxSpanMinutes);
}

export function clampSpanToAxis(
  start: number,
  end: number,
  dayAny: number,
  minDurationMinutes: number = GanttGeometry.MIN_DURATION_MINUTES
): Span {
  const bounds = dayAxisBounds(dayAny);
  const day0 = bounds.day0;
  const maxEnd = bounds.maxEnd;

  let s = start;
  let e = end;
  if (e < s + minDurationMinutes) {
    e = s + minDurationMinutes;
  }

  if (s < day0) {
    s = day0;
  }
  if (s > maxEnd - minDurationMinutes) {
    s = maxEnd - minDurationMinutes;
  }
  if (e > maxEnd) {
    e = maxEnd;
  }
  if (e < s + minDurationMinutes) {
    e = s + minDurationMinutes;
    if (e > maxEnd) {
      e = maxEnd;
      s = maxEnd - minDurationMinutes;
    }
  }
  return new Span(s, e);
}

export function clampTimeToAxis(time: number, dayAny: number): number {
  const bounds = dayAxisBounds(dayAny);
  if (time < bounds.day0) {
    return bounds.day0;
  }
  if (time > bounds.maxEnd) {
    return bounds.maxEnd;
  }
  return time;
}
