export class TapHit {
  x: number = 0;
  y: number = 0;
  taskId: string | null = null;
}

export enum TapDecision {
  Wait = 0,
  OpenForm = 1,
  Create = 2,
  Ignore = 3
}

export class TapClassifier {
  static readonly HIT_SLOP_VP: number = 32;
  static readonly DOUBLE_MS: number = 250;

  static onDown(prev: TapHit | null, prevMs: number, curr: TapHit, nowMs: number): TapDecision {
    if (prev === null || nowMs - prevMs > TapClassifier.DOUBLE_MS) {
      return TapDecision.Wait;
    }

    if (prev.taskId !== null && curr.taskId !== null) {
      return TapDecision.Wait;
    }

    if (prev.taskId === null && curr.taskId === null) {
      const dx = curr.x - prev.x;
      const dy = curr.y - prev.y;
      if (Math.hypot(dx, dy) <= TapClassifier.HIT_SLOP_VP) {
        return TapDecision.Create;
      }
    }

    return TapDecision.Ignore;
  }

  static onWaitTimeout(hit: TapHit): TapDecision {
    if (hit.taskId !== null) {
      return TapDecision.OpenForm;
    }
    return TapDecision.Ignore;
  }

  static shouldOpenDeleteVeilOnRelease(
    taskId: string | null,
    wasDragging: boolean,
    actualEditActive: boolean,
    longPressFired: boolean
  ): boolean {
    return taskId !== null && !wasDragging && !actualEditActive && !longPressFired;
  }

  static shouldOpenDeleteVeilOnWaitTimeout(
    pointerDown: boolean,
    longPressPending: boolean,
    actualEditActive: boolean
  ): boolean {
    return !pointerDown && !longPressPending && !actualEditActive;
  }
}
