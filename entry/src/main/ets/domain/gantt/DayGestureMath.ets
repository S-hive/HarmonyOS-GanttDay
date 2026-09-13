import { GanttGeometry } from './GanttGeometry';
import { clampSpanToAxis, clampTimeToAxis, Span } from './DaySpanClamp';
import { Task } from '../models/Task';

export { Span };

export function clampXToView(geo: GanttGeometry, x: number): number {
  if (x < 0) {
    return 0;
  }
  if (x > geo.widthPx) {
    return geo.widthPx;
  }
  return x;
}

export function clampSpanToView(geo: GanttGeometry, start: number, end: number): Span {
  const axis = clampSpanToAxis(start, end, geo.viewStart);
  const minDur = GanttGeometry.MIN_DURATION_MINUTES;
  let s = Math.max(axis.start, geo.viewStart);
  let e = Math.min(axis.end, geo.viewEnd);
  if (e < s + minDur) {
    e = Math.min(geo.viewEnd, s + minDur);
    if (e < s + minDur) {
      s = Math.max(geo.viewStart, e - minDur);
    }
  }
  return new Span(s, e);
}

export function proposeMove(task: Task, geo: GanttGeometry, deltaX: number): Task {
  const duration = task.plannedEnd - task.plannedStart;
  const deltaMinutes = Math.round(deltaX / geo.widthPx * (geo.viewEnd - geo.viewStart));
  const viewSpan = geo.viewEnd - geo.viewStart;
  if (duration >= viewSpan) {
    const span = clampSpanToView(geo, geo.viewStart, geo.viewEnd);
    return task.copyWith(task.title, span.start, span.end);
  }
  const start = geo.snap(task.plannedStart + deltaMinutes);
  const span = clampSpanToView(geo, start, start + duration);
  if (span.end - span.start === duration) {
    return task.copyWith(task.title, span.start, span.end);
  }
  const maxStart = geo.viewEnd - duration;
  let pinned = start;
  if (pinned < geo.viewStart) {
    pinned = geo.viewStart;
  }
  if (pinned > maxStart) {
    pinned = maxStart;
  }
  return task.copyWith(task.title, pinned, pinned + duration);
}

export function proposeResizeStart(task: Task, geo: GanttGeometry, x: number): Task {
  let start = geo.snap(geo.timeOf(clampXToView(geo, x)));
  const latest = task.plannedEnd - GanttGeometry.MIN_DURATION_MINUTES;
  if (start > latest) {
    start = latest;
  }
  const span = clampSpanToView(geo, start, task.plannedEnd);
  return task.copyWith(task.title, span.start, span.end);
}

export function proposeResizeEnd(task: Task, geo: GanttGeometry, x: number): Task {
  const end = geo.clampDuration(
    task.plannedStart,
    geo.snap(geo.timeOf(clampXToView(geo, x)))
  );
  const span = clampSpanToView(geo, task.plannedStart, end);
  return task.copyWith(task.title, span.start, span.end);
}

export function proposeCreateAt(geo: GanttGeometry, x: number): Span {
  const start = geo.snap(geo.timeOf(clampXToView(geo, x)));
  return new Span(start, start + 60);
}

export function proposeCreate(geo: GanttGeometry, x0: number, x1: number): Span {
  const left: number = clampXToView(geo, Math.min(x0, x1));
  const right: number = clampXToView(geo, Math.max(x0, x1));
  const start: number = geo.snap(geo.timeOf(left));
  const end: number = geo.clampDuration(start, geo.snap(geo.timeOf(right)));
  return clampSpanToView(geo, start, end);
}

export function expandProbeFromOverscroll(
  day0: number,
  maxEnd: number,
  edgeBase: number,
  hourPx: number,
  overscrollPx: number,
  toTheRight: boolean
): number {
  let safeHourPx = hourPx;
  if (safeHourPx < 28) {
    safeHourPx = 28;
  }
  if (safeHourPx > 400) {
    safeHourPx = 400;
  }
  if (overscrollPx <= 0) {
    return clampTimeToAxis(edgeBase, day0);
  }
  const extraHours = Math.max(1, Math.ceil(overscrollPx / safeHourPx));
  const probe = toTheRight ? edgeBase + extraHours * 60 : edgeBase - extraHours * 60;
  const clamped = clampTimeToAxis(probe, day0);
  if (clamped > maxEnd) {
    return maxEnd;
  }
  return clamped;
}
