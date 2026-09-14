import { Task } from '../models/Task';
import { AppColors } from '../../ui/theme/AppColors';
import { FactorySwatches } from './FactorySwatches';

export function resolvedSwatchArgb(task: Task): number {
  const overrideId: string | null = task.overrideSwatchId;
  if (overrideId !== null && overrideId.length > 0) {
    return FactorySwatches.argbOf(overrideId);
  }
  return FactorySwatches.argbOf(task.autoSwatchId);
}

export function taskBarArgb(
  isDone: boolean,
  _plannedStart: number,
  plannedEnd: number,
  now: number,
  originalArgb: number
): number {
  if (!isDone && plannedEnd < now) {
    return AppColors.PLANNED_GRAY;
  }
  return originalArgb;
}

export function taskBarArgbFromTask(task: Task, now: number): number {
  return taskBarArgb(task.isDone, task.plannedStart, task.plannedEnd, now, resolvedSwatchArgb(task));
}

export function taskBarLabelArgb(fill: number): number {
  const r: number = (fill >>> 16) & 0xFF;
  const g: number = (fill >>> 8) & 0xFF;
  const b: number = fill & 0xFF;
  const lum: number = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
  if (lum > 0.65) {
    return 0xDE000000;
  }
  return 0xFFFFFFFF;
}
