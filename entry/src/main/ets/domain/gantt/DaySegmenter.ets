import { GanttSegment } from '../models/GanttSegment';
import { Task } from '../models/Task';
import { WallClock } from '../time/WallClock';

export class DaySegmenter {
  static segmentsForDay(task: Task, dayAny: number): GanttSegment[] {
    return DaySegmenter.clipToDay(task.id, task.plannedStart, task.plannedEnd, dayAny);
  }

  static clipToDay(taskId: string, start: number, end: number, dayAny: number): GanttSegment[] {
    const day0 = WallClock.dayStart(dayAny);
    const day1 = WallClock.dayEndExclusive(dayAny);
    return DaySegmenter.clipToRange(taskId, start, end, day0, day1);
  }

  static clipToRange(
    taskId: string,
    start: number,
    end: number,
    rangeStart: number,
    rangeEnd: number
  ): GanttSegment[] {
    if (start >= rangeEnd || end <= rangeStart) {
      return [];
    }
    const clippedStart = start < rangeStart ? rangeStart : start;
    const clippedEnd = end > rangeEnd ? rangeEnd : end;
    if (clippedEnd <= clippedStart) {
      return [];
    }
    return [new GanttSegment(taskId, clippedStart, clippedEnd)];
  }

  static mergeAbutting(segs: GanttSegment[]): GanttSegment[] {
    const out: GanttSegment[] = [];
    for (let i = 0; i < segs.length; i++) {
      const s: GanttSegment = segs[i];
      if (out.length === 0) {
        out.push(s);
        continue;
      }
      const last: GanttSegment = out[out.length - 1];
      if (last.taskId === s.taskId && last.end === s.start) {
        out[out.length - 1] = new GanttSegment(s.taskId, last.start, s.end);
      } else {
        out.push(s);
      }
    }
    return out;
  }
}
