import { GanttSegment } from '../models/GanttSegment';

export class LaneLayout {
  static keyOf(s: GanttSegment): string {
    return `${s.taskId}:${s.start}`;
  }

  static withoutTask(segs: GanttSegment[], taskId: string): GanttSegment[] {
    if (taskId.length === 0) {
      return segs;
    }
    const out: GanttSegment[] = [];
    for (let i = 0; i < segs.length; i++) {
      if (segs[i].taskId !== taskId) {
        out.push(segs[i]);
      }
    }
    return out;
  }

  static assignExclusive(segs: GanttSegment[]): Map<string, number> {
    const sorted: GanttSegment[] = segs.slice();
    sorted.sort((a: GanttSegment, b: GanttSegment): number => {
      if (a.start !== b.start) {
        return a.start - b.start;
      }
      return a.end - b.end;
    });
    const taskLane: Map<string, number> = new Map<string, number>();
    const out: Map<string, number> = new Map<string, number>();
    let next: number = 0;
    for (let i = 0; i < sorted.length; i++) {
      const s: GanttSegment = sorted[i];
      let lane: number | undefined = taskLane.get(s.taskId);
      if (lane === undefined) {
        lane = next;
        next++;
        taskLane.set(s.taskId, lane);
      }
      out.set(LaneLayout.keyOf(s), lane);
    }
    return out;
  }

  static assign(segs: GanttSegment[]): Map<string, number> {
    const sorted: GanttSegment[] = segs.slice();
    sorted.sort((a: GanttSegment, b: GanttSegment): number => {
      if (a.start !== b.start) {
        return a.start - b.start;
      }
      return a.end - b.end;
    });
    const laneEnds: number[] = [];
    const out: Map<string, number> = new Map<string, number>();
    for (let i = 0; i < sorted.length; i++) {
      const s: GanttSegment = sorted[i];
      let lane = 0;
      while (lane < laneEnds.length && laneEnds[lane] > s.start) {
        lane++;
      }
      if (lane === laneEnds.length) {
        laneEnds.push(s.end);
      } else {
        laneEnds[lane] = s.end;
      }
      out.set(LaneLayout.keyOf(s), lane);
    }
    return out;
  }

  static nextFreeLane(lanes: Map<string, number>, preferred: number): number {
    const used: Set<number> = new Set<number>();
    lanes.forEach((lane: number) => {
      used.add(lane);
    });
    let lane: number = preferred < 0 ? 0 : preferred;
    while (used.has(lane)) {
      lane++;
    }
    return lane;
  }

  static laneCount(lanes: Map<string, number>): number {
    if (lanes.size === 0) {
      return 1;
    }
    let maxLane = 0;
    lanes.forEach((lane: number) => {
      if (lane > maxLane) {
        maxLane = lane;
      }
    });
    return maxLane + 1;
  }
}
