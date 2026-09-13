# 日视图双击按住拖拽创建 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 日视图改为「空白点一下，第二下按住拖出时间条，松手后标题框确认」；拖到视口边缘时按 Windows 规则压缩加长可见时段。

**Architecture:** 新纯模块 `CreateStroke` 管创建笔划（4vp、不武装）。新纯模块 `CreateEdgePush` 管边缘带探针。已有 `proposeCreate` / `expandProbeFromOverscroll` / `computeDayFitMinutes` 不变。`DayGanttPage` 去掉 2 秒武装和双击立刻 60 分钟条；默认 8–22 铺满视口，创建时按探针扩 fit。

**Tech Stack:** ArkTS、Hypium（`entry@ohosTest`）、Stage HAP。对照只读：`d:\javaFail\GanttDay\lib\ui\day\day_gantt_gestures.dart`。

**Spec:** `docs/superpowers/specs/2026-09-13-day-create-drag-design.md`

## Global Constraints

- `entry/src/main/ets/domain/` 下禁止 `import` ArkUI 或 `@kit.ArkData`
- 时间：本地墙钟分钟；吸附 15 分钟；最短 15 分钟
- 创建弹窗只要任务名；空标题不 `upsert`
- 第二下抬手位移小于 4vp → 取消，不武装下一次
- 边缘带：视口坐标左右 56vp；`edgeBase` 在进入边缘带时固定
- 贴边重复：180ms；外侧约 35% 边缘带
- 可见窗上限 `kDayViewMaxSpanMinutes`（7 天）；左不早于当日 0:00
- 已有色条拖到边缘本次不扩轴
- 不改周 / 月创建
- JS `Date` 月份 0-based：`new Date(2026, 7, 8)` = 2026-08-08
- Hypium 无设备时常挂起：先 `assembleHap` 作编译门禁，不要编造 PASS 日志
- 每完成一个 Task 提交一次；短句 `feat:` / 中文均可
- 不要改 `d:\javaFail\GanttDay`

---

## File Structure

```
entry/src/main/ets/domain/gesture/CreateStroke.ets      (new)
entry/src/main/ets/domain/gantt/CreateEdgePush.ets      (new)
entry/src/main/ets/domain/gantt/DayVisibleRange.ets     (add daySpansTouchingDay)
entry/src/main/ets/ui/day/DayGanttPage.ets              (wire stroke + fit + edge)
entry/src/ohosTest/ets/test/CreateStroke.test.ets       (new)
entry/src/ohosTest/ets/test/CreateEdgePush.test.ets     (new)
entry/src/ohosTest/ets/test/DayVisibleRange.test.ets    (new)
entry/src/ohosTest/ets/test/List.test.ets               (register)
```

`CreateTaskPopup` / `TapClassifier` / `MemoryTaskRepository` 不改（空标题拒绝已有测试）。

---

### Task 1: CreateStroke

**Files:**
- Create: `entry/src/main/ets/domain/gesture/CreateStroke.ets`
- Test: `entry/src/ohosTest/ets/test/CreateStroke.test.ets`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`

**Interfaces:**
- Consumes: 无
- Produces:
  - `CreateStroke.MIN_DRAG_VP = 4`
  - `END_CANCEL = 0` / `END_POPUP = 1`
  - `begin(x: number): void`
  - `move(x: number): boolean` — 非拖拽中返回 `false`（证明不武装）
  - `x0()` / `x1(): number`
  - `finish(): number` — `END_CANCEL` 或 `END_POPUP`，并把状态拉回 idle
  - `abort(): void`
  - `isDragging(): boolean`

- [ ] **Step 1: 写失败测试**

`entry/src/ohosTest/ets/test/CreateStroke.test.ets`：

```ets
import { describe, it, expect } from '@ohos/hypium';
import { CreateStroke, END_CANCEL, END_POPUP } from '../../../main/ets/domain/gesture/CreateStroke';

export default function createStrokeTest() {
  describe('CreateStroke', () => {
    it('move_before_begin_is_ignored', 0, () => {
      const s = new CreateStroke();
      expect(s.move(80)).assertFalse();
      expect(s.isDragging()).assertFalse();
    });

    it('finish_under_4vp_cancels_and_does_not_rearm', 0, () => {
      const s = new CreateStroke();
      s.begin(40);
      s.move(42);
      expect(s.finish()).assertEqual(END_CANCEL);
      expect(s.isDragging()).assertFalse();
      expect(s.move(120)).assertFalse();
    });

    it('finish_at_least_4vp_opens_popup_and_keeps_xs', 0, () => {
      const s = new CreateStroke();
      s.begin(40);
      s.move(80);
      expect(s.x0()).assertEqual(40);
      expect(s.x1()).assertEqual(80);
      expect(s.finish()).assertEqual(END_POPUP);
      expect(s.x0()).assertEqual(40);
      expect(s.x1()).assertEqual(80);
      expect(s.isDragging()).assertFalse();
    });

    it('min_drag_constant_is_4', 0, () => {
      expect(CreateStroke.MIN_DRAG_VP).assertEqual(4);
    });
  });
}
```

在 `List.test.ets` 增加：

```ets
import createStrokeTest from './CreateStroke.test';
```

并在 `testsuite()` 里调用 `createStrokeTest();`。

- [ ] **Step 2: 确认测试尚未通过**

工程根目录（PowerShell）：

```
& "D:\device\DevEco\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --mode module -p module=entry@ohosTest -p product=default test
```

期望：找不到 `CreateStroke` 或编译失败。若 Hypium 挂起，改跑：

```
& "D:\device\DevEco\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --mode module -p product=default assembleHap
```

无设备时以 ArkTS 编译报错为红灯，不要编造测试 PASS。

- [ ] **Step 3: 最小实现**

`entry/src/main/ets/domain/gesture/CreateStroke.ets`：

```ets
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
```

- [ ] **Step 4: 再跑 Step 2 的命令**

期望：`CreateStroke` 相关通过，或 `assembleHap` BUILD SUCCESSFUL。

- [ ] **Step 5: Commit**

```
git add entry/src/main/ets/domain/gesture/CreateStroke.ets entry/src/ohosTest/ets/test/CreateStroke.test.ets entry/src/ohosTest/ets/test/List.test.ets
git commit -m "feat: add CreateStroke for hold-drag create"
```

---

### Task 2: 当日段 + 探针扩 fit

**Files:**
- Modify: `entry/src/main/ets/domain/gantt/DayVisibleRange.ets`
- Test: `entry/src/ohosTest/ets/test/DayVisibleRange.test.ets`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`

**Interfaces:**
- Consumes: `DaySegmenter.segmentsForDay`、`computeDayFitMinutes`、`FitMinutes`、`Task`
- Produces:
  - `daySpansTouchingDay(tasks: Task[], day0: number): FitMinutes[]` — 只收与 `[day0, day0+1440)` 相交的任务，每段用当日 clip 的 start/end

- [ ] **Step 1: 写失败测试**

`entry/src/ohosTest/ets/test/DayVisibleRange.test.ets`：

```ets
import { describe, it, expect } from '@ohos/hypium';
import { Task } from '../../../main/ets/domain/models/Task';
import { WallClock } from '../../../main/ets/domain/time/WallClock';
import {
  computeDayFitMinutes,
  daySpansTouchingDay
} from '../../../main/ets/domain/gantt/DayVisibleRange';

export default function dayVisibleRangeTest() {
  describe('DayVisibleRange', () => {
    const day0 = WallClock.minutes(new Date(2026, 7, 8));

    it('empty_tasks_fit_is_8_to_22', 0, () => {
      const fit = computeDayFitMinutes(8, 22, day0, [], []);
      expect(fit.start).assertEqual(8 * 60);
      expect(fit.end).assertEqual(22 * 60);
    });

    it('probe_past_22_lengthens_end_by_whole_hour', 0, () => {
      const fit = computeDayFitMinutes(8, 22, day0, [], [day0 + 22 * 60 + 1]);
      expect(fit.start).assertEqual(8 * 60);
      expect(fit.end).assertEqual(23 * 60);
    });

    it('day_spans_use_selected_day_clip', 0, () => {
      const t = new Task(
        'n',
        'night',
        day0 + 23 * 60,
        day0 + 25 * 60,
        'azure',
        0
      );
      const spans = daySpansTouchingDay([t], day0);
      expect(spans.length).assertEqual(1);
      expect(spans[0].start).assertEqual(day0 + 23 * 60);
      expect(spans[0].end).assertEqual(day0 + 24 * 60);
      const fit = computeDayFitMinutes(8, 22, day0, spans, []);
      expect(fit.end).assertEqual(24 * 60);
    });
  });
}
```

`List.test.ets`：`import dayVisibleRangeTest from './DayVisibleRange.test';` 并调用。

- [ ] **Step 2: 跑测试，确认 `daySpansTouchingDay` 未定义**

同 Task 1 的 hvigor 命令。

- [ ] **Step 3: 实现 `daySpansTouchingDay`**

在 `DayVisibleRange.ets` 顶部增加 import：

```ets
import { Task } from '../models/Task';
import { DaySegmenter } from './DaySegmenter';
```

文件末尾增加：

```ets
export function daySpansTouchingDay(tasks: Task[], day0: number): FitMinutes[] {
  const out: FitMinutes[] = [];
  const day1: number = day0 + WallClock.MINUTES_PER_DAY;
  for (let i = 0; i < tasks.length; i++) {
    const task: Task = tasks[i];
    if (task.plannedEnd <= day0 || task.plannedStart >= day1) {
      continue;
    }
    const segs = DaySegmenter.segmentsForDay(task, day0);
    for (let j = 0; j < segs.length; j++) {
      out.push(new FitMinutes(segs[j].start, segs[j].end));
    }
  }
  return out;
}
```

注意：`computeDayFitMinutes` 里 `expandFitMinutes` 用 `time - day0`。`FitMinutes` 的 start/end 若是绝对墙钟，会算错。对照现有 `expandFitMinutes`：`minutes = clampInt(time - day0, ...)` 且 `daySpans` 传入的是 **span.start / span.end 当绝对墙钟**（`expandFitMinutes(start, end, day0, span.start)`）。

现有 `computeDayFitMinutes` 把 `span.start` / `span.end - 1` 当绝对时间。因此 `daySpansTouchingDay` 必须推**绝对墙钟**。上面测试里 `spans[0].start === day0 + 23*60` 与此一致。

但 `FitMinutes` 在 `computeDayFitMinutes` 初始 `start/end` 是相对当日的分钟（8*60）。`expandFitMinutes` 把绝对 `time` 减 `day0` 再和相对 start/end 比。正确。

- [ ] **Step 4: 再跑，确认通过或 assembleHap 成功**

- [ ] **Step 5: Commit**

```
git add entry/src/main/ets/domain/gantt/DayVisibleRange.ets entry/src/ohosTest/ets/test/DayVisibleRange.test.ets entry/src/ohosTest/ets/test/List.test.ets
git commit -m "feat: fit day spans and live probe hours"
```

---

### Task 3: CreateEdgePush

**Files:**
- Create: `entry/src/main/ets/domain/gantt/CreateEdgePush.ets`
- Test: `entry/src/ohosTest/ets/test/CreateEdgePush.test.ets`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`

**Interfaces:**
- Consumes: `expandProbeFromOverscroll`、`kDayViewMaxSpanMinutes`
- Produces:
  - `CREATE_EDGE_ZONE_VP = 56`
  - `CREATE_EDGE_HOLD_FRAC = 0.35`
  - `CREATE_EDGE_REPEAT_MS = 180`（页面用，模块只导出常量）
  - `class CreateEdgePush` 字段：`rightBase`/`leftBase`（`number | null` 用 `hasRight`/`hasLeft` + 数值，ArkTS 避免复杂 union 则用 `hasRight: boolean` + `rightBase: number`）
  - `reset(): void`
  - `applyPointer(rawX: number, viewportW: number, viewStart: number, viewEnd: number, day0: number): number | null` — 返回探针绝对墙钟；不在边缘带返回 `null`
  - `shouldHoldRepeat(rawX: number, viewportW: number): boolean`
  - `holdTick(rawX: number, viewportW: number, hourPx: number, viewStart: number, viewEnd: number, day0: number): number | null`

对照 Windows：进入右缘时 `rightBase = viewEnd`，`rightPushPx = max(depth, 外拖)`；离开带 1.5 倍宽度则清右缘。探针：`expandProbeFromOverscroll(day0, day0+max, base, hourPx, push, toTheRight)`。`hourPx = viewportW / ((viewEnd-viewStart)/60)`，再夹到 28–400（与已有 `expandProbeFromOverscroll` 内部一致，调用方可传未夹值）。

- [ ] **Step 1: 写失败测试**

```ets
import { describe, it, expect } from '@ohos/hypium';
import { WallClock } from '../../../main/ets/domain/time/WallClock';
import {
  CREATE_EDGE_HOLD_FRAC,
  CREATE_EDGE_REPEAT_MS,
  CREATE_EDGE_ZONE_VP,
  CreateEdgePush
} from '../../../main/ets/domain/gantt/CreateEdgePush';

export default function createEdgePushTest() {
  describe('CreateEdgePush', () => {
    const day0 = WallClock.minutes(new Date(2026, 7, 8));
    const viewStart = day0 + 8 * 60;
    const viewEnd = day0 + 22 * 60;
    const w = 700;

    it('constants_match_windows', 0, () => {
      expect(CREATE_EDGE_ZONE_VP).assertEqual(56);
      expect(CREATE_EDGE_REPEAT_MS).assertEqual(180);
      expect(CREATE_EDGE_HOLD_FRAC).assertEqual(0.35);
    });

    it('center_pointer_returns_null', 0, () => {
      const e = new CreateEdgePush();
      expect(e.applyPointer(350, w, viewStart, viewEnd, day0)).assertNull();
    });

    it('right_edge_opens_one_hour_from_fixed_base', 0, () => {
      const e = new CreateEdgePush();
      const p = e.applyPointer(w - 10, w, viewStart, viewEnd, day0);
      expect(p).assertEqual(viewEnd + 60);
    });

    it('second_frame_same_depth_does_not_runaway', 0, () => {
      const e = new CreateEdgePush();
      const a = e.applyPointer(w - 10, w, viewStart, viewEnd, day0);
      const b = e.applyPointer(w - 10, w, viewStart, viewEnd, day0);
      expect(a).assertEqual(b);
    });

    it('hold_repeat_only_on_outer_band', 0, () => {
      const e = new CreateEdgePush();
      expect(e.shouldHoldRepeat(w - 10, w)).assertTrue();
      expect(e.shouldHoldRepeat(w / 2, w)).assertFalse();
    });
  });
}
```

`List.test.ets` 注册 `createEdgePushTest`。

- [ ] **Step 2: 确认失败**

同 Task 1 命令。

- [ ] **Step 3: 实现**

`entry/src/main/ets/domain/gantt/CreateEdgePush.ets`：

```ets
import { expandProbeFromOverscroll } from './DayGestureMath';
import { kDayViewMaxSpanMinutes } from './DayVisibleRange';

export const CREATE_EDGE_ZONE_VP: number = 56;
export const CREATE_EDGE_HOLD_FRAC: number = 0.35;
export const CREATE_EDGE_REPEAT_MS: number = 180;

function hourWidth(viewportW: number, viewStart: number, viewEnd: number): number {
  const hours: number = (viewEnd - viewStart) / 60;
  if (hours <= 0 || viewportW <= 0) {
    return 28;
  }
  return viewportW / hours;
}

export class CreateEdgePush {
  hasRight: boolean = false;
  rightBase: number = 0;
  rightPushPx: number = 0;
  hasLeft: boolean = false;
  leftBase: number = 0;
  leftPushPx: number = 0;

  reset(): void {
    this.hasRight = false;
    this.hasLeft = false;
    this.rightPushPx = 0;
    this.leftPushPx = 0;
  }

  shouldHoldRepeat(rawX: number, viewportW: number): boolean {
    const outer: number = CREATE_EDGE_ZONE_VP * CREATE_EDGE_HOLD_FRAC;
    return rawX >= viewportW - outer || rawX <= outer;
  }

  applyPointer(
    rawX: number,
    viewportW: number,
    viewStart: number,
    viewEnd: number,
    day0: number
  ): number | null {
    this.updatePushes(rawX, viewportW, 0, viewStart, viewEnd);
    return this.probe(viewportW, viewStart, viewEnd, day0);
  }

  holdTick(
    rawX: number,
    viewportW: number,
    _hourPx: number,
    viewStart: number,
    viewEnd: number,
    day0: number
  ): number | null {
    if (!this.shouldHoldRepeat(rawX, viewportW)) {
      return this.probe(viewportW, viewStart, viewEnd, day0);
    }
    const step: number = hourWidth(viewportW, viewStart, viewEnd);
    if (rawX >= viewportW - CREATE_EDGE_ZONE_VP * CREATE_EDGE_HOLD_FRAC) {
      if (!this.hasRight) {
        this.hasRight = true;
        this.rightBase = viewEnd;
      }
      this.rightPushPx = this.rightPushPx + step;
    } else if (rawX <= CREATE_EDGE_ZONE_VP * CREATE_EDGE_HOLD_FRAC) {
      if (!this.hasLeft) {
        this.hasLeft = true;
        this.leftBase = viewStart;
      }
      this.leftPushPx = this.leftPushPx + step;
    }
    return this.probe(viewportW, viewStart, viewEnd, day0);
  }

  private updatePushes(
    rawX: number,
    viewportW: number,
    dx: number,
    viewStart: number,
    viewEnd: number
  ): void {
    const zone: number = CREATE_EDGE_ZONE_VP;
    const nearRight: boolean = rawX >= viewportW - zone;
    const nearLeft: boolean = rawX <= zone;
    if (nearRight) {
      if (!this.hasRight) {
        this.hasRight = true;
        this.rightBase = viewEnd;
        this.rightPushPx = 0;
      }
      const depth: number = rawX - (viewportW - zone);
      if (dx > 0) {
        this.rightPushPx = this.rightPushPx + dx;
      }
      if (depth > this.rightPushPx) {
        this.rightPushPx = depth;
      }
      if (rawX > viewportW) {
        const extra: number = rawX - viewportW + zone;
        if (extra > this.rightPushPx) {
          this.rightPushPx = extra;
        }
      }
    } else if (rawX < viewportW - zone * 1.5) {
      this.hasRight = false;
      this.rightPushPx = 0;
    }
    if (nearLeft) {
      if (!this.hasLeft) {
        this.hasLeft = true;
        this.leftBase = viewStart;
        this.leftPushPx = 0;
      }
      const depth: number = zone - rawX;
      if (dx < 0) {
        this.leftPushPx = this.leftPushPx + (-dx);
      }
      if (depth > this.leftPushPx) {
        this.leftPushPx = depth;
      }
      if (rawX < 0) {
        const extra: number = -rawX + zone;
        if (extra > this.leftPushPx) {
          this.leftPushPx = extra;
        }
      }
    } else if (rawX > zone * 1.5) {
      this.hasLeft = false;
      this.leftPushPx = 0;
    }
  }

  private probe(
    viewportW: number,
    viewStart: number,
    viewEnd: number,
    day0: number
  ): number | null {
    const maxEnd: number = day0 + kDayViewMaxSpanMinutes;
    const hx: number = hourWidth(viewportW, viewStart, viewEnd);
    if (this.hasRight && this.rightPushPx > 0) {
      return expandProbeFromOverscroll(day0, maxEnd, this.rightBase, hx, this.rightPushPx, true);
    }
    if (this.hasLeft && this.leftPushPx > 0) {
      return expandProbeFromOverscroll(day0, maxEnd, this.leftBase, hx, this.leftPushPx, false);
    }
    if (this.hasRight) {
      return expandProbeFromOverscroll(day0, maxEnd, this.rightBase, hx, 0, true);
    }
    if (this.hasLeft) {
      return expandProbeFromOverscroll(day0, maxEnd, this.leftBase, hx, 0, false);
    }
    return null;
  }
}
```

右缘 `w-10`、zone=56 → depth=46 > 0，`expandProbe` 至少 +60。测试 `viewEnd+60` 成立。

若 `rightPushPx === 0` 且刚进入，`applyPointer` 应用 depth 后 push>0。中心点不进带，返回 null。

- [ ] **Step 4: 再跑测试 / assembleHap**

- [ ] **Step 5: Commit**

```
git add entry/src/main/ets/domain/gantt/CreateEdgePush.ets entry/src/ohosTest/ets/test/CreateEdgePush.test.ets entry/src/ohosTest/ets/test/List.test.ets
git commit -m "feat: add create-edge overscroll probes"
```

---

### Task 4: 页面接上 CreateStroke（先不改轴）

**Files:**
- Modify: `entry/src/main/ets/ui/day/DayGanttPage.ets`

**Interfaces:**
- Consumes: `CreateStroke`、`END_CANCEL`、`END_POPUP`、`proposeCreate`、`TapClassifier`
- Produces: 第二下空白按下开始预览；移动更新；抬手不足 4vp 取消且不武装；拖够打开已有 `CreateTaskPopup`。不再调用 `armCreateStroke` / `CREATE_ARM_MS` / `proposeCreateAt`。

- [ ] **Step 1: 删除武装状态**

删掉这些字段和常量、方法：`CREATE_ARM_MS`、`createArmed`、`createArmTimerId`、`clearCreateArmTimer`、`armCreateStroke`。

增加：

```ets
import { CreateStroke, END_POPUP } from '../../domain/gesture/CreateStroke';
```

字段：

```ets
private createStroke: CreateStroke = new CreateStroke();
```

`releasePanIfIdle` 里用 `this.createStroke.isDragging()` 替换 `createDragging || createArmed`。可保留 `createDragging` 与 `isDragging()` 同步，或全部改成 `createStroke.isDragging()`。选后者，删 `createDragging` / `createX0` / `createX1`。

- [ ] **Step 2: 改触摸**

`Down`：删掉

```ets
if (this.createArmed && hit.taskId === null) {
  this.startCreateDrag(x);
  return;
}
this.createArmed = false;
this.clearCreateArmTimer();
```

`handleTapDecision` 的 Create 分支改为 `this.startCreateDrag(canvasX)`（内部 `createStroke.begin`）。

`startCreateDrag`：

```ets
private startCreateDrag(canvasX: number): void {
  this.createStroke.begin(canvasX);
  this.axisScrollable = ScrollDirection.None;
  this.tapConsumed = true;
  this.updateCreatePreview();
}
```

`updateCreatePreview`：

```ets
private updateCreatePreview(): void {
  const span = proposeCreate(this.gestureGeo(), this.createStroke.x0(), this.createStroke.x1());
  const id: string = this.createDraft !== null ? this.createDraft.id : util.generateRandomUUID();
  const createdAt: number = this.createDraft !== null ?
    this.createDraft.createdAt : WallClock.minutes(new Date());
  this.createDraft = new Task(id, '', span.start, span.end, FactorySwatches.DEFAULT_ID, createdAt);
  this.preview = null;
  this.createStart = span.start;
  this.createEnd = span.end;
  this.redraw();
}
```

`Move`：`if (this.createStroke.isDragging()) { this.createStroke.move(x); this.updateCreatePreview(); return; }`

`Up/Cancel`：`if (this.createStroke.isDragging())`：
- Cancel → `createStroke.abort()`，`createDraft = null`，`redraw`，`releasePanIfIdle`
- Up → `const endKind = this.createStroke.finish()`；若 `END_POPUP` 则 `openCreatePopup()`；否则 `createDraft = null`，`redraw`，`releasePanIfIdle`

`aboutToDisappear` 去掉 `clearCreateArmTimer`。

- [ ] **Step 3: 编译**

```
& "D:\device\DevEco\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --mode module -p product=default assembleHap
```

期望：BUILD SUCCESSFUL。

- [ ] **Step 4: Commit**

```
git add entry/src/main/ets/ui/day/DayGanttPage.ets
git commit -m "feat: hold-drag create without 2s arm"
```

---

### Task 5: 8–22 铺满视口 + 创建边缘扩轴

**Files:**
- Modify: `entry/src/main/ets/ui/day/DayGanttPage.ets`

**Interfaces:**
- Consumes: `computeDayFitMinutes`、`daySpansTouchingDay`、`CreateEdgePush`、`CREATE_EDGE_REPEAT_MS`、`FitMinutes`、`DaySegmenter.clipToRange` / `segmentsForDay`
- Produces: 默认 fit 铺满视口；创建中探针扩窗；180ms holdTick；创建结束清探针并按任务重算 fit。`drawGeo` 与 `gestureGeo` 相同：`new GanttGeometry(day0+fit.start, day0+fit.end, viewportWidthVp)`。`canvasWidthVp = viewportWidthVp`。`watchOverlapping(day0, day0 + kDayViewMaxSpanMinutes)`。

- [ ] **Step 1: fit 状态**

增加字段：

```ets
private fitStartMin: number = 8 * 60;
private fitEndMin: number = 22 * 60;
private createProbes: number[] = [];
private edgePush: CreateEdgePush = new CreateEdgePush();
private edgeRepeatId: number = -1;
private lastRawX: number = 0;
```

删掉 `canvasWidthFor` 的 24h 加宽（或改为 `return viewportW`）。`applyViewport`：`this.canvasWidthVp = width`。

```ets
private activeGeo(): GanttGeometry {
  const day0: number = this.day0Of();
  return new GanttGeometry(day0 + this.fitStartMin, day0 + this.fitEndMin, this.viewportWidthVp);
}
```

`drawGeo` / `gestureGeo` 都改成返回 `this.activeGeo()`。

```ets
private recomputeFit(probes: number[]): void {
  const day0: number = this.day0Of();
  const spans = daySpansTouchingDay(this.cachedTasks, day0);
  const fit = computeDayFitMinutes(8, 22, day0, spans, probes);
  this.fitStartMin = fit.start;
  this.fitEndMin = fit.end;
}

private clearCreateAxis(): void {
  this.createProbes = [];
  this.edgePush.reset();
  this.clearEdgeRepeat();
  this.recomputeFit([]);
}

private clearEdgeRepeat(): void {
  if (this.edgeRepeatId !== -1) {
    clearInterval(this.edgeRepeatId);
    this.edgeRepeatId = -1;
  }
}
```

`bindWatch`：

```ets
this.unwatch = this.repo.watchOverlapping(day0, day0 + kDayViewMaxSpanMinutes, this.sink);
```

`sink.apply` 在非创建拖拽时 `recomputeFit([])` 再 `redraw`。创建拖拽中不要用 watch 把 fit 打回 8–22。

- [ ] **Step 2: 创建 Move 里喂边缘**

`point.x` 是视口 / Canvas 可见 x（`rawX`）。`createStroke.move` 仍用 `touchCanvasX`（铺满时 scroll=0，等于 rawX）。

```ets
if (event.type === TouchType.Move && this.createStroke.isDragging()) {
  event.stopPropagation();
  this.lastRawX = point.x;
  this.createStroke.move(x);
  const geo = this.activeGeo();
  const probe = this.edgePush.applyPointer(
    point.x,
    this.viewportWidthVp,
    geo.viewStart,
    geo.viewEnd,
    this.day0Of()
  );
  this.applyProbe(probe);
  this.syncEdgeRepeat();
  this.updateCreatePreview();
  return;
}
```

```ets
private applyProbe(probe: number | null): void {
  if (probe === null) {
    return;
  }
  const next: number[] = [];
  let minP: number = probe;
  let maxP: number = probe;
  for (let i = 0; i < this.createProbes.length; i++) {
    const p: number = this.createProbes[i];
    if (p < minP) {
      minP = p;
    }
    if (p > maxP) {
      maxP = p;
    }
    next.push(p);
  }
  next.push(probe);
  this.createProbes = [minP, maxP];
  this.recomputeFit(this.createProbes);
}

private syncEdgeRepeat(): void {
  const want: boolean = this.edgePush.shouldHoldRepeat(this.lastRawX, this.viewportWidthVp);
  if (!want) {
    this.clearEdgeRepeat();
    return;
  }
  if (this.edgeRepeatId !== -1) {
    return;
  }
  this.edgeRepeatId = setInterval(() => {
    if (!this.createStroke.isDragging()) {
      this.clearEdgeRepeat();
      return;
    }
    const geo = this.activeGeo();
    const hourPx: number = this.viewportWidthVp / ((geo.viewEnd - geo.viewStart) / 60);
    const probe = this.edgePush.holdTick(
      this.lastRawX,
      this.viewportWidthVp,
      hourPx,
      geo.viewStart,
      geo.viewEnd,
      this.day0Of()
    );
    this.applyProbe(probe);
    this.updateCreatePreview();
  }, CREATE_EDGE_REPEAT_MS);
}
```

扩窗后 `proposeCreate` 使用新 `activeGeo()`。`x0/x1` 是像素；窗变窄后同一像素对应更多分钟，这与 Windows 一致。

创建结束（`finish` 取消、`abort`、`cancelCreate`、`confirmCreate` 无论是否插入）都调用 `clearCreateAxis()`。`openCreatePopup` 前**不要**清探针（弹窗期间预览条仍按展开后的轴画，与 Windows「弹窗期间保持 sticky」一致）；关弹窗时再 `clearCreateAxis`。

- [ ] **Step 3: 网格按 fit 画**

`paintGrid` 不要再写死 `DAY_HOURS = 24`。用：

```ets
const day0: number = this.day0Of();
const startH: number = this.fitStartMin / 60;
const endH: number = this.fitEndMin / 60;
const hourPx: number = this.viewportWidthVp / (endH - startH);
for (let h = startH; h <= endH; h++) {
  const t: number = day0 + h * 60;
  const x: number = geo.xOf(t);
  const labelH: number = ((h % 24) + 24) % 24;
  // 刻度与 `${labelH}:00`
}
```

`rebuildBars`：对 fit 覆盖的每个自然日调用 `DaySegmenter.segmentsForDay`（从 `WallClock.dayStart(day0 + fitStartMin)` 走到 `day0 + fitEndMin`，步长 1440），这样跨午夜仍两段。

`scrollToFit`：默认铺满后 `xOffset = 0`。非创建空白拖：现有逻辑，`max = canvasWidthVp - viewportWidthVp`，铺满时为 0，拖不动。

`aboutToDisappear`：`clearEdgeRepeat()`。

- [ ] **Step 4: assembleHap**

期望 BUILD SUCCESSFUL。

- [ ] **Step 5: Commit**

```
git add entry/src/main/ets/ui/day/DayGanttPage.ets
git commit -m "feat: compress day axis while creating at edges"
```

---

### Task 6: 规格指针与手工清单

**Files:**
- Modify: `docs/superpowers/specs/2026-09-12-harmonyos-ganttday-design.md` §3.2 / §3.5 各加一句指向新规格
- Modify: `.superpowers/sdd/progress.md` 记本计划

- [ ] **Step 1: 改第一期规格中已过时的创建句**

§3.2 表格「空白处连续点按两下」改为：「空白处点一下再按住拖，见 `2026-09-13-day-create-drag-design.md`」。

§3.5 开头加：创建路径已由该文件替代；不再双击立刻 60 分钟。

`.superpowers/sdd/progress.md` 增加：

```
- Plan 2026-09-13-day-create-drag: Task 1–5 complete（或按实际勾）
```

- [ ] **Step 2: 手工对照（有平板再做，无设备在 progress 标 UNVERIFIED）**

- 第二下按住拖出预览，松手出标题框，输入名称后任务出现
- 第二下点一下就抬 → 无条、无框
- 拖到视口右缘 → 小时变窄、窗加长；取消后无新任务则回到 8–22 铺满
- 点已有色条开抽屉；双击先确认再删
- 创建中底栏 / 顶栏翻日不触发

- [ ] **Step 3: Commit**

```
git add docs/superpowers/specs/2026-09-12-harmonyos-ganttday-design.md .superpowers/sdd/progress.md
git commit -m "docs: point phase-1 create to hold-drag spec"
```

---

## Spec coverage（自检）

| 规格 | 任务 |
| --- | --- |
| 第二下按住拖、4vp、不武装 | Task 1 + 4 |
| 标题框 / 空标题不插入 | 已有 popup + MemoryTaskRepository；Task 4/5 只接线 |
| 边缘 56vp、固定 base、整小时、7 日 | Task 2 + 3 + 5 |
| 180ms 贴边 | Task 3 常量 + Task 5 `setInterval` |
| 创建结束重算 fit | Task 5 `clearCreateAxis` |
| 已有色条不扩轴 | Task 5 只在 `createStroke.isDragging()` 里 `applyPointer` |
| 不改周月 / 标签 | 无对应改动 |
| `proposeCreateAt` 界面不用 | Task 4 删除该调用 |

无 TBD。`CreateStroke.finish` / `END_*` 在 Task 1 与 Task 4 名称一致。`CreateEdgePush.applyPointer` / `holdTick` / `CREATE_EDGE_REPEAT_MS` 在 Task 3 与 Task 5 一致。
