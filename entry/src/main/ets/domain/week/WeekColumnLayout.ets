import { DaySegmenter } from '../gantt/DaySegmenter';
import { GanttSegment } from '../models/GanttSegment';
import { Task } from '../models/Task';
import { WallClock } from '../time/WallClock';

export class WeekSlot {
  taskId: string;
  title: string;
  dayIndex: number;
  segStart: number;
  segEnd: number;
  spanStart: number;
  spanEnd: number;
  topFrac: number;
  heightFrac: number;
  columnIndex: number;
  columnCount: number;

  constructor(
    taskId: string,
    title: string,
    dayIndex: number,
    segStart: number,
    segEnd: number,
    spanStart: number,
    spanEnd: number,
    topFrac: number,
    heightFrac: number,
    columnIndex: number,
    columnCount: number
  ) {
    this.taskId = taskId;
    this.title = title;
    this.dayIndex = dayIndex;
    this.segStart = segStart;
    this.segEnd = segEnd;
    this.spanStart = spanStart;
    this.spanEnd = spanEnd;
    this.topFrac = topFrac;
    this.heightFrac = heightFrac;
    this.columnIndex = columnIndex;
    this.columnCount = columnCount;
  }
}

export function dateOnly(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

export function mondayOnOrBefore(d: Date): Date {
  const day: Date = dateOnly(d);
  const jsDay: number = day.getDay();
  const back: number = jsDay === 0 ? 6 : jsDay - 1;
  return new Date(day.getFullYear(), day.getMonth(), day.getDate() - back);
}

class RawSlot {
  taskId: string;
  title: string;
  dayIndex: number;
  segStart: number;
  segEnd: number;
  spanStart: number;
  spanEnd: number;
  topFrac: number;
  heightFrac: number;
  columnIndex: number;
  columnCount: number;

  constructor(
    taskId: string,
    title: string,
    dayIndex: number,
    segStart: number,
    segEnd: number,
    spanStart: number,
    spanEnd: number,
    topFrac: number,
    heightFrac: number
  ) {
    this.taskId = taskId;
    this.title = title;
    this.dayIndex = dayIndex;
    this.segStart = segStart;
    this.segEnd = segEnd;
    this.spanStart = spanStart;
    this.spanEnd = spanEnd;
    this.topFrac = topFrac;
    this.heightFrac = heightFrac;
    this.columnIndex = 0;
    this.columnCount = 1;
  }
}

function findRoot(parent: number[], i: number): number {
  let idx: number = i;
  while (parent[idx] !== idx) {
    parent[idx] = parent[parent[idx]];
    idx = parent[idx];
  }
  return idx;
}

function unionRoots(parent: number[], a: number, b: number): void {
  const ra: number = findRoot(parent, a);
  const rb: number = findRoot(parent, b);
  if (ra !== rb) {
    parent[rb] = ra;
  }
}

function overlaps(a: RawSlot, b: RawSlot): boolean {
  return a.segStart < b.segEnd && b.segStart < a.segEnd;
}

function packDay(items: RawSlot[]): WeekSlot[] {
  if (items.length === 0) {
    return [];
  }
  const sorted: RawSlot[] = items.slice();
  sorted.sort((a: RawSlot, b: RawSlot): number => {
    if (a.segStart !== b.segStart) {
      return a.segStart - b.segStart;
    }
    return a.segEnd - b.segEnd;
  });

  const colEnds: number[] = [];
  for (let i = 0; i < sorted.length; i++) {
    const item: RawSlot = sorted[i];
    let col: number = 0;
    while (col < colEnds.length && colEnds[col] > item.segStart) {
      col++;
    }
    if (col === colEnds.length) {
      colEnds.push(item.segEnd);
    } else {
      colEnds[col] = item.segEnd;
    }
    item.columnIndex = col;
  }

  const n: number = sorted.length;
  const parent: number[] = [];
  for (let i = 0; i < n; i++) {
    parent.push(i);
  }

  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      if (overlaps(sorted[i], sorted[j])) {
        unionRoots(parent, i, j);
      }
    }
  }

  const maxCol: Map<number, number> = new Map<number, number>();
  for (let i = 0; i < n; i++) {
    const r: number = findRoot(parent, i);
    const c: number = sorted[i].columnIndex;
    const prev: number | undefined = maxCol.get(r);
    if (prev !== undefined) {
      maxCol.set(r, prev > c ? prev : c);
    } else {
      maxCol.set(r, c);
    }
  }
  for (let i = 0; i < n; i++) {
    const rootMax: number | undefined = maxCol.get(findRoot(parent, i));
    if (rootMax !== undefined) {
      sorted[i].columnCount = rootMax + 1;
    }
  }

  const out: WeekSlot[] = [];
  for (let i = 0; i < sorted.length; i++) {
    const s: RawSlot = sorted[i];
    out.push(new WeekSlot(
      s.taskId,
      s.title,
      s.dayIndex,
      s.segStart,
      s.segEnd,
      s.spanStart,
      s.spanEnd,
      s.topFrac,
      s.heightFrac,
      s.columnIndex,
      s.columnCount
    ));
  }
  return out;
}

export function layoutWeekSlots(weekMonday: Date, tasks: Task[]): WeekSlot[] {
  const monday: Date = dateOnly(weekMonday);
  const weekStart: number = WallClock.minutes(monday);
  const weekEnd: number = weekStart + 7 * WallClock.MINUTES_PER_DAY;

  const byDay: RawSlot[][] = [];
  for (let i = 0; i < 7; i++) {
    byDay.push([]);
  }

  for (let t = 0; t < tasks.length; t++) {
    const task: Task = tasks[t];
    if (task.plannedEnd <= task.plannedStart) {
      continue;
    }
    for (let d = 0; d < 7; d++) {
      const day0: number = weekStart + d * WallClock.MINUTES_PER_DAY;
      const segs: GanttSegment[] = DaySegmenter.clipToDay(task.id, task.plannedStart, task.plannedEnd, day0);
      if (segs.length === 0) {
        continue;
      }
      if (day0 < weekStart || day0 >= weekEnd) {
        continue;
      }
      const seg: GanttSegment = segs[0];
      const top: number = (seg.start - day0) / WallClock.MINUTES_PER_DAY;
      const height: number = (seg.end - seg.start) / WallClock.MINUTES_PER_DAY;
      byDay[d].push(new RawSlot(
        task.id,
        task.title,
        d,
        seg.start,
        seg.end,
        task.plannedStart,
        task.plannedEnd,
        top,
        height
      ));
    }
  }

  const out: WeekSlot[] = [];
  for (let d = 0; d < byDay.length; d++) {
    const packed: WeekSlot[] = packDay(byDay[d]);
    for (let i = 0; i < packed.length; i++) {
      out.push(packed[i]);
    }
  }
  return out;
}
