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
}
