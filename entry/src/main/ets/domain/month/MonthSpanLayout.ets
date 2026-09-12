import { LaneLayout } from '../gantt/LaneLayout';
import { GanttSegment } from '../models/GanttSegment';
import { Task } from '../models/Task';
import { dateOnly, mondayOnOrBefore } from '../time/Calendar';
import { WallClock } from '../time/WallClock';

export const kMonthMaxBarsPerDay: number = 10;

export class MonthTaskSelection {
  visible: Task[];
  overflowByDay: Map<number, number>;

  constructor(visible: Task[], overflowByDay: Map<number, number>) {
    this.visible = visible;
    this.overflowByDay = overflowByDay;
  }
}

export class MonthPlacedBar {
  taskId: string;
  title: string;
  lane: number;
  startFrac: number;
  endFrac: number;
  openDay: Date;
  spanStart: number;
  spanEnd: number;

  constructor(
    taskId: string,
    title: string,
    lane: number,
    startFrac: number,
    endFrac: number,
    openDay: Date,
    spanStart: number,
    spanEnd: number
  ) {
    this.taskId = taskId;
    this.title = title;
    this.lane = lane;
    this.startFrac = startFrac;
    this.endFrac = endFrac;
    this.openDay = openDay;
    this.spanStart = spanStart;
    this.spanEnd = spanEnd;
  }
}

export class MonthWeekLayout {
  weekMonday: Date;
  days: Date[];
  bars: MonthPlacedBar[];
  overflowByDay: Map<number, number>;
  laneCount: number;

  constructor(
    weekMonday: Date,
    days: Date[],
    bars: MonthPlacedBar[],
    overflowByDay: Map<number, number>,
    laneCount: number
  ) {
    this.weekMonday = weekMonday;
    this.days = days;
    this.bars = bars;
    this.overflowByDay = overflowByDay;
    this.laneCount = laneCount;
  }
}

export function isSameCalendarDaySpan(start: number, end: number): boolean {
  if (end <= start) {
    return false;
  }
  return WallClock.dayStart(start) === WallClock.dayStart(end - 1);
}

export class DayTimeWindow {
  start: number;
  end: number;

  constructor(start: number, end: number) {
    this.start = start;
    this.end = end;
  }

  frac(t: number): number {
    const span: number = this.end - this.start;
    if (span <= 0) {
      return 0;
    }
    const f: number = (t - this.start) / span;
    if (f < 0) {
      return 0;
    }
    if (f > 1) {
      return 1;
    }
    return f;
  }
}

export function dayTimeWindowFor(day0: number, tasks: Task[]): DayTimeWindow {
  const day1: number = day0 + WallClock.MINUTES_PER_DAY;
  let lo: number | null = null;
  let hi: number | null = null;
  for (let i = 0; i < tasks.length; i++) {
    const t: Task = tasks[i];
    if (!isSameCalendarDaySpan(t.plannedStart, t.plannedEnd)) {
      continue;
    }
    if (t.plannedEnd <= day0 || t.plannedStart >= day1) {
      continue;
    }
    if (lo === null || t.plannedStart < lo) {
      lo = t.plannedStart;
    }
    if (hi === null || t.plannedEnd > hi) {
      hi = t.plannedEnd;
    }
  }
  if (lo === null || hi === null) {
    return new DayTimeWindow(day0, day1);
  }
  if (hi <= lo) {
    hi = lo + 60;
  }
  return new DayTimeWindow(lo, hi);
}

function monthDaysOverlapped(month: Date, start: number, end: number): number[] {
  const monthStart: number = WallClock.minutes(new Date(month.getFullYear(), month.getMonth(), 1));
  const monthEnd: number = WallClock.minutes(new Date(month.getFullYear(), month.getMonth() + 1, 1));
  let day: number = WallClock.dayStart(start);
  if (day < monthStart) {
    day = monthStart;
  }
  const last: number = end < monthEnd ? end : monthEnd;
  const out: number[] = [];
  while (day < last) {
    out.push(WallClock.dateTime(day).getDate());
    day += WallClock.MINUTES_PER_DAY;
  }
  return out;
}

function taskPriorityCompare(a: Task, b: Task): number {
  if (a.plannedStart !== b.plannedStart) {
    return a.plannedStart - b.plannedStart;
  }
  return b.plannedEnd - a.plannedEnd;
}

function dayCountOrZero(counts: Map<number, number>, day: number): number {
  const n: number | undefined = counts.get(day);
  if (n !== undefined) {
    return n;
  }
  return 0;
}

export function selectVisibleMonthTasks(
  month: Date,
  tasks: Task[],
  maxPerDay: number = kMonthMaxBarsPerDay
): MonthTaskSelection {
  const sorted: Task[] = tasks.slice();
  sorted.sort(taskPriorityCompare);
  const dayCounts: Map<number, number> = new Map<number, number>();
  const visible: Task[] = [];

  for (let i = 0; i < sorted.length; i++) {
    const t: Task = sorted[i];
    if (t.plannedEnd <= t.plannedStart) {
      continue;
    }
    const days: number[] = monthDaysOverlapped(month, t.plannedStart, t.plannedEnd);
    if (days.length === 0) {
      continue;
    }
    let fits: boolean = true;
    for (let d = 0; d < days.length; d++) {
      if (dayCountOrZero(dayCounts, days[d]) >= maxPerDay) {
        fits = false;
        break;
      }
    }
    if (!fits) {
      continue;
    }
    visible.push(t);
    for (let d = 0; d < days.length; d++) {
      const day: number = days[d];
      dayCounts.set(day, dayCountOrZero(dayCounts, day) + 1);
    }
  }

  const totalByDay: Map<number, number> = new Map<number, number>();
  for (let i = 0; i < tasks.length; i++) {
    const t: Task = tasks[i];
    if (t.plannedEnd <= t.plannedStart) {
      continue;
    }
    const days: number[] = monthDaysOverlapped(month, t.plannedStart, t.plannedEnd);
    for (let d = 0; d < days.length; d++) {
      const day: number = days[d];
      totalByDay.set(day, dayCountOrZero(totalByDay, day) + 1);
    }
  }

  const overflow: Map<number, number> = new Map<number, number>();
  totalByDay.forEach((total: number, day: number) => {
    const n: number = total - dayCountOrZero(dayCounts, day);
    if (n > 0) {
      overflow.set(day, n);
    }
  });

  return new MonthTaskSelection(visible, overflow);
}

export function buildMonthWeekLayouts(
  month: Date,
  tasks: Task[],
  overflowByDay: Map<number, number> = new Map<number, number>()
): MonthWeekLayout[] {
  const monthStart: Date = new Date(month.getFullYear(), month.getMonth(), 1);
  const monthEnd: Date = new Date(month.getFullYear(), month.getMonth() + 1, 1);
  const firstMonday: Date = mondayOnOrBefore(monthStart);
  const lastDay: Date = new Date(monthEnd.getFullYear(), monthEnd.getMonth(), monthEnd.getDate() - 1);
  const lastMonday: Date = mondayOnOrBefore(lastDay);

  const weeks: MonthWeekLayout[] = [];
  let monday: Date = firstMonday;
  while (monday.getTime() <= lastMonday.getTime()) {
    weeks.push(layoutWeek(monday, month, tasks, overflowByDay));
    monday = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + 7);
  }
  return weeks;
}

function layoutWeek(
  weekMonday: Date,
  month: Date,
  tasks: Task[],
  overflowByDay: Map<number, number>
): MonthWeekLayout {
  const monday: Date = dateOnly(weekMonday);
  const weekStart: number = WallClock.minutes(monday);
  const weekEnd: number = weekStart + 7 * WallClock.MINUTES_PER_DAY;
  const days: Date[] = [];
  for (let i = 0; i < 7; i++) {
    days.push(new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i));
  }

  const segs: GanttSegment[] = [];
  const byKey: Map<string, Task> = new Map<string, Task>();
  for (let i = 0; i < tasks.length; i++) {
    const t: Task = tasks[i];
    const start: number = t.plannedStart > weekStart ? t.plannedStart : weekStart;
    const end: number = t.plannedEnd < weekEnd ? t.plannedEnd : weekEnd;
    if (end <= start) {
      continue;
    }
    const seg: GanttSegment = new GanttSegment(t.id, start, end);
    segs.push(seg);
    byKey.set(LaneLayout.keyOf(seg), t);
  }

  const windows: DayTimeWindow[] = [];
  for (let d = 0; d < 7; d++) {
    windows.push(dayTimeWindowFor(weekStart + d * WallClock.MINUTES_PER_DAY, tasks));
  }

  const lanes: Map<string, number> = LaneLayout.assign(segs);
  const bars: MonthPlacedBar[] = [];
  for (let i = 0; i < segs.length; i++) {
    const seg: GanttSegment = segs[i];
    const key: string = LaneLayout.keyOf(seg);
    const t: Task | undefined = byKey.get(key);
    const lane: number | undefined = lanes.get(key);
    if (t === undefined || lane === undefined) {
      continue;
    }
    const startFrac: number = weekFrac(seg.start, false, weekStart, windows);
    let endFrac: number = weekFrac(seg.end, true, weekStart, windows);
    if (endFrac < startFrac) {
      endFrac = startFrac;
    }
    const open: Date = WallClock.dateTime(WallClock.dayStart(seg.start));
    bars.push(new MonthPlacedBar(
      t.id,
      t.title,
      lane,
      startFrac,
      endFrac,
      dateOnly(open),
      t.plannedStart,
      t.plannedEnd
    ));
  }

  const weekOverflow: Map<number, number> = new Map<number, number>();
  for (let i = 0; i < days.length; i++) {
    const d: Date = days[i];
    if (d.getFullYear() === month.getFullYear() && d.getMonth() === month.getMonth()) {
      const n: number | undefined = overflowByDay.get(d.getDate());
      if (n !== undefined && n > 0) {
        weekOverflow.set(d.getDate(), n);
      }
    }
  }

  return new MonthWeekLayout(
    monday,
    days,
    bars,
    weekOverflow,
    LaneLayout.laneCount(lanes)
  );
}

function weekFrac(
  t: number,
  asEnd: boolean,
  weekStart: number,
  windows: DayTimeWindow[]
): number {
  let dayIndex: number = Math.floor((t - weekStart) / WallClock.MINUTES_PER_DAY);
  let minute: number = t;
  if (asEnd &&
    t > weekStart &&
    (t - weekStart) % WallClock.MINUTES_PER_DAY === 0 &&
    dayIndex > 0) {
    dayIndex -= 1;
    minute = weekStart + (dayIndex + 1) * WallClock.MINUTES_PER_DAY;
  }
  if (dayIndex < 0) {
    return 0;
  }
  if (dayIndex >= 7) {
    return 7;
  }
  return dayIndex + windows[dayIndex].frac(minute);
}
