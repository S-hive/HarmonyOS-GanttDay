import { GanttGeometry } from '../../domain/gantt/GanttGeometry';
import { Task } from '../../domain/models/Task';
import { WallClock } from '../../domain/time/WallClock';
import { DeleteConfirm } from '../common/DeleteConfirm';

export function taskAfterFormClose(existing: Task, title: string, start: number, end: number): Task {
  let plannedEnd: number = end;
  if (plannedEnd < start + GanttGeometry.MIN_DURATION_MINUTES) {
    plannedEnd = start + GanttGeometry.MIN_DURATION_MINUTES;
  }
  const trimmed: string = title.trim();
  if (trimmed.length > 0) {
    return existing.copyWith(trimmed, start, plannedEnd);
  }
  return existing.copyWith(undefined, start, plannedEnd);
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

export function formatPlanDateTime(minutes: number): string {
  const d: Date = WallClock.dateTime(minutes);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

@Component
export struct TaskForm {
  @Link title: string;
  @Link plannedStart: number;
  @Link plannedEnd: number;
  onDelete: () => void = () => {
  };

  private nudgeStart(delta: number): void {
    this.plannedStart = this.plannedStart + delta;
    if (this.plannedEnd < this.plannedStart + GanttGeometry.MIN_DURATION_MINUTES) {
      this.plannedEnd = this.plannedStart + GanttGeometry.MIN_DURATION_MINUTES;
    }
  }

  private nudgeEnd(delta: number): void {
    let next: number = this.plannedEnd + delta;
    if (next < this.plannedStart + GanttGeometry.MIN_DURATION_MINUTES) {
      next = this.plannedStart + GanttGeometry.MIN_DURATION_MINUTES;
    }
    this.plannedEnd = next;
  }

  private async confirmDelete(): Promise<void> {
    const ok: boolean = await DeleteConfirm.show(this.title);
    if (ok) {
      this.onDelete();
    }
  }

  build() {
    Column() {
      Text('任务')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 16 })
      Text('标题')
        .fontSize(13)
        .fontColor(0x73000000)
        .width('100%')
      TextInput({ text: this.title, placeholder: '标题' })
        .margin({ top: 6, bottom: 16 })
        .onChange((value: string) => {
          this.title = value;
        })
      Text('计划开始')
        .fontSize(13)
        .fontColor(0x73000000)
        .width('100%')
      Row() {
        Text(formatPlanDateTime(this.plannedStart))
          .fontSize(16)
          .layoutWeight(1)
        Button('−15', { type: ButtonType.Normal })
          .height(32)
          .onClick(() => {
            this.nudgeStart(-GanttGeometry.SNAP_MINUTES);
          })
        Button('+15', { type: ButtonType.Normal })
          .height(32)
          .margin({ left: 8 })
          .onClick(() => {
            this.nudgeStart(GanttGeometry.SNAP_MINUTES);
          })
      }
      .width('100%')
      .margin({ top: 6, bottom: 16 })
      .alignItems(VerticalAlign.Center)
      Text('计划结束')
        .fontSize(13)
        .fontColor(0x73000000)
        .width('100%')
      Row() {
        Text(formatPlanDateTime(this.plannedEnd))
          .fontSize(16)
          .layoutWeight(1)
        Button('−15', { type: ButtonType.Normal })
          .height(32)
          .onClick(() => {
            this.nudgeEnd(-GanttGeometry.SNAP_MINUTES);
          })
        Button('+15', { type: ButtonType.Normal })
          .height(32)
          .margin({ left: 8 })
          .onClick(() => {
            this.nudgeEnd(GanttGeometry.SNAP_MINUTES);
          })
      }
      .width('100%')
      .margin({ top: 6, bottom: 24 })
      .alignItems(VerticalAlign.Center)
      Blank()
      Button('删除', { type: ButtonType.Normal })
        .width('100%')
        .backgroundColor(0xFFFFE5E5)
        .fontColor(Color.Red)
        .onClick(() => {
          this.confirmDelete();
        })
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }
}
