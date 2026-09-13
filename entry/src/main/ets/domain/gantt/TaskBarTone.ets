import { Task } from '../models/Task';
import { AppColors } from '../../ui/theme/AppColors';

export function taskBarArgb(isDone: boolean, _plannedStart: number, plannedEnd: number, now: number): number {
  if (isDone) {
    return AppColors.AZURE;
  }
  if (plannedEnd < now) {
    return AppColors.PLANNED_GRAY;
  }
  return AppColors.AZURE;
}

export function taskBarArgbFromTask(task: Task, now: number): number {
  return taskBarArgb(task.isDone, task.plannedStart, task.plannedEnd, now);
}

export function taskBarLabelArgb(fill: number): number {
  if (fill === AppColors.PLANNED_GRAY) {
    return 0xDE000000;
  }
  return 0xFFFFFFFF;
}
