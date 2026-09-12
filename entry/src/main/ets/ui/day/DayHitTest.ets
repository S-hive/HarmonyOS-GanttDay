export const HIT_MOVE: string = 'move';
export const HIT_RESIZE_START: string = 'resizeStart';
export const HIT_RESIZE_END: string = 'resizeEnd';
export const HIT_EMPTY: string = 'empty';

export const DEFAULT_EDGE_SLOP: number = 8;

export class HitBar {
  taskId: string;
  x: number;
  y: number;
  width: number;
  height: number;

  constructor(taskId: string, x: number, y: number, width: number, height: number) {
    this.taskId = taskId;
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }
}

export class HitResult {
  taskId: string | null;
  kind: string;

  constructor(taskId: string | null, kind: string) {
    this.taskId = taskId;
    this.kind = kind;
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
      return new HitResult(b.taskId, HIT_RESIZE_START);
    }
    if (Math.abs(x - (b.x + b.width)) <= edgeSlop) {
      return new HitResult(b.taskId, HIT_RESIZE_END);
    }
    return new HitResult(b.taskId, HIT_MOVE);
  }
  return new HitResult(null, HIT_EMPTY);
}
