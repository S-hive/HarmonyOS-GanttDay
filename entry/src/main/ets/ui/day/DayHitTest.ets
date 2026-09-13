export const HIT_MOVE: string = 'move';
export const HIT_RESIZE_START: string = 'resizeStart';
export const HIT_RESIZE_END: string = 'resizeEnd';
export const HIT_EMPTY: string = 'empty';

export const DEFAULT_EDGE_SLOP: number = 8;
export const DAY_DRAG_START_SLOP: number = 32;

export function canvasXFromTouch(touchX: number, scrollX: number, canvasWidth: number): number {
  const shifted: number = touchX + scrollX;
  if (scrollX > 0 && touchX + 0.5 < scrollX && shifted <= canvasWidth) {
    return shifted;
  }
  return touchX;
}

export function movementExceedsSlop(dx: number, dy: number, windowDx: number, slop: number): boolean {
  return Math.hypot(dx, dy) > slop || Math.abs(windowDx) > slop;
}

export function shouldCancelDoubleTapOnMove(pendingTaskId: string | null): boolean {
  return pendingTaskId !== null;
}

export function laneIndexFromY(y: number, headerHeight: number, laneHeight: number): number {
  if (laneHeight <= 0) {
    return 0;
  }
  const row: number = Math.floor((y - headerHeight) / laneHeight);
  if (row < 0) {
    return 0;
  }
  return row;
}

export function snapshotTaskLanes(
  bars: HitBar[],
  headerHeight: number,
  laneHeight: number
): Map<string, number> {
  const out: Map<string, number> = new Map<string, number>();
  for (let i = 0; i < bars.length; i++) {
    const b: HitBar = bars[i];
    out.set(b.taskId, laneIndexFromY(b.y, headerHeight, laneHeight));
  }
  return out;
}

export class HitBar {
  taskId: string;
  x: number;
  y: number;
  width: number;
  height: number;
  trueStart: boolean;
  trueEnd: boolean;
  isActual: boolean;

  constructor(
    taskId: string,
    x: number,
    y: number,
    width: number,
    height: number,
    trueStart: boolean = true,
    trueEnd: boolean = true,
    isActual: boolean = false
  ) {
    this.taskId = taskId;
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
    this.trueStart = trueStart;
    this.trueEnd = trueEnd;
    this.isActual = isActual;
  }
}

export class HitResult {
  taskId: string | null;
  kind: string;
  isActual: boolean;

  constructor(taskId: string | null, kind: string, isActual: boolean = false) {
    this.taskId = taskId;
    this.kind = kind;
    this.isActual = isActual;
  }
}

export function hitTest(bars: HitBar[], x: number, y: number, edgeSlop: number = DEFAULT_EDGE_SLOP): HitResult {
  for (let i = bars.length - 1; i >= 0; i--) {
    const b: HitBar = bars[i];
    const left: number = b.x - edgeSlop;
    const right: number = b.x + b.width + edgeSlop;
    if (x < left || x > right || y < b.y || y > b.y + b.height) {
      continue;
    }
    if (Math.abs(x - b.x) <= edgeSlop) {
      return new HitResult(b.taskId, b.trueStart ? HIT_RESIZE_START : HIT_MOVE, b.isActual);
    }
    if (Math.abs(x - (b.x + b.width)) <= edgeSlop) {
      return new HitResult(b.taskId, b.trueEnd ? HIT_RESIZE_END : HIT_MOVE, b.isActual);
    }
    return new HitResult(b.taskId, HIT_MOVE, b.isActual);
  }
  return new HitResult(null, HIT_EMPTY, false);
}
