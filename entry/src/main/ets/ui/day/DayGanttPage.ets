import { GanttGeometry } from '../../domain/gantt/GanttGeometry';
import { DaySegmenter } from '../../domain/gantt/DaySegmenter';
import { LaneLayout } from '../../domain/gantt/LaneLayout';
import { kDayViewMaxSpanMinutes } from '../../domain/gantt/DayVisibleRange';
import { proposeMove, proposeResizeEnd, proposeResizeStart } from '../../domain/gantt/DayGestureMath';
import { GanttSegment } from '../../domain/models/GanttSegment';
import { Task } from '../../domain/models/Task';
import { dateOnly } from '../../domain/time/Calendar';
import { WallClock } from '../../domain/time/WallClock';
import { MemoryTaskRepository } from '../../data/MemoryTaskRepository';
import { TaskListener, TaskRepository } from '../../platform/TaskRepository';
import { AppColors } from '../theme/AppColors';
import {
  DEFAULT_EDGE_SLOP,
  HIT_EMPTY,
  HIT_MOVE,
  HIT_RESIZE_END,
  HIT_RESIZE_START,
  HitBar,
  hitTest
} from './DayHitTest';

const FIT_START_HOUR: number = 8;
const FIT_END_HOUR: number = 22;
const DAY_HOURS: number = 24;
const HEADER_HEIGHT: number = 32;
const LANE_HEIGHT: number = 28;
const BAR_HEIGHT: number = 20;
const BAR_GAP: number = 4;
const BAR_RADIUS: number = 4;

class PageTaskSink implements TaskListener {
  apply: (tasks: Task[]) => void = (_tasks: Task[]): void => {
  };

  onTasks(tasks: Task[]): void {
    this.apply(tasks);
  }
}

function argbToCss(argb: number): string {
  const a: number = ((argb >>> 24) & 0xFF) / 255;
  const r: number = (argb >> 16) & 0xFF;
  const g: number = (argb >> 8) & 0xFF;
  const b: number = argb & 0xFF;
  return `rgba(${r}, ${g}, ${b}, ${a})`;
}

function canvasWidthFor(viewportW: number): number {
  const fitHours: number = FIT_END_HOUR - FIT_START_HOUR;
  if (viewportW <= 0) {
    return 1;
  }
  return viewportW * DAY_HOURS / fitHours;
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
  let r: number = radius;
  if (r * 2 > w) {
    r = w / 2;
  }
  if (r * 2 > h) {
    r = h / 2;
  }
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r);
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  ctx.lineTo(x + r, y + h);
  ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r);
  ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
}

@Component
export struct DayGanttPage {
  repo: TaskRepository = new MemoryTaskRepository();
  @Prop date: Date = new Date();
  @State canvasWidthVp: number = 1400;
  @State viewportWidthVp: number = 800;
  @State viewportHeightVp: number = 400;
  @State axisScrollable: ScrollDirection = ScrollDirection.Horizontal;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private scroller: Scroller = new Scroller();
  private sink: PageTaskSink = new PageTaskSink();
  private unwatch: () => void = (): void => {
  };
  private boundDay0: number = -1;
  private cachedTasks: Task[] = [];
  private hitBars: HitBar[] = [];
  private titles: Map<string, string> = new Map<string, string>();
  private canvasReady: boolean = false;
  private didFitScroll: boolean = false;
  private dragging: boolean = false;
  private dragKind: string = HIT_EMPTY;
  private dragTask: Task | null = null;
  private grabX: number = 0;
  private startWindowX: number = 0;
  private startScrollX: number = 0;
  private preview: Task | null = null;

  aboutToAppear(): void {
    this.sink.apply = (list: Task[]): void => {
      this.cachedTasks = list;
      this.redraw();
    };
    this.bindWatch();
  }

  aboutToUpdate(): void {
    const day0: number = this.day0Of();
    if (day0 !== this.boundDay0) {
      this.bindWatch();
      this.didFitScroll = false;
      this.scrollToFit();
    }
  }

  aboutToDisappear(): void {
    this.unwatch();
    this.unwatch = (): void => {
    };
    this.boundDay0 = -1;
  }

  private day0Of(): number {
    return WallClock.minutes(dateOnly(this.date));
  }

  private bindWatch(): void {
    this.unwatch();
    const day0: number = this.day0Of();
    this.boundDay0 = day0;
    this.unwatch = this.repo.watchOverlapping(day0, day0 + WallClock.MINUTES_PER_DAY, this.sink);
  }

  private drawGeo(): GanttGeometry {
    return new GanttGeometry(this.day0Of(), this.day0Of() + WallClock.MINUTES_PER_DAY, this.canvasWidthVp);
  }

  private gestureGeo(): GanttGeometry {
    const span: number = kDayViewMaxSpanMinutes;
    return new GanttGeometry(this.day0Of(), this.day0Of() + span,
      this.canvasWidthVp * span / WallClock.MINUTES_PER_DAY);
  }

  private findTask(id: string): Task | null {
    for (let i = 0; i < this.cachedTasks.length; i++) {
      if (this.cachedTasks[i].id === id) {
        return this.cachedTasks[i];
      }
    }
    return null;
  }

  private tasksForDraw(): Task[] {
    if (this.preview === null) {
      return this.cachedTasks;
    }
    const out: Task[] = [];
    for (let i = 0; i < this.cachedTasks.length; i++) {
      if (this.cachedTasks[i].id === this.preview.id) {
        out.push(this.preview);
      } else {
        out.push(this.cachedTasks[i]);
      }
    }
    return out;
  }

  private rebuildBars(geo: GanttGeometry): void {
    const day0: number = this.day0Of();
    const segs: GanttSegment[] = [];
    this.titles = new Map<string, string>();
    const shown: Task[] = this.tasksForDraw();
    for (let i = 0; i < shown.length; i++) {
      const task: Task = shown[i];
      this.titles.set(task.id, task.title);
      const clip: GanttSegment[] = DaySegmenter.segmentsForDay(task, day0);
      for (let j = 0; j < clip.length; j++) {
        segs.push(clip[j]);
      }
    }
    const lanes: Map<string, number> = LaneLayout.assign(segs);
    const bars: HitBar[] = [];
    for (let k = 0; k < segs.length; k++) {
      const seg: GanttSegment = segs[k];
      const lane: number | undefined = lanes.get(LaneLayout.keyOf(seg));
      const row: number = lane === undefined ? 0 : lane;
      const x: number = geo.xOf(seg.start);
      let w: number = geo.xOf(seg.end) - x;
      if (w < 2) {
        w = 2;
      }
      const y: number = HEADER_HEIGHT + row * LANE_HEIGHT + BAR_GAP;
      bars.push(new HitBar(seg.taskId, x, y, w, BAR_HEIGHT));
    }
    this.hitBars = bars;
  }

  private scrollToFit(): void {
    if (this.didFitScroll || this.canvasWidthVp <= 0) {
      return;
    }
    this.didFitScroll = true;
    this.scroller.scrollTo({
      xOffset: this.canvasWidthVp * FIT_START_HOUR / DAY_HOURS,
      yOffset: 0,
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
    this.canvasWidthVp = canvasWidthFor(width);
    if (sizeChanged) {
      this.didFitScroll = false;
    }
    this.scrollToFit();
    this.redraw();
  }

  private redraw(): void {
    if (!this.canvasReady) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.ctx;
    const cw: number = ctx.width;
    const ch: number = ctx.height;
    if (cw <= 0 || ch <= 0 || this.canvasWidthVp <= 0 || this.viewportHeightVp <= 0) {
      return;
    }
    const geo: GanttGeometry = this.drawGeo();
    this.rebuildBars(geo);
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, cw, ch);
    const sx: number = cw / this.canvasWidthVp;
    const sy: number = ch / this.viewportHeightVp;
    ctx.setTransform(sx, 0, 0, sy, 0, 0);
    this.paintGrid(ctx, geo);
    this.paintBars(ctx);
    this.paintNowLine(ctx, geo);
  }

  private paintGrid(ctx: CanvasRenderingContext2D, geo: GanttGeometry): void {
    const width: number = this.canvasWidthVp;
    const height: number = this.viewportHeightVp;
    const rowCount: number = Math.max(LaneLayout.laneCount(this.laneMapFromBars()),
      Math.ceil(Math.max(0, height - HEADER_HEIGHT) / LANE_HEIGHT));
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.08)';
    ctx.lineWidth = 1;
    for (let r = 0; r <= rowCount; r++) {
      const y: number = HEADER_HEIGHT + r * LANE_HEIGHT;
      if (y > height) {
        break;
      }
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }

    const hourPx: number = width / DAY_HOURS;
    const day0: number = this.day0Of();
    for (let h = 0; h <= DAY_HOURS; h++) {
      const x: number = geo.xOf(day0 + h * 60);
      const emphasized: boolean = h % 6 === 0;
      ctx.strokeStyle = emphasized ? 'rgba(0, 0, 0, 0.14)' : 'rgba(0, 0, 0, 0.07)';
      ctx.beginPath();
      ctx.moveTo(x, HEADER_HEIGHT);
      ctx.lineTo(x, height);
      ctx.stroke();
      ctx.fillStyle = 'rgba(0, 0, 0, 0.55)';
      ctx.font = '11px sans-serif';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'top';
      ctx.fillText(`${h}:00`, x + 4, 8);
    }

    if (hourPx > 40) {
      ctx.strokeStyle = 'rgba(0, 0, 0, 0.04)';
      for (let h = 0; h < DAY_HOURS; h++) {
        const base: number = geo.xOf(day0 + h * 60);
        for (let q = 1; q < 4; q++) {
          const x: number = base + hourPx * q / 4;
          ctx.beginPath();
          ctx.moveTo(x, HEADER_HEIGHT);
          ctx.lineTo(x, height);
          ctx.stroke();
        }
      }
    }
  }

  private laneMapFromBars(): Map<string, number> {
    const lanes: Map<string, number> = new Map<string, number>();
    for (let i = 0; i < this.hitBars.length; i++) {
      const b: HitBar = this.hitBars[i];
      const lane: number = Math.round((b.y - HEADER_HEIGHT - BAR_GAP) / LANE_HEIGHT);
      lanes.set(`${b.taskId}:${i}`, lane);
    }
    return lanes;
  }

  private paintBars(ctx: CanvasRenderingContext2D): void {
    for (let i = 0; i < this.hitBars.length; i++) {
      const b: HitBar = this.hitBars[i];
      ctx.fillStyle = argbToCss(AppColors.AZURE);
      ctx.beginPath();
      addRoundRect(ctx, b.x, b.y, b.width, b.height, BAR_RADIUS);
      ctx.fill();
      const title: string | undefined = this.titles.get(b.taskId);
      const label: string = title === undefined ? '' : title;
      ctx.save();
      ctx.beginPath();
      ctx.rect(b.x, b.y, b.width, b.height);
      ctx.clip();
      ctx.fillStyle = '#FFFFFF';
      ctx.font = '13px sans-serif';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      ctx.fillText(label, b.x + 6, b.y + b.height / 2);
      ctx.restore();
    }
  }

  private paintNowLine(ctx: CanvasRenderingContext2D, geo: GanttGeometry): void {
    const now: number = WallClock.minutes(new Date());
    const day0: number = this.day0Of();
    if (now < day0 || now > day0 + WallClock.MINUTES_PER_DAY) {
      return;
    }
    const x: number = geo.xOf(now);
    ctx.strokeStyle = '#FF5252';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x, HEADER_HEIGHT - 4);
    ctx.lineTo(x, this.viewportHeightVp);
    ctx.stroke();
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
      event.stopPropagation();
      const hit = hitTest(this.hitBars, x, y, DEFAULT_EDGE_SLOP);
      this.dragKind = hit.kind;
      this.dragTask = hit.taskId === null ? null : this.findTask(hit.taskId);
      this.grabX = x;
      this.startWindowX = point.windowX;
      this.startScrollX = this.scroller.currentOffset().xOffset;
      this.dragging = true;
      this.preview = null;
      this.axisScrollable = ScrollDirection.None;
      return;
    }

    if (event.type === TouchType.Move && this.dragging) {
      event.stopPropagation();
      if (this.dragKind === HIT_EMPTY) {
        const dx: number = point.windowX - this.startWindowX;
        let next: number = this.startScrollX - dx;
        if (next < 0) {
          next = 0;
        }
        const max: number = this.canvasWidthVp - this.viewportWidthVp;
        if (next > max) {
          next = max;
        }
        this.scroller.scrollTo({ xOffset: next, yOffset: 0, animation: false });
        return;
      }
      if (this.dragTask === null) {
        return;
      }
      const geo: GanttGeometry = this.gestureGeo();
      if (this.dragKind === HIT_MOVE) {
        this.preview = proposeMove(this.dragTask, geo, x - this.grabX);
      } else if (this.dragKind === HIT_RESIZE_START) {
        this.preview = proposeResizeStart(this.dragTask, geo, x);
      } else if (this.dragKind === HIT_RESIZE_END) {
        this.preview = proposeResizeEnd(this.dragTask, geo, x);
      }
      this.redraw();
      return;
    }

    if ((event.type === TouchType.Up || event.type === TouchType.Cancel) && this.dragging) {
      event.stopPropagation();
      const pending: Task | null = this.preview;
      this.dragging = false;
      this.preview = null;
      this.dragTask = null;
      this.dragKind = HIT_EMPTY;
      this.axisScrollable = ScrollDirection.Horizontal;
      if (pending !== null && event.type === TouchType.Up) {
        this.repo.upsert(pending);
      } else {
        this.redraw();
      }
    }
  }

  build() {
    Column() {
      Scroll(this.scroller) {
        Canvas(this.ctx)
          .width(this.canvasWidthVp)
          .height(this.viewportHeightVp)
          .onReady(() => {
            this.canvasReady = true;
            this.redraw();
          })
          .onTouch((event: TouchEvent) => {
            this.onCanvasTouch(event);
          })
      }
      .scrollable(this.axisScrollable)
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .onAreaChange((_old: Area, area: Area) => {
        this.applyViewport(lengthVp(area.width), lengthVp(area.height));
      })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Block)
  }
}
