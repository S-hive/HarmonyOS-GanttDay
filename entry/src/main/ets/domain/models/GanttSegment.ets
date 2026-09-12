export class GanttSegment {
  taskId: string;
  start: number;
  end: number;

  constructor(taskId: string, start: number, end: number) {
    this.taskId = taskId;
    this.start = start;
    this.end = end;
  }
}
