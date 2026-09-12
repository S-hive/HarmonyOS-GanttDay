import { TapClassifier, TapDecision, TapHit } from '../../domain/gesture/TapClassifier';
import { Task } from '../../domain/models/Task';
import { dateOnly, mondayOnOrBefore } from '../../domain/time/Calendar';
import { WallClock } from '../../domain/time/WallClock';
import { layoutWeekSlots, WeekSlot } from '../../domain/week/WeekColumnLayout';
import { MemoryTaskRepository } from '../../data/MemoryTaskRepository';
import { TaskListener, TaskRepository } from '../../platform/TaskRepository';
import { DeleteConfirm } from '../common/DeleteConfirm';
import { SideDrawer } from '../common/SideDrawer';
import { TaskForm, taskAfterFormClose } from '../task/TaskForm';
import { AppColors } from '../theme/AppColors';

export const WEEK_HOUR_HEIGHT: number = 48;
export const WEEK_GUTTER_WIDTH: number = 52;
export const WEEK_HEADER_HEIGHT: number = 36;
export const WEEK_DAY_HOURS: number = 24;
export const WEEK_DAY_BOUNDARY_GAP: number = 3;
export const WEEK_DAY_BOUNDARY_WIDTH: number = 1;
export const WEEK_DAY_BOUNDARY_STRIDE: number = WEEK_DAY_BOUNDARY_GAP * 2 + WEEK_DAY_BOUNDARY_WIDTH;
export const WEEK_SCROLL_START_HOUR: number = 8;
export const WEEK_DAY_BOUNDARY_COLOR: number = 0xFFC62828;
export const WEEK_BAR_RADIUS: number = 4;

const WEEKDAY_LABELS: string[] = ['一', '二', '三', '四', '五', '六', '日'];

export class WeekBlockRect {
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

export function weekBodyHeight(): number {
  return WEEK_DAY_HOURS * WEEK_HOUR_HEIGHT;
}

export function weekDefaultScrollY(): number {
  return WEEK_SCROLL_START_HOUR * WEEK_HOUR_HEIGHT;
}

export function weekScrollY(bodyViewportH: number): number {
  const target: number = weekDefaultScrollY();
  const max: number = weekBodyHeight() - bodyViewportH;
  if (max <= 0) {
    return 0;
  }
  if (target > max) {
    return max;
  }
  return target;
}

export function weekDayWidth(gridWidth: number): number {
  return (gridWidth - 6 * WEEK_DAY_BOUNDARY_STRIDE) / 7;
}

export function weekDayLeft(dayIndex: number, dayWidth: number): number {
  return dayIndex * (dayWidth + WEEK_DAY_BOUNDARY_STRIDE);
}

export function weekBlockRect(slot: WeekSlot, dayWidth: number): WeekBlockRect {
  const colW: number = dayWidth / slot.columnCount;
  return new WeekBlockRect(
    slot.taskId,
    weekDayLeft(slot.dayIndex, dayWidth) + slot.columnIndex * colW,
    slot.topFrac * WEEK_DAY_HOURS * WEEK_HOUR_HEIGHT,
    colW,
    slot.heightFrac * WEEK_DAY_HOURS * WEEK_HOUR_HEIGHT
  );
}

export function hitTestWeekBlock(rects: WeekBlockRect[], x: number, y: number): string | null {
  for (let i = rects.length - 1; i >= 0; i--) {
    const r: WeekBlockRect = rects[i];
    if (x >= r.x && x <= r.x + r.width && y >= r.y && y <= r.y + r.height) {
      return r.taskId;
    }
  }
  return null;
}

function hourRange(): number[] {
  const out: number[] = [];
  for (let h = 0; h < WEEK_DAY_HOURS; h++) {
    out.push(h);
  }
  return out;
}

function sameCalendarDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function argbToCss(argb: number): string {
  const a: number = ((argb >>> 24) & 0xFF) / 255;
  const r: number = (argb >> 16) & 0xFF;
  const g: number = (argb >> 8) & 0xFF;
  const b: number = argb & 0xFF;
  return `rgba(${r}, ${g}, ${b}, ${a})`;
}

function lengthVp(value: Length): number {
  return parseFloat(`${value}`);
}

function addRoundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  radius: number
): void {
  let rad: number = radius;
  if (rad * 2 > w) {
    rad = w / 2;
  }
  if (rad * 2 > h) {
    rad = h / 2;
  }
  ctx.moveTo(x + rad, y);
  ctx.lineTo(x + w - rad, y);
  ctx.arcTo(x + w, y, x + w, y + rad, rad);
  ctx.lineTo(x + w, y + h - rad);
  ctx.arcTo(x + w, y + h, x + w - rad, y + h, rad);
  ctx.lineTo(x + rad, y + h);
  ctx.arcTo(x, y + h, x, y + h - rad, rad);
  ctx.lineTo(x, y + rad);
  ctx.arcTo(x, y, x + rad, y, rad);
  ctx.closePath();
}

class PageTaskSink implements TaskListener {
  apply: (tasks: Task[]) => void = (_tasks: Task[]): void => {
  };

  onTasks(tasks: Task[]): void {
    this.apply(tasks);
  }
}

@Component
export struct WeekPage {
  repo: TaskRepository = new MemoryTaskRepository();
  @Prop date: Date = new Date();
  onOpenDay: (day: Date) => void = (_day: Date): void => {
  };
  @State canvasWidthVp: number = 700;
  @State viewportWidthVp: number = 800;
  @State viewportHeightVp: number = 400;
  @State drawerOpen: boolean = false;
  @State formTitle: string = '';
  @State formStart: number = 0;
  @State formEnd: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private scroller: Scroller = new Scroller();
  private sink: PageTaskSink = new PageTaskSink();
  private unwatch: () => void = (): void => {
  };
  private boundWeek0: number = -1;
  private cachedTasks: Task[] = [];
  private hitRects: WeekBlockRect[] = [];
  private titles: Map<string, string> = new Map<string, string>();
  private canvasReady: boolean = false;
  private didFitScroll: boolean = false;
  private hours: number[] = hourRange();
  private prevTap: TapHit | null = null;
  private prevTapMs: number = 0;
  private pendingHit: TapHit | null = null;
  private tapTimerId: number = -1;
  private formBase: Task | null = null;

  aboutToAppear(): void {
    this.sink.apply = (list: Task[]): void => {
      this.cachedTasks = list;
      this.redraw();
    };
    this.bindWatch();
  }

  aboutToUpdate(): void {
    const week0: number = this.week0Of();
    if (week0 !== this.boundWeek0) {
      this.bindWatch();
      this.didFitScroll = false;
      this.scrollToEight();
    }
  }

  aboutToDisappear(): void {
    this.cancelPendingTap();
    this.unwatch();
    this.unwatch = (): void => {
    };
    this.boundWeek0 = -1;
  }

  private weekMonday(): Date {
    return mondayOnOrBefore(this.date);
  }

  private week0Of(): number {
    return WallClock.minutes(dateOnly(this.weekMonday()));
  }

  private bindWatch(): void {
    this.unwatch();
    const week0: number = this.week0Of();
    this.boundWeek0 = week0;
    this.unwatch = this.repo.watchOverlapping(week0, week0 + 7 * WallClock.MINUTES_PER_DAY, this.sink);
  }

  private dateOfDay(dayIndex: number): Date {
    const monday: Date = this.weekMonday();
    return new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + dayIndex);
  }

  private headerLabel(dayIndex: number): string {
    const day: Date = this.dateOfDay(dayIndex);
    return `${WEEKDAY_LABELS[dayIndex]} ${day.getMonth() + 1}/${day.getDate()}`;
  }

  private dayIsToday(dayIndex: number): boolean {
    return sameCalendarDay(this.dateOfDay(dayIndex), new Date());
  }

  private todayIndex(): number {
    const monday: Date = this.weekMonday();
    const today: Date = dateOnly(new Date());
    const diff: number = Math.round((today.getTime() - monday.getTime()) / 86400000);
    return diff;
  }

  private findTask(id: string): Task | null {
    for (let i = 0; i < this.cachedTasks.length; i++) {
      if (this.cachedTasks[i].id === id) {
        return this.cachedTasks[i];
      }
    }
    return null;
  }

  private cancelPendingTap(): void {
    if (this.tapTimerId !== -1) {
      clearTimeout(this.tapTimerId);
      this.tapTimerId = -1;
    }
    this.prevTap = null;
    this.prevTapMs = 0;
    this.pendingHit = null;
  }

  private fireWaitTimeout(): void {
    this.tapTimerId = -1;
    const hit: TapHit | null = this.pendingHit;
    this.prevTap = null;
    this.prevTapMs = 0;
    this.pendingHit = null;
    if (hit === null) {
      return;
    }
    if (TapClassifier.onWaitTimeout(hit) === TapDecision.OpenForm && hit.taskId !== null) {
      this.openForm(hit.taskId);
    }
  }

  private toTapHit(taskId: string | null, x: number, y: number): TapHit {
    const hit: TapHit = new TapHit();
    hit.x = x;
    hit.y = y;
    hit.taskId = taskId;
    return hit;
  }

  private handleTapDecision(decision: TapDecision, curr: TapHit, nowMs: number): void {
    if (decision === TapDecision.Wait) {
      this.prevTap = curr;
      this.prevTapMs = nowMs;
      this.pendingHit = curr;
      this.tapTimerId = setTimeout(() => {
        this.fireWaitTimeout();
      }, TapClassifier.DOUBLE_MS);
      return;
    }
    this.cancelPendingTap();
    if (decision === TapDecision.Delete && curr.taskId !== null) {
      this.askDelete(curr.taskId);
    }
  }

  private openForm(taskId: string): void {
    const task: Task | null = this.findTask(taskId);
    if (task === null) {
      return;
    }
    this.formBase = task;
    this.formTitle = task.title;
    this.formStart = task.plannedStart;
    this.formEnd = task.plannedEnd;
    this.drawerOpen = true;
  }

  private closeDrawer(): void {
    const base: Task | null = this.formBase;
    this.drawerOpen = false;
    this.formBase = null;
    if (base === null) {
      return;
    }
    this.repo.upsert(taskAfterFormClose(base, this.formTitle, this.formStart, this.formEnd));
  }

  private async askDelete(taskId: string): Promise<void> {
    const task: Task | null = this.findTask(taskId);
    if (task === null) {
      return;
    }
    const ok: boolean = await DeleteConfirm.show(task.title);
    if (!ok) {
      return;
    }
    if (this.formBase !== null && this.formBase.id === taskId) {
      this.drawerOpen = false;
      this.formBase = null;
    }
    await this.repo.delete(taskId);
  }

  private deleteFromForm(): void {
    const base: Task | null = this.formBase;
    this.drawerOpen = false;
    this.formBase = null;
    if (base === null) {
      return;
    }
    this.repo.delete(base.id);
  }

  private rebuildRects(): void {
    const dayWidth: number = weekDayWidth(this.canvasWidthVp);
    const slots: WeekSlot[] = layoutWeekSlots(this.weekMonday(), this.cachedTasks);
    const rects: WeekBlockRect[] = [];
    this.titles = new Map<string, string>();
    for (let i = 0; i < slots.length; i++) {
      const s: WeekSlot = slots[i];
      this.titles.set(s.taskId, s.title);
      rects.push(weekBlockRect(s, dayWidth));
    }
    this.hitRects = rects;
  }

  private scrollToEight(): void {
    if (this.didFitScroll) {
      return;
    }
    const bodyH: number = this.viewportHeightVp - WEEK_HEADER_HEIGHT;
    if (bodyH <= 0) {
      return;
    }
    this.didFitScroll = true;
    this.scroller.scrollTo({
      xOffset: 0,
      yOffset: weekScrollY(bodyH),
      animation: false
    });
  }

  private applyViewport(width: number, height: number): void {
    if (width <= 0 || height <= 0) {
      return;
    }
    const sizeChanged: boolean = width !== this.viewportWidthVp || height !== this.viewportHeightVp;
    this.viewportWidthVp = width;
    this.viewportHeightVp = height;
    let grid: number = width - WEEK_GUTTER_WIDTH;
    if (grid < 1) {
      grid = 1;
    }
    this.canvasWidthVp = grid;
    if (sizeChanged) {
      this.didFitScroll = false;
    }
    this.scrollToEight();
    this.redraw();
  }

  private redraw(): void {
    if (!this.canvasReady) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.ctx;
    const cw: number = ctx.width;
    const ch: number = ctx.height;
    const bodyH: number = weekBodyHeight();
    if (cw <= 0 || ch <= 0 || this.canvasWidthVp <= 0) {
      return;
    }
    this.rebuildRects();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, cw, ch);
    const sx: number = cw / this.canvasWidthVp;
    const sy: number = ch / bodyH;
    ctx.setTransform(sx, 0, 0, sy, 0, 0);
    this.paintGrid(ctx);
    this.paintBlocks(ctx);
    this.paintNowLine(ctx);
  }

  private paintGrid(ctx: CanvasRenderingContext2D): void {
    const width: number = this.canvasWidthVp;
    const bodyH: number = weekBodyHeight();
    const dayWidth: number = weekDayWidth(width);
    const today: number = this.todayIndex();
    if (today >= 0 && today < 7) {
      ctx.fillStyle = 'rgba(69, 123, 217, 0.06)';
      ctx.fillRect(weekDayLeft(today, dayWidth), 0, dayWidth, bodyH);
    }
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.08)';
    ctx.lineWidth = 1;
    for (let h = 0; h <= WEEK_DAY_HOURS; h++) {
      const y: number = h * WEEK_HOUR_HEIGHT;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }
    ctx.fillStyle = argbToCss(WEEK_DAY_BOUNDARY_COLOR);
    for (let d = 1; d < 7; d++) {
      const x: number = weekDayLeft(d, dayWidth) - WEEK_DAY_BOUNDARY_STRIDE + WEEK_DAY_BOUNDARY_GAP;
      ctx.fillRect(x, 0, WEEK_DAY_BOUNDARY_WIDTH, bodyH);
    }
  }

  private paintBlocks(ctx: CanvasRenderingContext2D): void {
    for (let i = 0; i < this.hitRects.length; i++) {
      const b: WeekBlockRect = this.hitRects[i];
      let w: number = b.width;
      let h: number = b.height;
      if (w < 2) {
        w = 2;
      }
      if (h < 2) {
        h = 2;
      }
      ctx.fillStyle = argbToCss(AppColors.AZURE);
      ctx.beginPath();
      addRoundRect(ctx, b.x, b.y, w, h, WEEK_BAR_RADIUS);
      ctx.fill();
      const title: string | undefined = this.titles.get(b.taskId);
      const label: string = title === undefined ? '' : title;
      ctx.save();
      ctx.beginPath();
      ctx.rect(b.x, b.y, w, h);
      ctx.clip();
      ctx.fillStyle = '#FFFFFF';
      ctx.font = '12px sans-serif';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'top';
      ctx.fillText(label, b.x + 4, b.y + 4);
      ctx.restore();
    }
  }

  private paintNowLine(ctx: CanvasRenderingContext2D): void {
    const today: number = this.todayIndex();
    if (today < 0 || today > 6) {
      return;
    }
    const now: Date = new Date();
    const y: number = (now.getHours() * 60 + now.getMinutes()) / WallClock.MINUTES_PER_DAY * weekBodyHeight();
    const dayWidth: number = weekDayWidth(this.canvasWidthVp);
    const x: number = weekDayLeft(today, dayWidth);
    ctx.fillStyle = argbToCss(WEEK_DAY_BOUNDARY_COLOR);
    ctx.fillRect(x, y - 0.5, dayWidth, 1);
  }

  private onCanvasTouch(event: TouchEvent): void {
    const point: TouchObject | undefined = event.type === TouchType.Up || event.type === TouchType.Cancel ?
      event.changedTouches[0] : event.touches[0];
    if (point === undefined) {
      return;
    }
    const x: number = point.x;
    const y: number = point.y;
    if (event.type === TouchType.Down) {
      const taskId: string | null = hitTestWeekBlock(this.hitRects, x, y);
      if (taskId === null) {
        this.cancelPendingTap();
        return;
      }
      event.stopPropagation();
      if (this.tapTimerId !== -1) {
        clearTimeout(this.tapTimerId);
        this.tapTimerId = -1;
      }
      const curr: TapHit = this.toTapHit(taskId, x, y);
      const nowMs: number = Date.now();
      const decision: TapDecision = TapClassifier.onDown(this.prevTap, this.prevTapMs, curr, nowMs);
      this.handleTapDecision(decision, curr, nowMs);
      return;
    }
    if (event.type === TouchType.Move && this.pendingHit !== null) {
      const dx: number = x - this.pendingHit.x;
      const dy: number = y - this.pendingHit.y;
      if (Math.hypot(dx, dy) > TapClassifier.HIT_SLOP_VP) {
        this.cancelPendingTap();
      }
    }
  }

  @Builder
  boundaryMark() {
    Row() {
      Column()
        .width(WEEK_DAY_BOUNDARY_GAP)
      Column()
        .width(WEEK_DAY_BOUNDARY_WIDTH)
        .height('100%')
        .backgroundColor(WEEK_DAY_BOUNDARY_COLOR)
      Column()
        .width(WEEK_DAY_BOUNDARY_GAP)
    }
    .width(WEEK_DAY_BOUNDARY_STRIDE)
    .height('100%')
  }

  @Builder
  headerDay(dayIndex: number) {
    Column() {
      Text(this.headerLabel(dayIndex))
        .fontSize(12)
        .fontWeight(this.dayIsToday(dayIndex) ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.dayIsToday(dayIndex) ? AppColors.AZURE : Color.Black)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onOpenDay(this.dateOfDay(dayIndex));
    })
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Column()
            .width(WEEK_GUTTER_WIDTH)
            .height(WEEK_HEADER_HEIGHT)
          this.headerDay(0)
          this.boundaryMark()
          this.headerDay(1)
          this.boundaryMark()
          this.headerDay(2)
          this.boundaryMark()
          this.headerDay(3)
          this.boundaryMark()
          this.headerDay(4)
          this.boundaryMark()
          this.headerDay(5)
          this.boundaryMark()
          this.headerDay(6)
        }
        .width('100%')
        .height(WEEK_HEADER_HEIGHT)

        Scroll(this.scroller) {
          Row() {
            Column() {
              ForEach(this.hours, (h: number) => {
                Text(`${h}:00`)
                  .fontSize(11)
                  .fontColor(AppColors.ON_SURFACE_MUTED)
                  .width(WEEK_GUTTER_WIDTH)
                  .height(WEEK_HOUR_HEIGHT)
                  .textAlign(TextAlign.End)
                  .padding({ right: 6, top: 2 })
              }, (h: number) => `${h}`)
            }
            .width(WEEK_GUTTER_WIDTH)
            .height(weekBodyHeight())

            Canvas(this.ctx)
              .width(this.canvasWidthVp)
              .height(weekBodyHeight())
              .onReady(() => {
                this.canvasReady = true;
                this.redraw();
              })
              .onTouch((event: TouchEvent) => {
                this.onCanvasTouch(event);
              })
          }
          .width('100%')
          .height(weekBodyHeight())
          .alignItems(VerticalAlign.Top)
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .onAreaChange((_old: Area, area: Area) => {
        this.applyViewport(lengthVp(area.width), lengthVp(area.height));
      })

      if (this.drawerOpen) {
        SideDrawer({
          screenWidth: this.viewportWidthVp,
          onClose: () => {
            this.closeDrawer();
          }
        }) {
          TaskForm({
            title: $formTitle,
            plannedStart: $formStart,
            plannedEnd: $formEnd,
            onDelete: () => {
              this.deleteFromForm();
            }
          })
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
