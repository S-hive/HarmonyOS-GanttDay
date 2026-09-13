export const END_CANCEL: number = 0;
export const END_POPUP: number = 1;

const PHASE_IDLE: number = 0;
const PHASE_DRAG: number = 1;

export class CreateStroke {
  static readonly MIN_DRAG_VP: number = 4;
  private startX: number = 0;
  private lastX: number = 0;
  private phase: number = PHASE_IDLE;

  begin(x: number): void {
    this.startX = x;
    this.lastX = x;
    this.phase = PHASE_DRAG;
  }

  move(x: number): boolean {
    if (this.phase !== PHASE_DRAG) {
      return false;
    }
    this.lastX = x;
    return true;
  }

  x0(): number {
    return this.startX;
  }

  x1(): number {
    return this.lastX;
  }

  finish(): number {
    if (this.phase !== PHASE_DRAG) {
      return END_CANCEL;
    }
    this.phase = PHASE_IDLE;
    if (Math.abs(this.lastX - this.startX) < CreateStroke.MIN_DRAG_VP) {
      return END_CANCEL;
    }
    return END_POPUP;
  }

  abort(): void {
    this.phase = PHASE_IDLE;
  }

  isDragging(): boolean {
    return this.phase === PHASE_DRAG;
  }
}
