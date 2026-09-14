import { expandProbeFromOverscroll } from './DayGestureMath';
import { kDayViewMaxSpanMinutes } from './DayVisibleRange';

export const CREATE_EDGE_ZONE_VP: number = 168;
export const CREATE_EDGE_HOLD_FRAC: number = 0.35;
export const CREATE_EDGE_REPEAT_MS: number = 180;

function hourWidth(viewportW: number, viewStart: number, viewEnd: number): number {
  const hours: number = (viewEnd - viewStart) / 60;
  if (hours <= 0 || viewportW <= 0) {
    return 28;
  }
  return viewportW / hours;
}

export class CreateEdgePush {
  hasRight: boolean = false;
  rightBase: number = 0;
  rightPushPx: number = 0;
  hasLeft: boolean = false;
  leftBase: number = 0;
  leftPushPx: number = 0;

  reset(): void {
    this.hasRight = false;
    this.hasLeft = false;
    this.rightPushPx = 0;
    this.leftPushPx = 0;
  }

  shouldHoldRepeat(rawX: number, viewportW: number): boolean {
    const outer: number = CREATE_EDGE_ZONE_VP * CREATE_EDGE_HOLD_FRAC;
    return rawX >= viewportW - outer || rawX <= outer;
  }

  applyPointer(
    rawX: number,
    viewportW: number,
    viewStart: number,
    viewEnd: number,
    day0: number
  ): number | null {
    this.updatePushes(rawX, viewportW, 0, viewStart, viewEnd);
    return this.probe(viewportW, viewStart, viewEnd, day0);
  }

  holdTick(
    rawX: number,
    viewportW: number,
    _hourPx: number,
    viewStart: number,
    viewEnd: number,
    day0: number
  ): number | null {
    if (!this.shouldHoldRepeat(rawX, viewportW)) {
      return this.probe(viewportW, viewStart, viewEnd, day0);
    }
    const step: number = hourWidth(viewportW, viewStart, viewEnd);
    if (rawX >= viewportW - CREATE_EDGE_ZONE_VP * CREATE_EDGE_HOLD_FRAC) {
      if (!this.hasRight) {
        this.hasRight = true;
        this.rightBase = viewEnd;
      }
      this.rightPushPx = this.rightPushPx + step;
    } else if (rawX <= CREATE_EDGE_ZONE_VP * CREATE_EDGE_HOLD_FRAC) {
      if (!this.hasLeft) {
        this.hasLeft = true;
        this.leftBase = viewStart;
      }
      this.leftPushPx = this.leftPushPx + step;
    }
    return this.probe(viewportW, viewStart, viewEnd, day0);
  }

  private updatePushes(
    rawX: number,
    viewportW: number,
    dx: number,
    viewStart: number,
    viewEnd: number
  ): void {
    const zone: number = CREATE_EDGE_ZONE_VP;
    const nearRight: boolean = rawX >= viewportW - zone;
    const nearLeft: boolean = rawX <= zone;
    if (nearRight) {
      if (!this.hasRight) {
        this.hasRight = true;
        this.rightBase = viewEnd;
        this.rightPushPx = 0;
      }
      const depth: number = rawX - (viewportW - zone);
      if (dx > 0) {
        this.rightPushPx = this.rightPushPx + dx;
      }
      if (depth > this.rightPushPx) {
        this.rightPushPx = depth;
      }
      if (rawX > viewportW) {
        const extra: number = rawX - viewportW + zone;
        if (extra > this.rightPushPx) {
          this.rightPushPx = extra;
        }
      }
    } else if (rawX < viewportW - zone * 1.5) {
      this.hasRight = false;
      this.rightPushPx = 0;
    }
    if (nearLeft) {
      if (!this.hasLeft) {
        this.hasLeft = true;
        this.leftBase = viewStart;
        this.leftPushPx = 0;
      }
      const depth: number = zone - rawX;
      if (dx < 0) {
        this.leftPushPx = this.leftPushPx + (-dx);
      }
      if (depth > this.leftPushPx) {
        this.leftPushPx = depth;
      }
      if (rawX < 0) {
        const extra: number = -rawX + zone;
        if (extra > this.leftPushPx) {
          this.leftPushPx = extra;
        }
      }
    } else if (rawX > zone * 1.5) {
      this.hasLeft = false;
      this.leftPushPx = 0;
    }
  }

  private probe(
    viewportW: number,
    viewStart: number,
    viewEnd: number,
    day0: number
  ): number | null {
    const maxEnd: number = day0 + kDayViewMaxSpanMinutes;
    const hx: number = hourWidth(viewportW, viewStart, viewEnd);
    if (this.hasRight && this.rightPushPx > 0) {
      return expandProbeFromOverscroll(day0, maxEnd, this.rightBase, hx, this.rightPushPx, true);
    }
    if (this.hasLeft && this.leftPushPx > 0) {
      return expandProbeFromOverscroll(day0, maxEnd, this.leftBase, hx, this.leftPushPx, false);
    }
    if (this.hasRight) {
      return expandProbeFromOverscroll(day0, maxEnd, this.rightBase, hx, 0, true);
    }
    if (this.hasLeft) {
      return expandProbeFromOverscroll(day0, maxEnd, this.leftBase, hx, 0, false);
    }
    return null;
  }
}
