# HarmonyOS GanttDay 第一期 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 MatePad 上做出可日常使用的原生日 / 周 / 月甘特：本机 RDB、日视图拖改与双击创建/删除、右侧抽屉编辑。

**Architecture:** 领域模块（墙钟、几何、切段、分行、手势数学、周列、月跨日条）纯 ArkTS，零 ArkUI / RDB 依赖。界面只通过 `TaskRepository` 读写。第一期适配器：内存（测）+ 鸿蒙 RDB（产品）。日视图 Canvas 绘制；周 / 月消费布局模块的几何。

**Tech Stack:** ArkTS、Stage 模型 HAP、`@kit.ArkData` relationalStore、Hypium（`entry@ohosTest`）。对照实现：`d:\javaFail\GanttDay`（只读，不要改那个仓库）。

**Spec:** `docs/superpowers/specs/2026-09-12-harmonyos-ganttday-design.md`

## Global Constraints

- 设备：华为平板 HarmonyOS 6+；不做手机适配
- 实现：原生 ArkTS HAP；不引用 Flutter / Windows 工程
- 时间：本地墙钟分钟（1970-01-01 00:00 起），不按时区换算
- 吸附：四舍五入到最近 15 分钟（8:07→8:00，8:08→8:15）；最短时长 15 分钟
- 重叠：半开区间；头尾相接共行；跨午夜一条任务两段
- 第一期色条只用默认霁蓝 `#457BD9`（`azure`）
- 创建：日视图空白双击 → 吸附后 60 分钟预览 + 锚点标题框
- 删除：已有色条 / 周块双击 → 先确认再删；月视图双击不删
- 单击色条开表单须等双击窗口结束
- 库打不开：改名为 `gantday.db.corrupt-<时间戳>` 再重建，禁止静默清空
- `entry/src/main/ets/domain/` 下禁止 `import` ArkUI 或 `@kit.ArkData`
- JS `Date` 月份 0-based：`new Date(2026, 7, 8)` = 2026-08-08
- 每完成一个 Task 提交一次；提交信息用中文或 `feat:` 前缀均可，保持短句

本计划是一份。Task 1–13 结束后日视图已能日常用；14–15 是周 / 月。不要把周 / 月提前揉进日视图任务。

---

## File Structure

```
entry/src/main/ets/
  entryability/EntryAbility.ets
  pages/Index.ets
  domain/
    time/WallClock.ets
    models/Task.ets
    models/GanttSegment.ets
    models/ColorSwatch.ets
    gantt/FactorySwatches.ets
    gantt/GanttGeometry.ets
    gantt/DaySegmenter.ets
    gantt/LaneLayout.ets
    gantt/DayVisibleRange.ets
    gantt/DaySpanClamp.ets
    gantt/DayGestureMath.ets
    gesture/TapClassifier.ets
    week/WeekColumnLayout.ets
    month/MonthSpanLayout.ets
  platform/TaskRepository.ets
  data/
    MemoryTaskRepository.ets
    AppDatabase.ets
    RdbTaskRepository.ets
  ui/
    theme/AppColors.ets
    shell/AppShell.ets
    shell/ViewNavBar.ets
    common/SideDrawer.ets
    common/DeleteConfirm.ets
    common/DbErrorScreen.ets
    day/DayGanttPage.ets
    day/CreateTaskPopup.ets
    task/TaskForm.ets
    week/WeekPage.ets
    month/MonthPage.ets
entry/src/ohosTest/ets/test/
  List.test.ets
  WallClock.test.ets
  GanttGeometry.test.ets
  DaySegmenter.test.ets
  LaneLayout.test.ets
  DayGestureMath.test.ets
  TapClassifier.test.ets
  WeekColumnLayout.test.ets
  MonthSpanLayout.test.ets
  MemoryTaskRepository.test.ets
  AppDatabase.test.ets
```

对照算法时打开 Windows 同名文件，不要「凭记忆重写」。

---

### Task 1: DevEco 工程与 Hypium 入口

**Files:**
- Create / 由向导生成：`AppScope/app.json5`、`entry/src/main/module.json5`、`entry/src/main/ets/entryability/EntryAbility.ets`、`entry/src/ohosTest/ets/test/List.test.ets`
- Create: `entry/src/ohosTest/ets/test/Smoke.test.ets`

**Interfaces:**
- Consumes: 无
- Produces: 可运行的 HAP 工程；`List.test.ets` 会调用后续每个 `*.test.ets` 的 default export

- [ ] **Step 1: 确认或创建 Stage 工程**

若仓库还没有 `entry/src/main/module.json5`：用 DevEco Studio 在本目录创建 Application（ArkTS / Stage / Tablet / HarmonyOS 6）。

`AppScope/app.json5` 中：

```json5
{
  "app": {
    "bundleName": "com.shive.ganttday",
    "vendor": "S-hive",
    "versionCode": 1000000,
    "versionName": "1.0.0",
    "icon": "$media:layered_image",
    "label": "$string:app_name"
  }
}
```

应用显示名写成 `GanttDay`。

- [ ] **Step 2: 写冒烟测试**

`entry/src/ohosTest/ets/test/Smoke.test.ets`：

```ets
import { describe, it, expect } from '@ohos/hypium';

export default function smokeTest() {
  describe('Smoke', () => {
    it('hypium_runs', 0, () => {
      expect(1 + 1).assertEqual(2);
    });
  });
}
```

`entry/src/ohosTest/ets/test/List.test.ets` 必须调用它（已有向导文件则追加一行）：

```ets
import smokeTest from './Smoke.test';

export default function testsuite() {
  smokeTest();
}
```

之后每个新测试文件都要：写文件 → 在 `List.test.ets` 里 `import` 并调用。不要省略。

- [ ] **Step 3: 跑测试，确认通过**

在工程根目录：

```
hvigorw --mode module -p module=entry@ohosTest -p product=default test
```

若本机只有 DevEco：用「OhosTest」运行配置。Expected: `hypium_runs` PASS。

- [ ] **Step 4: Commit**

```
git add AppScope entry docs
git commit -m "feat: scaffold HarmonyOS GanttDay and Hypium smoke test"
```

---

### Task 2: WallClock 与 Task / GanttSegment

**Files:**
- Create: `entry/src/main/ets/domain/time/WallClock.ets`
- Create: `entry/src/main/ets/domain/models/Task.ets`
- Create: `entry/src/main/ets/domain/models/GanttSegment.ets`
- Test: `entry/src/ohosTest/ets/test/WallClock.test.ets`

**Interfaces:**
- Consumes: 无
- Produces:
  - `WallClock.MINUTES_PER_DAY = 1440`
  - `WallClock.minutes(local: Date): number`
  - `WallClock.dateTime(m: number): Date`（钟面与 `m` 一致）
  - `WallClock.dayStart(any: number): number`
  - `WallClock.dayEndExclusive(any: number): number`
  - `class Task` 字段：`id, title, plannedStart, plannedEnd, actualStart, actualEnd, isDone, primaryTagId, autoSwatchId, overrideSwatchId, notes, createdAt`
  - `Task.copyWith(...)` （`actualStart` 等可用 `null` 清空时加 `clearActuals`）
  - `class GanttSegment { taskId: string; start: number; end: number }`

- [ ] **Step 1: 写失败测试**

`WallClock.test.ets`（对照 `GanttDay/test/domain/wall_clock_test.dart`）：

```ets
import { describe, it, expect } from '@ohos/hypium';
import { WallClock } from '../../../main/ets/domain/time/WallClock';

export default function wallClockTest() {
  describe('WallClock', () => {
    it('roundtrip_clock_face', 0, () => {
      const dt = new Date(2026, 7, 8, 9, 15);
      const m = WallClock.minutes(dt);
      const back = WallClock.dateTime(m);
      expect(back.getFullYear()).assertEqual(2026);
      expect(back.getMonth()).assertEqual(7);
      expect(back.getDate()).assertEqual(8);
      expect(back.getHours()).assertEqual(9);
      expect(back.getMinutes()).assertEqual(15);
    });

    it('dayStart_and_dayEndExclusive', 0, () => {
      const noon = WallClock.minutes(new Date(2026, 7, 8, 12, 0));
      const start = WallClock.dayStart(noon);
      const end = WallClock.dayEndExclusive(noon);
      const startDt = WallClock.dateTime(start);
      const endDt = WallClock.dateTime(end);
      expect(startDt.getFullYear()).assertEqual(2026);
      expect(startDt.getMonth()).assertEqual(7);
      expect(startDt.getDate()).assertEqual(8);
      expect(startDt.getHours()).assertEqual(0);
      expect(endDt.getDate()).assertEqual(9);
      expect(end - start).assertEqual(24 * 60);
    });

    it('encoding_is_clock_face_only', 0, () => {
      const m = WallClock.minutes(new Date(2026, 7, 8, 9, 0));
      const epoch = Date.UTC(1970, 0, 1);
      const dayUtc = Date.UTC(2026, 7, 8);
      const daysSinceEpoch = Math.floor((dayUtc - epoch) / 86400000);
      expect(m).assertEqual(daysSinceEpoch * 1440 + 9 * 60);
    });

    it('midnight_is_its_own_dayStart', 0, () => {
      const mid = WallClock.minutes(new Date(2026, 7, 8));
      expect(WallClock.dayStart(mid)).assertEqual(mid);
      expect(WallClock.dayEndExclusive(mid)).assertEqual(mid + 1440);
    });
  });
}
```

在 `List.test.ets` 注册 `wallClockTest()`。

- [ ] **Step 2: 跑测试，确认失败**

Expected: 编译失败或 `WallClock` 未定义。

- [ ] **Step 3: 最小实现**

`WallClock.ets`：

```ets
export class WallClock {
  static readonly MINUTES_PER_DAY: number = 24 * 60;

  static minutes(local: Date): number {
    const utcMs = Date.UTC(
      local.getFullYear(),
      local.getMonth(),
      local.getDate(),
      local.getHours(),
      local.getMinutes()
    );
    return Math.floor(utcMs / 60000);
  }

  static dateTime(m: number): Date {
    const utc = new Date(m * 60000);
    return new Date(
      utc.getUTCFullYear(),
      utc.getUTCMonth(),
      utc.getUTCDate(),
      utc.getUTCHours(),
      utc.getUTCMinutes()
    );
  }

  static dayStart(any: number): number {
    return any - (any % WallClock.MINUTES_PER_DAY);
  }

  static dayEndExclusive(any: number): number {
    return WallClock.dayStart(any) + WallClock.MINUTES_PER_DAY;
  }
}
```

`GanttSegment.ets`：

```ets
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
```

`Task.ets`：字段按 Interfaces；`actualStart` / `actualEnd` / `primaryTagId` / `overrideSwatchId` / `notes` 类型为 `number | null` 或 `string | null`；`isDone: boolean` 默认 `false`；`autoSwatchId` 必填。`copyWith` 用可选参数，需要清空实际时间时加 `clearActuals: boolean`。对照 `GanttDay/lib/domain/models/task.dart`。

- [ ] **Step 4: 跑测试，确认通过**

Expected: 上述 4 个用例 PASS。

- [ ] **Step 5: Commit**

```
git add entry/src/main/ets/domain entry/src/ohosTest/ets/test
git commit -m "feat: add WallClock and task models"
```

---

### Task 3: GanttGeometry

**Files:**
- Create: `entry/src/main/ets/domain/gantt/GanttGeometry.ets`
- Test: `entry/src/ohosTest/ets/test/GanttGeometry.test.ets`

**Interfaces:**
- Consumes: `WallClock.minutes`
- Produces:
  - `GanttGeometry.MIN_DURATION_MINUTES = 15`
  - `GanttGeometry.SNAP_MINUTES = 15`
  - `constructor(viewStart: number, viewEnd: number, widthPx: number)`
  - `xOf(t: number): number`
  - `timeOf(x: number): number`
  - `snap(t: number): number`
  - `clampDuration(start: number, end: number): number`

- [ ] **Step 1: 写失败测试**

对照 `GanttDay/test/domain/gantt_geometry_test.dart`。`day = WallClock.minutes(new Date(2026, 7, 8))`，`geo = new GanttGeometry(day + 8*60, day + 22*60, 1400)`。

断言：

- `xOf(day+8*60) === 0`，`xOf(day+22*60) === 1400`
- `timeOf(100) === day + 9*60`
- `snap(day+8*60+7) === day+8*60`，`snap(day+8*60+8) === day+8*60+15`
- `snap(day+9*60)` 与 `snap(day+9*60+45)` 不变
- `clampDuration(start, start+5) === start+15`；`start-30` → `start+15`；`start+45` → `start+45`

- [ ] **Step 2: 跑测试，确认失败**

- [ ] **Step 3: 最小实现**

对照 `GanttDay/lib/domain/gantt/gantt_geometry.dart` 逐行移植：

```ets
export class GanttGeometry {
  static readonly MIN_DURATION_MINUTES: number = 15;
  static readonly SNAP_MINUTES: number = 15;

  viewStart: number;
  viewEnd: number;
  widthPx: number;

  constructor(viewStart: number, viewEnd: number, widthPx: number) {
    this.viewStart = viewStart;
    this.viewEnd = viewEnd;
    this.widthPx = widthPx;
  }

  xOf(t: number): number {
    return (t - this.viewStart) / (this.viewEnd - this.viewStart) * this.widthPx;
  }

  timeOf(x: number): number {
    return this.viewStart + Math.round((x / this.widthPx) * (this.viewEnd - this.viewStart));
  }

  snap(t: number): number {
    const r = t % GanttGeometry.SNAP_MINUTES;
    return r < GanttGeometry.SNAP_MINUTES / 2 ? t - r : t + (GanttGeometry.SNAP_MINUTES - r);
  }

  clampDuration(start: number, end: number): number {
    if (end < start + GanttGeometry.MIN_DURATION_MINUTES) {
      return start + GanttGeometry.MIN_DURATION_MINUTES;
    }
    return end;
  }
}
```

- [ ] **Step 4: 跑测试，确认通过**

- [ ] **Step 5: Commit**

```
git commit -m "feat: add GanttGeometry snap and duration clamp"
```

---

### Task 4: DaySegmenter 与 LaneLayout

**Files:**
- Create: `entry/src/main/ets/domain/gantt/DaySegmenter.ets`
- Create: `entry/src/main/ets/domain/gantt/LaneLayout.ets`
- Test: `entry/src/ohosTest/ets/test/DaySegmenter.test.ets`
- Test: `entry/src/ohosTest/ets/test/LaneLayout.test.ets`

**Interfaces:**
- Consumes: `Task`, `GanttSegment`, `WallClock`
- Produces:
  - `DaySegmenter.segmentsForDay(task: Task, dayAny: number): GanttSegment[]`
  - `DaySegmenter.clipToDay(taskId, start, end, dayAny): GanttSegment[]`
  - `DaySegmenter.clipToRange(taskId, start, end, rangeStart, rangeEnd): GanttSegment[]`
  - `LaneLayout.keyOf(s: GanttSegment): string` → `` `${taskId}:${start}` ``
  - `LaneLayout.assign(segs: GanttSegment[]): Map<string, number>`
  - `LaneLayout.laneCount(lanes: Map<string, number>): number`

- [ ] **Step 1: 写失败测试**

`DaySegmenter.test.ets` 逐条移植 `GanttDay/test/domain/day_segmenter_test.dart`（跨夜当天到午夜、次日早晨、恰 00:00 结束次日无段、日内不裁、另一天为空、`clipToRange` 整周一段）。用 `new Task(...)`，`autoSwatchId` 填 `'azure'`，`createdAt` 填 `0`。

`LaneLayout.test.ets` 移植 `GanttDay/test/domain/lane_layout_test.dart`：

- 0–60 与 60–120 都是 lane 0
- 0–90 与 60–120 不同 lane
- 完全重叠 lane 集合为 `{0,1}`
- 结束后让出的 lane 被第三条复用
- `laneCount` 空 map 为 1

- [ ] **Step 2: 跑测试，确认失败**

- [ ] **Step 3: 最小实现**

`DaySegmenter` 对照 `GanttDay/lib/domain/gantt/day_segmenter.dart`。`LaneLayout.assign` 对照 `GanttDay/lib/domain/gantt/lane_layout.dart`（按 start 再 end 排序；`laneEnds[lane] > start` 则换行；半开区间）。

- [ ] **Step 4: 跑测试，确认通过**

- [ ] **Step 5: Commit**

```
git commit -m "feat: add day segmenter and lane packing"
```

---

### Task 5: 日视图手势数学（含双击创建 60 分钟）

**Files:**
- Create: `entry/src/main/ets/domain/gantt/DayVisibleRange.ets`
- Create: `entry/src/main/ets/domain/gantt/DaySpanClamp.ets`
- Create: `entry/src/main/ets/domain/gantt/DayGestureMath.ets`
- Test: `entry/src/ohosTest/ets/test/DayGestureMath.test.ets`

**Interfaces:**
- Consumes: `GanttGeometry`, `Task`, `WallClock`
- Produces:
  - `kDayViewMaxSpanMinutes = 7 * 1440`
  - `clampXToView(geo, x): number`
  - `proposeMove(task, geo, deltaX): Task`
  - `proposeResizeStart(task, geo, x): Task`
  - `proposeResizeEnd(task, geo, x): Task`
  - `proposeCreateAt(geo, x): Span` 其中 `class Span { start: number; end: number }`
  - `expandProbeFromOverscroll(...)`（对照 Dart，给日视图边缘展开用）

第一期**不要**移植拖空白创建的 `proposeCreate(x0,x1)`。创建只走 `proposeCreateAt`。

- [ ] **Step 1: 写失败测试**

`day = WallClock.minutes(new Date(2026, 7, 8))`。

`proposeCreateAt`：

```ets
const geo = new GanttGeometry(day + 8 * 60, day + 22 * 60, 1400);
const span = proposeCreateAt(geo, geo.xOf(day + 9 * 60 + 7));
expect(span.start).assertEqual(day + 9 * 60);
expect(span.end).assertEqual(day + 10 * 60);
```

`proposeMove`：9:00–11:00 的任务，`deltaX` 等于 1 小时像素（`1400/14`），结果 start 为 10:00，时长仍 120。

`proposeResizeEnd`：拖到 10:08 应对 10:15；拖到早于 start+15 应对 start+15。

`expandProbeFromOverscroll` 移植 `GanttDay/test/ui/day_gesture_math_test.dart` 里 zero push / +1 hour / +3 hours / cap 7 days 四条。

- [ ] **Step 2: 跑测试，确认失败**

- [ ] **Step 3: 最小实现**

`DayVisibleRange.ets`：只需要 `export const kDayViewMaxSpanMinutes = 7 * WallClock.MINUTES_PER_DAY;`。`computeDayFitMinutes` / `expandFitMinutes` 一并对照 `day_visible_range.dart` 移植（日视图默认 8–22 展开用得着）。

`DaySpanClamp.ets` 对照 `day_span_clamp.ets` 的 Dart 版：`dayAxisBounds`、`clampSpanToAxis`、`clampTimeToAxis`。

`DayGestureMath.ets` 对照 `day_gesture_math.dart` 的 `clampXToView`、`clampSpanToView`、`proposeMove`、`proposeResizeStart`、`proposeResizeEnd`、`expandProbeFromOverscroll`。另加：

```ets
export function proposeCreateAt(geo: GanttGeometry, x: number): Span {
  const start = geo.snap(geo.timeOf(clampXToView(geo, x)));
  return new Span(start, start + 60);
}
```

- [ ] **Step 4: 跑测试，确认通过**

- [ ] **Step 5: Commit**

```
git commit -m "feat: add day gesture math and 60-minute create-at"
```

---

### Task 6: TapClassifier（单击开表单 / 双击删 / 双击空白创建）

**Files:**
- Create: `entry/src/main/ets/domain/gesture/TapClassifier.ets`
- Test: `entry/src/ohosTest/ets/test/TapClassifier.test.ets`

**Interfaces:**
- Consumes: 无
- Produces:
  - `TapClassifier.HIT_SLOP_VP = 32`
  - `TapClassifier.DOUBLE_MS = 300`
  - `class TapHit { x: number; y: number; taskId: string | null }`（`null` = 空白）
  - `enum TapDecision { Wait, OpenForm, Delete, Create, Ignore }`
  - `TapClassifier.onDown(prev: TapHit | null, prevMs: number, curr: TapHit, nowMs: number): TapDecision`

规则（规格 3.5 / 3.6）：

- 没有 prev，或间隔 > 300ms，或距离 > 32：若 `curr.taskId !== null` → `Wait`（等超时后由 UI 发 `OpenForm`）；若空白 → `Wait`（空白单击无效果，超时变 `Ignore`）
- 第二次：同一 `taskId` 非空 → `Delete`
- 第二次：两次都是空白 → `Create`
- 第二次：一次空白一次色条 → `Ignore`
- 另提供 `TapClassifier.onWaitTimeout(hit: TapHit): TapDecision`：色条 → `OpenForm`，空白 → `Ignore`

- [ ] **Step 1: 写失败测试**

```ets
import { describe, it, expect } from '@ohos/hypium';
import { TapClassifier, TapDecision, TapHit } from '../../../main/ets/domain/gesture/TapClassifier';

function hit(x: number, y: number, taskId: string | null): TapHit {
  const h = new TapHit();
  h.x = x;
  h.y = y;
  h.taskId = taskId;
  return h;
}

export default function tapClassifierTest() {
  describe('TapClassifier', () => {
    it('first_bar_tap_waits', 0, () => {
      const d = TapClassifier.onDown(null, 0, hit(10, 10, 'a'), 1000);
      expect(d).assertEqual(TapDecision.Wait);
    });

    it('second_bar_tap_same_task_deletes', 0, () => {
      const d = TapClassifier.onDown(hit(10, 10, 'a'), 1000, hit(12, 11, 'a'), 1200);
      expect(d).assertEqual(TapDecision.Delete);
    });

    it('second_empty_tap_creates', 0, () => {
      const d = TapClassifier.onDown(hit(40, 40, null), 1000, hit(42, 41, null), 1200);
      expect(d).assertEqual(TapDecision.Create);
    });

    it('timeout_on_bar_opens_form', 0, () => {
      expect(TapClassifier.onWaitTimeout(hit(10, 10, 'a'))).assertEqual(TapDecision.OpenForm);
    });

    it('timeout_on_empty_ignores', 0, () => {
      expect(TapClassifier.onWaitTimeout(hit(40, 40, null))).assertEqual(TapDecision.Ignore);
    });

    it('same_task_far_apart_still_deletes', 0, () => {
      const d = TapClassifier.onDown(hit(5, 5, 'night'), 1000, hit(200, 5, 'night'), 1180);
      expect(d).assertEqual(TapDecision.Delete);
    });

    it('empty_taps_far_apart_ignore', 0, () => {
      const d = TapClassifier.onDown(hit(0, 0, null), 1000, hit(80, 0, null), 1100);
      expect(d).assertEqual(TapDecision.Ignore);
    });
  });
}
```

`onDown` 规则：

- 双击删除：`prev.taskId !== null && prev.taskId === curr.taskId && now-prevMs <= DOUBLE_MS`（跨午夜两段同一 id，不受 32vp 限制）
- 双击创建：两次 `taskId === null` 且距离 ≤ 32 且间隔 ≤ 300
- 否则若间隔 ≤ 300 但条件不满足 → `Ignore`（取消等待中的单击）
- 间隔 > 300 或没有 prev：当作新的第一下 → `Wait`

- [ ] **Step 2: 跑测试，确认失败**

- [ ] **Step 3: 最小实现**

按上面修正规则写 `TapClassifier.onDown` / `onWaitTimeout`。距离：`Math.hypot(dx, dy)`。

- [ ] **Step 4: 跑测试，确认通过**

- [ ] **Step 5: Commit**

```
git commit -m "feat: classify bar tap, double-tap delete, empty double-tap create"
```

---

### Task 7: WeekColumnLayout

**Files:**
- Create: `entry/src/main/ets/domain/week/WeekColumnLayout.ets`
- Test: `entry/src/ohosTest/ets/test/WeekColumnLayout.test.ets`

**Interfaces:**
- Consumes: `Task`, `DaySegmenter`, `WallClock`
- Produces:
  - `class WeekSlot` 字段与 `GanttDay/lib/ui/week/week_column_layout.dart` 的 `WeekSlot` 相同
  - `layoutWeekSlots(weekMonday: Date, tasks: Task[]): WeekSlot[]`

`weekMonday` 必须先归一到当地 00:00。周一用 `Date.getDay()`：JS 周日=0，周一=1。归一：

```ets
export function dateOnly(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

export function mondayOnOrBefore(d: Date): Date {
  const day = dateOnly(d);
  const jsDay = day.getDay(); // 0 Sun .. 6 Sat
  const back = jsDay === 0 ? 6 : jsDay - 1;
  return new Date(day.getFullYear(), day.getMonth(), day.getDate() - back);
}
```

- [ ] **Step 1: 写失败测试**

对照 `GanttDay/test/ui/week_column_layout_test.dart`，`monday = new Date(2026, 7, 3)`：

1. 8/5 09:30–12:00「拍摄」：`dayIndex === 2`，`topFrac ≈ 9.5/24`，`heightFrac ≈ 2.5/24`，`columnIndex 0`，`columnCount 1`
2. 8/4 18:00–8/6 10:00：`dayIndex` 为 `[1,2,3]`，高度分别为 `6/24`、`1`、`10/24`
3. 拍摄 + 面试重叠 + 13:15 剪辑：拍摄/面试 `columnCount === 2` 且 index 为 `{0,1}`；剪辑 `columnCount === 1`

浮点用 `Math.abs(a-b) < 1e-9`。

- [ ] **Step 2: 跑测试，确认失败**

- [ ] **Step 3: 最小实现**

对照 `GanttDay/lib/ui/week/week_column_layout.dart` 全文移植（含并查集 `columnCount`）。不要改算法。

- [ ] **Step 4: 跑测试，确认通过**

- [ ] **Step 5: Commit**

```
git commit -m "feat: add week column layout"
```

---

### Task 8: MonthSpanLayout

**Files:**
- Create: `entry/src/main/ets/domain/month/MonthSpanLayout.ets`
- Test: `entry/src/ohosTest/ets/test/MonthSpanLayout.test.ets`

**Interfaces:**
- Consumes: `Task`, `GanttSegment`, `LaneLayout`, `WallClock`，以及 Task 7 的 `dateOnly` / `mondayOnOrBefore`（可把这两个函数放到 `domain/time/Calendar.ets` 以免 week/month 互相 import UI）
- Produces:
  - `kMonthMaxBarsPerDay = 10`
  - `selectVisibleMonthTasks(month: Date, tasks: Task[]): MonthTaskSelection`
  - `buildMonthWeekLayouts(month, tasks, overflowByDay): MonthWeekLayout[]`
  - `dayTimeWindowFor(day0, tasks): DayTimeWindow`
  - `isSameCalendarDaySpan(start, end): boolean`

若 Task 7 把 `dateOnly` / `mondayOnOrBefore` 留在 week 文件，本任务先抽到 `domain/time/Calendar.ets`，week 改为 import Calendar。这是允许的拆分。

- [ ] **Step 1: 写失败测试**

对照 `GanttDay/test/ui/month_span_layout_test.dart` 全部用例（same-day 填满格子、双任务窗口 9–17、跨日 0–24、跨周切断、12 条保留 10 且 `overflowByDay[10]===2`、恰午夜结束无次日、`dayTimeWindowFor` 忽略跨日任务）。`month = new Date(2026, 7, 1)`。

- [ ] **Step 2: 跑测试，确认失败**

- [ ] **Step 3: 最小实现**

对照 `GanttDay/lib/ui/month/month_span_layout.dart` 全文移植。`Date.add` 用 `new Date(y, m, d + n)`。

- [ ] **Step 4: 跑测试，确认通过**

- [ ] **Step 5: Commit**

```
git commit -m "feat: add month span layout"
```

---

### Task 9: TaskRepository 接口与内存适配器

**Files:**
- Create: `entry/src/main/ets/platform/TaskRepository.ets`
- Create: `entry/src/main/ets/data/MemoryTaskRepository.ets`
- Create: `entry/src/main/ets/domain/gantt/FactorySwatches.ets`（仅常量，供 upsert 默认 `autoSwatchId`）
- Create: `entry/src/main/ets/domain/models/ColorSwatch.ets`
- Test: `entry/src/ohosTest/ets/test/MemoryTaskRepository.test.ets`

**Interfaces:**
- Consumes: `Task`, `WallClock`
- Produces:

```ets
export class EmptyTitleError {
  message: string = 'title is empty';
}

export interface TaskListener {
  onTasks(tasks: Task[]): void;
}

export interface TaskRepository {
  watchOverlapping(rangeStart: number, rangeEnd: number, listener: TaskListener): () => void;
  getById(id: string): Promise<Task | null>;
  upsert(task: Task): Promise<void>;
  delete(id: string): Promise<void>;
}
```

相交：`plannedStart < rangeEnd && plannedEnd > rangeStart`。

`upsert`：`title.trim().length === 0` 则 reject `EmptyTitleError`，不写入。`plannedEnd < plannedStart + 15` 则在写入前把 end 调成 start+15。

订阅后立刻 `onTasks` 一次当前快照；之后每次 upsert/delete 向所有仍相交的订阅推送。

- [ ] **Step 1: 写失败测试**

用 `MemoryTaskRepository`。造一条 8/8 23:00–8/9 01:00。

- 窗口 `[8/8 00:00, 8/9 00:00)` 能看到
- 窗口 `[8/9 00:00, 8/10 00:00)` 也能看到
- 窗口 `[8/10, 8/11)` 看不到
- upsert 后 watch 收到新列表
- delete 后列表为空
- `upsert` 空标题 reject
- `getById` 删除后为 null

- [ ] **Step 2: 跑测试，确认失败**

- [ ] **Step 3: 最小实现**

内存数组 + listener 列表。`FactorySwatches.DEFAULT_ID = 'azure'`。`ColorSwatch` 对照 Dart 字段（本任务只为后续种子，测仓库不必读色卡）。

- [ ] **Step 4: 跑测试，确认通过**

- [ ] **Step 5: Commit**

```
git commit -m "feat: add TaskRepository memory adapter"
```

---

### Task 10: RDB 建库、种子、损坏改名

**Files:**
- Create: `entry/src/main/ets/data/AppDatabase.ets`
- Create: `entry/src/main/ets/data/RdbTaskRepository.ets`
- Test: `entry/src/ohosTest/ets/test/AppDatabase.test.ets`

**Interfaces:**
- Consumes: `TaskRepository`, `FactorySwatches`, `@kit.ArkData` relationalStore, `@kit.CoreFileKit` fileIo
- Produces:
  - `AppDatabase.SCHEMA_VERSION = 2`
  - `AppDatabase.FILE_NAME = 'gantday.db'`
  - `AppDatabase.openOrRepair(context): Promise<RdbStore>`
  - `class DatabaseOpenError { message: string; path: string }`
  - `RdbTaskRepository` 实现 `TaskRepository`
  - 损坏时：把库文件 rename 为 `gantday.db.corrupt-<yyyyMMddHHmmss>` 再 `open` 新库

表 SQL 必须与 Windows schema 2 一致（对照 `GanttDay/lib/data/sqlite/app_database.dart`）：

```
color_swatch(id, name, argb, hue, saturation, lightness, is_default, sort_order, slate)
task(id, title, planned_start, planned_end, actual_start, actual_end, is_done, primary_tag_id, auto_swatch_id, override_swatch_id, notes, created_at)
tag(id, name, swatch_id)
task_tag(task_id, tag_id)
setting(key, value)
```

索引：`idx_task_planned_start`、`idx_task_planned_end`。

新库插入 `FactorySwatches.ALL`（8 张，对照 `factory_swatches.dart`，含 `azure` 0xFF457BD9）以及 setting：`visibleStartHour=8`、`visibleEndHour=22`、`urgencyWindowDays=7`。

`RdbTaskRepository.upsert` 写入第一期使用的列；`actual_*` NULL、`is_done=0`、`auto_swatch_id='azure'`。

- [ ] **Step 1: 写失败测试**

`AppDatabase.test.ets`（需要设备上下文：`getContext(this)` 在测试里用 Hypium 的 context）：

1. `openOrRepair` 成功后能 `INSERT` 一条 task 再 `SELECT` 回来，标题与分钟数一致
2. 相交查询跨夜两条窗口都能查到（与 Task 9 相同例子）
3. 把库文件写成非法字节后 `openOrRepair`：目录下存在 `gantday.db.corrupt-` 前缀文件，且新库能再插入

- [ ] **Step 2: 跑测试，确认失败**

- [ ] **Step 3: 最小实现**

`openOrRepair`：try `getRdbStore`；catch 则 rename + 再开。种子用 `INSERT OR IGNORE`。`RdbTaskRepository.watchOverlapping`：每次写后 `query` 再通知 listener（可用简单轮询/写后推送，不要上云）。

- [ ] **Step 4: 跑测试，确认通过**

- [ ] **Step 5: Commit**

```
git commit -m "feat: add RDB schema, factory swatches, corrupt rename"
```

---

### Task 11: AppShell 与日/周/月底栏

**Files:**
- Create: `entry/src/main/ets/ui/theme/AppColors.ets`
- Create: `entry/src/main/ets/ui/shell/ViewNavBar.ets`
- Create: `entry/src/main/ets/ui/shell/AppShell.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`（只放 `AppShell`）
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets` 若需传入 repository：先注入 `MemoryTaskRepository`，Task 16 再换 RDB

**Interfaces:**
- Consumes: 无领域新接口
- Produces:
  - `AppColors.AZURE = 0xFF457BD9`
  - `AppShell` 状态：`anchorDate: Date`、`navIndex: 0|1|2`
  - 顶栏：`GanttDay`、‹、日期、›、`今天`
  - 日标题 `YYYY-MM-DD`；周「M月 · 第N周」（周起周一，N 为月内周序号，对照 `app_shell.dart` `_weekOfMonth`）；月 `YYYY-MM`
  - 翻页：日 ±1 天；周 ±7；月 ±1 月
  - `ViewNavBar` 高 56vp，三等分图标，选中用 `AZURE`
  - 三个内容区先放占位 `Text('日'|'周'|'月')`，下一 Task 替换日

- [ ] **Step 1: 手工可验（本任务无 Hypium）**

编译安装到平板或模拟器。检查：底栏切换三页；日/周/月标题格式；前进后退；今天回到系统当天。无标签、无设置齿轮。

- [ ] **Step 2: 实现外壳**

日期格式自己写 `pad2`，不要用本地化长串。`weekOfMonth` 必须与 `app_shell.dart` 的 `_weekOfMonth` 同公式（Dart `weekday`：周一=1 … 周日=7）：

```ets
function dartWeekday(d: Date): number {
  const js = d.getDay();
  return js === 0 ? 7 : js;
}

function weekOfMonth(date: Date): number {
  const first = new Date(date.getFullYear(), date.getMonth(), 1);
  return Math.floor((date.getDate() + dartWeekday(first) - 2) / 7) + 1;
}
```

对照 `GanttDay/lib/ui/shell/app_shell.dart` 与 `view_nav_bar.dart` 的间距。

- [ ] **Step 3: 设备上验收 Step 1**

- [ ] **Step 4: Commit**

```
git commit -m "feat: add app shell with day week month chrome"
```

---

### Task 12: 日视图 Canvas（网格、色条、拖移/缩放/平移）

**Files:**
- Create: `entry/src/main/ets/ui/day/DayGanttPage.ets`
- Modify: `AppShell.ets`：`navIndex===0` 时放 `DayGanttPage`

**Interfaces:**
- Consumes: `GanttGeometry`, `DaySegmenter`, `LaneLayout`, `DayGestureMath`, `TaskRepository`, `TapClassifier`（本任务先接拖动手势；单击/双击在 Task 13 接上也可以，但 hit-test 本任务就要写成函数，避免 Task 13 重写画布）
- Produces:
  - 默认 fit 8:00–22:00，可横向滚动到 00:00–24:00（轴仍是当天 `day0` 起的 1440 分钟；需要看跨夜次日段时用 `DaySegmenter`）
  - 色条填充 `AppColors.AZURE`，圆角约 4vp，标题白色单行
  - 重叠分行；行高约 28vp
  - 拖中部 → `proposeMove` → `upsert`
  - 两端约 8vp 热区 → resize
  - 空白短拖平移 Scroll；`pan` 进行中 `hitTestBehavior` 不把事件交给系统侧滑返回（对画布包一层并在拖色条时 `stopPropagation`）
  - 拖色条期间不要改 `navIndex` / `anchorDate`

Hit-test 纯函数放在 `DayGanttPage.ets` 同目录 `DayHitTest.ets`：输入 bars 的像素矩形 + (x,y)，输出 `taskId | null` 与 `'move'|'resizeStart'|'resizeEnd'|'empty'`。

- [ ] **Step 1: 用 Memory 仓库预置两条重叠任务，编译运行**

在 `Index` / Ability 里 seed：8/8 09:00–12:00 与 10:00–12:00。Expected：两条分行；拖动后重启（若仍是 Memory 则重启丢失，本任务可先不要求重启保留）。

- [ ] **Step 2: 实现绘制与拖动手势**

对照 `day_gantt_painter.dart` 的小时竖线、当前时间线可选。Canvas：`CanvasRenderingContext2D`。每帧用当前 `geo.widthPx = canvasWidth`。

- [ ] **Step 3: 设备验收拖移 / 缩放 / 空白平移 / 重叠分行 / 跨夜两段（预置 23:00–01:00）**

- [ ] **Step 4: Commit**

```
git commit -m "feat: draw day gantt and drag to move or resize"
```

---

### Task 13: 双击创建、双击删除、右侧抽屉

**Files:**
- Create: `entry/src/main/ets/ui/day/CreateTaskPopup.ets`
- Create: `entry/src/main/ets/ui/common/DeleteConfirm.ets`
- Create: `entry/src/main/ets/ui/common/SideDrawer.ets`
- Create: `entry/src/main/ets/ui/task/TaskForm.ets`
- Modify: `DayGanttPage.ets`：接 `TapClassifier`；拖一旦成立则丢掉本次 tap 状态

**Interfaces:**
- Consumes: `TapClassifier`, `proposeCreateAt`, `TaskRepository`
- Produces:
  - `DeleteConfirm.show(title): Promise<boolean>` 文案：`删除「${title}」？此操作无法撤销。` 按钮「取消」「删除」
  - `CreateTaskPopup`：宽 300vp，锚在预览条下方（放不下就上方），标题输入，确认 / 取消
  - `SideDrawer`：宽 `clamp(360, 0.4*screen, 480)`，从右滑入，遮罩模糊；点遮罩关闭
  - `TaskForm`：标题、计划开始、计划结束（15 分钟步进）；删除走同一 `DeleteConfirm`
  - 关抽屉：标题 trim 非空则 upsert 标题+时间；空标题只存时间

单击：`onDown` 得 `Wait` 后启动 300ms timer，`onWaitTimeout` → `OpenForm`。第二次 `Delete` 则取消 timer。拖动手势 start 时取消 timer 与 prev tap。

- [ ] **Step 1: 设备验收清单（本任务结束后必须全过）**

1. 空白双击 → 1 小时预览 + 标题框；确认后出现色条
2. 标题框取消 / 点外面 → 不建
3. 单击色条（等约 300ms）→ 抽屉；改标题或时间，关抽屉后保留
4. 双击色条 → 确认框；取消则条还在且抽屉没开；确认则条消失
5. 跨午夜两段，双击任一段删整条
6. 抽屉内删除同样确认

- [ ] **Step 2: 实现弹层与手势接线**

`CreateTaskPopup` 对照 `create_task_popup.dart` 的定位（clamp 到屏幕 8vp 边距）。不要用居中 `AlertDialog` 当创建框。删除确认可以用系统 `AlertDialog`。

- [ ] **Step 3: 按 Step 1 在平板上点一遍**

- [ ] **Step 4: Commit**

```
git commit -m "feat: double-tap create and delete with side drawer form"
```

---

### Task 14: 周视图

**Files:**
- Create: `entry/src/main/ets/ui/week/WeekPage.ets`
- Modify: `AppShell.ets`：`navIndex===1` 用 `WeekPage`

**Interfaces:**
- Consumes: `layoutWeekSlots`, `TaskRepository`, `TapClassifier`（任务块上单击 / 双击；空白不创建）
- Produces:
  - 列 = 周一…周日，行 = 0:00–24:00，小时行高 48vp，左刻度 52vp，日界 1vp 红线两侧各 3vp（对照 `week_gantt_page.dart`）
  - 默认竖向滚到 8:00
  - 今天列表头高亮 `AZURE`
  - 点任务块一下（等双击窗口）→ 同一 `SideDrawer`+`TaskForm`
  - 双击任务块 → 同一 `DeleteConfirm`
  - 点日期表头 → `navIndex=0` 且 `anchorDate` 为该日
  - 不拖改时间、不空白创建

- [ ] **Step 1: 预置跨日 + 重叠任务，编译**

- [ ] **Step 2: 实现 WeekPage**

块几何：`top = topFrac * 24 * 48`，`height = heightFrac * 24 * 48`，水平按 `columnIndex/columnCount` 均分列宽。

- [ ] **Step 3: 验收表头进日、点块开抽屉、双击删除、重叠并排、跨日切开**

- [ ] **Step 4: Commit**

```
git commit -m "feat: add week calendar view"
```

---

### Task 15: 月视图

**Files:**
- Create: `entry/src/main/ets/ui/month/MonthPage.ets`
- Modify: `AppShell.ets`：`navIndex===2` 用 `MonthPage`

**Interfaces:**
- Consumes: `selectVisibleMonthTasks`, `buildMonthWeekLayouts`
- Produces:
  - 周行：上日期、下色条；条高 15vp，间隙 2vp
  - 只显示标题；默认色
  - 本月格 / `+N` / 色条点击 → `onOpenDay`（色条用 `bar.openDay`）
  - 非本月格子不可点
  - 双击不删除、不创建、不拖改期
  - 每日最多 10 条 + `+N`

- [ ] **Step 1: 预置跨周任务与 12 条同日任务**

- [ ] **Step 2: 实现 MonthPage**

条的左 = `startFrac / 7 * weekWidth`，宽 = `(endFrac-startFrac)/7 * weekWidth`，最小宽 4vp。

- [ ] **Step 3: 验收跨日连续条、跨周两段、+N、点进日视图、双击不删**

- [ ] **Step 4: Commit**

```
git commit -m "feat: add month span-bar view"
```

---

### Task 16: 启动接 RDB 与损坏屏

**Files:**
- Create: `entry/src/main/ets/ui/common/DbErrorScreen.ets`
- Modify: `EntryAbility.ets` / `Index.ets`：`AppDatabase.openOrRepair` 成功则把 `RdbTaskRepository` 注入 `AppShell`；失败先展示 `DbErrorScreen`（说明已改名，按钮「重建」再 `openOrRepair`）
- 去掉启动时的 Memory seed（测试数据不要进产品路径）

**Interfaces:**
- Consumes: `AppDatabase`, `RdbTaskRepository`
- Produces: 杀进程再开，任务还在

- [ ] **Step 1: 创一条任务，杀进程，再开，任务仍在**

- [ ] **Step 2: 实现启动接线**

写失败 toast：`promptAction.showToast({ message: '保存失败' })`，不要崩溃。

- [ ] **Step 3: 再验一次杀进程保留**

- [ ] **Step 4: Commit**

```
git commit -m "feat: persist tasks in RDB and surface corrupt-db repair"
```

---

### Task 17: 规格手工验收

**Files:** 不改代码，除非验收失败则回到对应 Task 修并补测。

对照规格第 8 节清单，在 MatePad 或平板模拟器上全部勾完：

- 日：拖移、缩放、平移、双击空白创建、单击开表单、双击删除确认/取消、跨夜两段
- 周：点块、双击删除、点表头进日
- 月：点条与 `+N` 进日；双击不删
- 抽屉保存与删除
- 无标签、无设置、无完成轴

- [ ] **Step 1: 按清单操作并记下失败项**

- [ ] **Step 2: 失败则修代码，补一条会失败过的领域测试（若属领域），再提交 `fix:`**

- [ ] **Step 3: 清单全绿后收尾提交（若有未提交修复）**

---

## Spec coverage（自检）

| 规格 | 任务 |
| --- | --- |
| 墙钟 / 几何 / 切段 / 分行 | 2–4 |
| 日手势数学、60 分钟创建 | 5 |
| 单击 vs 双击 | 6, 13 |
| 周 / 月布局 | 7, 8 |
| Repository 与内存 | 9 |
| RDB / 种子 / 损坏改名 | 10, 16 |
| 外壳顶栏底栏 | 11 |
| 日画面与拖动 | 12 |
| 创建框、删除确认、抽屉 | 13 |
| 周 / 月页面 | 14, 15 |
| 手工验收 | 17 |
| 第二期明确不做的能力 | 未建任务 |

## Type consistency

- 时间一律 `number`（墙钟分钟），不用 `Date` 存库
- 仓库方法名是 `watchOverlapping` / `getById` / `upsert` / `delete`
- 默认色卡 id 字符串 `'azure'`
- `TapDecision` 与 UI 分支同名
- `WeekSlot` / `MonthPlacedBar` 字段名与 Windows 版一致，便于对照测试数字
