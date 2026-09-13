import { Task } from '../models/Task';

export const LONG_PRESS_MS: number = 350;

export class ActualEditLanes {
  planned: number;
  actual: number;

  constructor(planned: number, actual: number) {
    this.planned = planned;
    this.actual = actual;
  }
}

export function actualEditLanePair(planned0: number, hasActual: boolean, capacity: number): ActualEditLanes {
  if (!hasActual) {
    return new ActualEditLanes(planned0, planned0);
  }
  const below: number = planned0 + 1;
  if (below < capacity) {
    return new ActualEditLanes(planned0, below);
  }
  if (planned0 > 0) {
    return new ActualEditLanes(planned0, planned0 - 1);
  }
  return new ActualEditLanes(1, 0);
}

export class PlannedStrip {
  x: number;
  y: number;
  width: number;
  height: number;

  constructor(x: number, y: number, width: number, height: number) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }
}

export function plannedInnerStrip(
  _outerX: number,
  outerY: number,
  _outerW: number,
  outerH: number,
  plannedX: number,
  plannedW: number
): PlannedStrip {
  let h: number = outerH * 0.28;
  if (h < 4) {
    h = 4;
  }
  let w: number = plannedW;
  if (w < 2) {
    w = 2;
  }
  return new PlannedStrip(plannedX, outerY + outerH - h, w, h);
}

export function dayBarUsesActual(task: Task, editingActual: boolean): boolean {
  return !editingActual && task.isDone && task.actualStart !== null && task.actualEnd !== null;
}

export function dayBarSpanStart(task: Task, editingActual: boolean): number {
  if (dayBarUsesActual(task, editingActual) && task.actualStart !== null) {
    return task.actualStart;
  }
  return task.plannedStart;
}

export function dayBarSpanEnd(task: Task, editingActual: boolean): number {
  if (dayBarUsesActual(task, editingActual) && task.actualEnd !== null) {
    return task.actualEnd;
  }
  return task.plannedEnd;
}

export function actualEditBannerText(title: string, isDone: boolean): string {
  const uncomplete: string = isDone ? '长按实际条取消完成　·　' : '';
  return `设置实际时间：${title}　·　可在任意行长按拖拽　·　${uncomplete}返回退出`;
}

let actualEditCloser: (() => void) | null = null;

export function bindActualEditCloser(closer: (() => void) | null): void {
  actualEditCloser = closer;
}

export function consumeActualEditBack(): boolean {
  if (actualEditCloser === null) {
    return false;
  }
  actualEditCloser();
  return true;
}
