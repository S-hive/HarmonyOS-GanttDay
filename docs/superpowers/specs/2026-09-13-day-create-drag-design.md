# 日视图双击按住拖拽创建

- 状态：用户已审阅通过
- 日期：2026-09-13
- 工作名：HarmonyOS-GanttDay
- 修订：替换第一期规格 §3.5「空白双击立刻 60 分钟条」的创建路径
- 参考：`d:\javaFail\GanttDay` 的 `day_gantt_gestures.dart`（长按拖创建 + 边缘扩轴）；本仓库用手势 B 代替长按

## 1. 目标

日视图创建与 Windows 版「拖出时间条、松手再命名」一致，但触发改为平板手势：

1. 空白处点一下，再在空白处**第二次按下并按住拖**，划出计划起止。
2. 松手且拖出足够距离后，弹出已有「新任务」标题框（只要任务名）。
3. 拖到视口左右边缘时，按 Windows 规则**压缩小时、加长可见时段**，不切日、不切底栏。

不改周 / 月创建（第一期周月仍不创建）。标签、色卡、完成轴仍不做。

## 2. 手势

沿用 `TapClassifier`：两次空白落点距离 ≤ 32vp，间隔 ≤ 500ms（从第一下**抬手**起算）→ `Create`。点在已有色条上仍走开表单 / 双击删除，不进入创建。

| 操作 | 结果 |
| --- | --- |
| 空白单击（双击窗口结束） | 无事 |
| 空白第二次按下 | 进入创建拖拽。`x0` = 按下点。预览为 `proposeCreate(geo, x0, x0)`（最短 15 分钟，15 分钟吸附） |
| 第二次按住移动 | `x1` 跟随手指，预览 = `proposeCreate(geo, x0, x1)`。左右拖均可，起止自动排序。允许跨午夜 |
| 抬手且 `|x1 − x0| < 4`（与按下同一套画布 x，单位 vp） | 取消：预览消失，不写库，不武装。必须重新「点一下再按住拖」 |
| 抬手且 `|x1 − x0| ≥ 4` | 预览保留，打开标题框 |
| 已有色条单击 / 双击 / 拖 | 不变：等双击窗口后开抽屉；双击确认删除；拖中部平移、拖两端缩放 |
| 创建拖拽进行中 | 不切日、不切底栏、空白短拖不平移时间轴；边缘扩轴见 §3 |
| 标题框打开后 | 不再认创建拖拽 |

取消的路径（均不写库）：第二下抬手不足 4vp；标题框点取消或点遮罩；系统打断（Touch Cancel）。

不再使用：双击立刻 60 分钟条；长按 350ms 创建；第二下轻点后武装再滑。`proposeCreateAt` 可留在领域层，界面创建不再调用。

## 3. 创建时的时间轴

对照 Windows `_onDragTime` + `expandProbeFromOverscroll` + `computeDayFitMinutes`。

- **默认 / 无创建探针**：可见窗由 `computeDayFitMinutes(8, 22, 当日任务段, [])` 得出。没有超出 8–22 的任务时，**8:00–22:00 铺满视口**。
- **边缘带**：相对 Canvas **可见宽**的左右各 56vp（视口坐标，不是含横向滚动的内容 x）。默认 8–22 铺满时可见宽 = 画布宽。手指进入后，按压入深度把探针时间往外推（`expandProbeFromOverscroll`）。`edgeBase` 取**刚进入边缘带时**的 view 边，避免每帧 +1 小时。
- **扩窗**：探针并入 `alsoInclude`，可见窗按整小时加长，画布宽度仍等于视口宽 → 小时变窄。左不早于当日 0:00，右最多 `day0 + 7×1440`（`kDayViewMaxSpanMinutes`）。
- **贴边重复**：手指留在更外侧（约边缘带外侧 35%）时，每 180ms 再加一小时，上限同上。
- **锚点**：扩窗时尽量钉住扩窗前视口中心对应的墙钟时刻，避免整轴乱跳。
- **创建结束**（确认插入、取消、抬手取消）：清掉本次 sticky / 探针，再按当日任务重算 fit。新插入且超出 8–22 的任务会留在新 fit 里；取消则回到创建前的任务 fit（通常仍是 8–22 铺满）。
- **非创建空白短拖**：只平移**当前已经更宽于视口**的轴，不靠边缘压缩。已有色条拖到边缘**本次不扩轴**（Windows 会扩；需要时复用同一套函数另开任务）。

第一期原文「左右滑动查看 0–8 / 22–24」在默认 8–22 铺满时不再靠滑动露出来；那些小时靠创建拖到边缘，或当日已有任务把 fit 撑开。

## 4. 弹窗与保存

沿用 `CreateTaskPopup`，不加标签。

- 宽约 300px，锚在预览条旁，不是正中对话框。
- 字段：标题「新任务」、吸附后的起止文案、任务名、取消 / 确认。
- 确认且 `trim(title)` 非空 → `TaskRepository.upsert`：给定起止、标题、`autoSwatchId = azure`、新 UUID、`createdAt` 为当前墙钟分钟。`primaryTagId` / 备注 / 实际时间保持空。
- `trim(title)` 为空 → 不插入，预览关掉，fit 按 §3 重算。
- 取消或点遮罩 → 不插入，同样重算 fit。
- 进入 Repository 之前时长已是 ≥ 15 分钟（`proposeCreate` / `clampDuration`）。

抽屉编辑、删除确认、周 / 月行为不变。

## 5. 模块

调用方只依赖小接口；手势规则不进 Canvas 绘制细节。

| 模块 | 接口 | 藏什么 |
| --- | --- | --- |
| `TapClassifier` | 已有 `onDown` | 双击窗口、32vp、Create vs Delete vs Wait |
| `CreateStroke`（新，纯 ArkTS） | `begin(x)` / `move(x)` / `end(x)` → 预览跨度或 `Cancel` / `OpenPopup` | 4vp 阈值；不武装 |
| `DayGestureMath` | 已有 `proposeCreate`、`expandProbeFromOverscroll` | 吸附、最短 15、边缘探针 |
| `DayVisibleRange` | 已有 `computeDayFitMinutes`、`expandFitMinutes` | fit 加长、7 日上限 |
| `DayGanttPage` | 消费上述结果 | 画预览、边缘带与 180ms 重复、禁切页、打开弹窗、`upsert` |
| `CreateTaskPopup` | 已有确认 / 取消 | 锚点几何、只要标题 |

`CreateStroke` 与 `domain/gesture/` 同层，禁止 import ArkUI / RDB。页面在 `Create` 判定后把指针坐标交给它；边缘探针与 fit 由页面用已有函数更新 `GanttGeometry`，再拿新 geo 去 `proposeCreate`。

数据流：手指 → `CreateStroke` + 边缘探针 → 预览 `Task`（不入库）→ 弹窗确认 → `TaskRepository.upsert` → `watchOverlapping` 推送 → 重绘。取消路径不调用 `upsert`。

## 6. 测试

领域单测（Hypium，`entry@ohosTest`，并在 `List.test.ets` 注册）：

- `CreateStroke`：按下后移动，预览起止等于 `proposeCreate`；抬手位移小于 4vp → Cancel，再次 `begin` 前 `move` 无效（证明不武装）；抬手位移至少 4vp → OpenPopup，跨度保留。
- 已有 `proposeCreate` / `expandProbeFromOverscroll` / `expandFitMinutes` 保持；补一条「探针并入 `computeDayFitMinutes` 后 end 按整小时变长」。
- 确认空标题不插入：沿用 `MemoryTaskRepository` 空标题拒绝（或创建页用的同一校验）。

第一期仍不做端到端自动点按。手工验收：

- 第二下按住拖出预览条，松手出标题框，输入名称后任务出现。
- 第二下点一下就抬 → 无条、无框。
- 拖到视口右（或左）缘 → 小时变窄、可见窗加长；取消或未保存关闭后，无新任务时回到 8–22 铺满。
- 点已有色条仍开抽屉；双击仍先确认再删。
- 创建拖拽中底栏 / 顶栏翻日不触发。

## 7. 非目标

- 创建框里的标签、色卡、备注。
- 已有色条拖到边缘扩轴。
- 恢复长按 350ms 创建，或双击立刻 60 分钟条。
- 周 / 月视图创建或拖改时间。
- 缩放手势（Windows 滚轮缩放本期不做）。
