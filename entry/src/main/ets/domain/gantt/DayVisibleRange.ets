import { WallClock } from '../time/WallClock';

export const kDayViewMaxSpanMinutes: number = 7 * WallClock.MINUTES_PER_DAY;

export class FitMinutes {
  start: number;
  end: number;

  constructor(start: number, end: number) {
    this.start = start;
    this.end = end;
  }
}

function clampInt(value: number, lo: number, hi: number): number {
  if (value < lo) {
    return lo;
  }
  if (value > hi) {
    return hi;
  }
  return value;
}

export function expandFitMinutes(
  fitStart: number,
  fitEnd: number,
  day0: number,
  time: number,
  expandAtExactEnd: boolean = true
): FitMinutes {
  let start = clampInt(fitStart, 0, kDayViewMaxSpanMinutes - 60);
  let end = clampInt(fitEnd, 60, kDayViewMaxSpanMinutes);
  if (end <= start) {
    end = start + 60;
  }

  const minutes = clampInt(time - day0, 0, kDayViewMaxSpanMinutes);

  if (minutes < start) {
    start = Math.floor(minutes / 60) * 60;
    if (start >= end) {
      start = clampInt(end - 60, 0, end - 60);
    }
  }
  if (minutes > end) {
    end = clampInt(Math.floor((minutes + 59) / 60) * 60, start + 60, kDayViewMaxSpanMinutes);
  } else if (expandAtExactEnd && minutes === end && end < kDayViewMaxSpanMinutes) {
    end = clampInt(end + 60, start + 60, kDayViewMaxSpanMinutes);
  }
  return new FitMinutes(start, end);
}

export function computeDayFitMinutes(
  settingsStartHour: number,
  settingsEndHour: number,
  day0: number,
  daySpans: FitMinutes[],
  alsoInclude: number[]
): FitMinutes {
  let start = clampInt(settingsStartHour, 0, 23) * 60;
  let end = clampInt(settingsEndHour, 1, 24) * 60;
  if (end <= start) {
    end = start + 60;
  }

  for (let i = 0; i < daySpans.length; i++) {
    const span = daySpans[i];
    if (span.end <= span.start) {
      continue;
    }
    const covered = expandFitMinutes(start, end, day0, span.start, false);
    start = covered.start;
    end = covered.end;
    const last = expandFitMinutes(start, end, day0, span.end - 1, false);
    start = last.start;
    end = last.end;
  }

  for (let j = 0; j < alsoInclude.length; j++) {
    const live = expandFitMinutes(start, end, day0, alsoInclude[j], true);
    start = live.start;
    end = live.end;
  }

  return new FitMinutes(start, end);
}
