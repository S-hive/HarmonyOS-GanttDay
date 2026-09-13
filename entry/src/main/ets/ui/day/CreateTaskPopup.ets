import { WallClock } from '../../domain/time/WallClock';

export const CREATE_POPUP_WIDTH: number = 300;
export const CREATE_POPUP_GAP: number = 8;
export const CREATE_POPUP_ESTIMATED_H: number = 128;
export const CREATE_POPUP_MARGIN: number = 8;
export const CREATE_POPUP_RADIUS: number = 12;

export class PopupRect {
  x: number = 0;
  y: number = 0;
  width: number = CREATE_POPUP_WIDTH;
}

function clamp(value: number, min: number, max: number): number {
  if (max < min) {
    return min;
  }
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

export function createPopupRect(
  anchorX: number,
  anchorY: number,
  _anchorW: number,
  anchorH: number,
  screenW: number,
  screenH: number
): PopupRect {
  const rect: PopupRect = new PopupRect();
  rect.width = CREATE_POPUP_WIDTH;
  rect.x = clamp(anchorX, CREATE_POPUP_MARGIN, screenW - CREATE_POPUP_WIDTH - CREATE_POPUP_MARGIN);
  let top: number = anchorY + anchorH + CREATE_POPUP_GAP;
  if (top + CREATE_POPUP_ESTIMATED_H > screenH - CREATE_POPUP_MARGIN) {
    top = anchorY - CREATE_POPUP_ESTIMATED_H - CREATE_POPUP_GAP;
  }
  rect.y = clamp(top, CREATE_POPUP_MARGIN, screenH - CREATE_POPUP_ESTIMATED_H - CREATE_POPUP_MARGIN);
  return rect;
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

export function formatSpanDuration(start: number, end: number): string {
  let mins: number = end - start;
  if (mins < 0) {
    mins = 0;
  }
  const h: number = Math.floor(mins / 60);
  const m: number = mins % 60;
  if (h <= 0) {
    return `${m}m`;
  }
  if (m === 0) {
    return `${h}h`;
  }
  return `${h}h ${m}m`;
}

export function formatBarTimeLabel(start: number, end: number): string {
  const a: Date = WallClock.dateTime(start);
  const b: Date = WallClock.dateTime(end);
  return `${pad2(a.getHours())}:${pad2(a.getMinutes())} – ${pad2(b.getHours())}:${pad2(b.getMinutes())} (${formatSpanDuration(start, end)})`;
}

export function formatBarCaption(title: string, start: number, end: number): string {
  const name: string = title.trim();
  const meta: string = formatBarTimeLabel(start, end);
  if (name.length === 0) {
    return meta;
  }
  return `${name}  ${meta}`;
}

@CustomDialog
export struct CreateTaskPopup {
  controller?: CustomDialogController;
  start: number = 0;
  end: number = 0;
  onConfirm: (title: string) => void = (_title: string) => {
  };
  onCancel: () => void = () => {
  };
  @State title: string = '';

  private closeSelf(): void {
    if (this.controller !== undefined) {
      this.controller.close();
    }
  }

  private confirm(): void {
    this.onConfirm(this.title);
    this.closeSelf();
  }

  private cancel(): void {
    this.onCancel();
    this.closeSelf();
  }

  build() {
    Column() {
      Text(formatBarTimeLabel(this.start, this.end))
        .fontSize(13)
        .fontColor('#232429')
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ bottom: 6 })
      TextInput({ text: this.title, placeholder: '任务名' })
        .id('createTaskTitle')
        .type(InputType.Normal)
        .placeholderColor('#8FB4E8')
        .caretColor('#457BD9')
        .fontColor('#232429')
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0, top: 8, bottom: 8 })
        .height(40)
        .width('100%')
        .textAlign(TextAlign.Start)
        .defaultFocus(true)
        .onChange((value: string) => {
          this.title = value;
        })
        .onSubmit((_type: EnterKeyType) => {
          this.confirm();
        })
      Divider()
        .color('#457BD9')
        .strokeWidth(1)
      Row() {
        Button('取消', { type: ButtonType.Normal })
          .fontSize(14)
          .fontColor('#232429')
          .height(40)
          .backgroundColor('#EEF2F7')
          .borderRadius(CREATE_POPUP_RADIUS)
          .layoutWeight(1)
          .onClick(() => {
            this.cancel();
          })
        Button('创建', { type: ButtonType.Normal })
          .fontSize(14)
          .fontColor(Color.White)
          .height(40)
          .backgroundColor('#457BD9')
          .borderRadius(CREATE_POPUP_RADIUS)
          .margin({ left: 8 })
          .layoutWeight(1)
          .onClick(() => {
            this.confirm();
          })
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width(CREATE_POPUP_WIDTH)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Color.White)
    .borderRadius(CREATE_POPUP_RADIUS)
    .shadow({ radius: 10, color: 0x42000000, offsetX: 0, offsetY: 4 })
  }
}
