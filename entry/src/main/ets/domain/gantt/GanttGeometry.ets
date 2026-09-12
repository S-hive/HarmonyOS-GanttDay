export class GanttGeometry {
  static readonly MIN_DURATION_MINUTES: number = 15;
  static readonly SNAP_MINUTES: number = 15;

  viewStart: number;
  viewEnd: number;
  widthPx: number;

  constructor(viewStart: number, viewEnd: number, widthPx: number) {
    this.viewStart = viewStart;
    this.viewEnd = viewEnd;
    this.widthPx = widthPx;
  }

  xOf(t: number): number {
    return (t - this.viewStart) / (this.viewEnd - this.viewStart) * this.widthPx;
  }

  timeOf(x: number): number {
    return this.viewStart + Math.round((x / this.widthPx) * (this.viewEnd - this.viewStart));
  }

  snap(t: number): number {
    const r = t % GanttGeometry.SNAP_MINUTES;
    return r < GanttGeometry.SNAP_MINUTES / 2 ? t - r : t + (GanttGeometry.SNAP_MINUTES - r);
  }

  clampDuration(start: number, end: number): number {
    if (end < start + GanttGeometry.MIN_DURATION_MINUTES) {
      return start + GanttGeometry.MIN_DURATION_MINUTES;
    }
    return end;
  }
}
