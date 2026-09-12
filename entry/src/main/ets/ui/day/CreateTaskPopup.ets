import { WallClock } from '../../domain/time/WallClock';

export const CREATE_POPUP_WIDTH: number = 300;
export const CREATE_POPUP_GAP: number = 8;
export const CREATE_POPUP_ESTIMATED_H: number = 168;
export const CREATE_POPUP_MARGIN: number = 8;

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

export function formatBarTimeLabel(start: number, end: number): string {
  const a: Date = WallClock.dateTime(start);
  const b: Date = WallClock.dateTime(end);
  return `${pad2(a.getHours())}:${pad2(a.getMinutes())}–${pad2(b.getHours())}:${pad2(b.getMinutes())}`;
}

@Component
export struct CreateTaskPopup {
  @Prop anchorX: number = 0;
  @Prop anchorY: number = 0;
  @Prop anchorW: number = 0;
  @Prop anchorH: number = 20;
  @Prop start: number = 0;
  @Prop end: number = 0;
  @Prop screenW: number = 800;
  @Prop screenH: number = 400;
  onConfirm: (title: string) => void = (_title: string) => {
  };
  onCancel: () => void = () => {
  };
  @State title: string = '';

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(0x1F000000)
        .onClick(() => {
          this.onCancel();
        })
      Column() {
        Text('新任务')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Text(formatBarTimeLabel(this.start, this.end))
          .fontSize(12)
          .fontColor(0x73000000)
          .margin({ top: 4, bottom: 10 })
        TextInput({ text: this.title, placeholder: '任务名' })
          .onChange((value: string) => {
            this.title = value;
          })
        Row() {
          Button('取消', { type: ButtonType.Normal })
            .backgroundColor(Color.Transparent)
            .fontColor(0xFF457BD9)
            .onClick(() => {
              this.onCancel();
            })
          Button('确认')
            .margin({ left: 8 })
            .onClick(() => {
              this.onConfirm(this.title);
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .margin({ top: 12 })
      }
      .width(CREATE_POPUP_WIDTH)
      .padding({ left: 16, right: 16, top: 14, bottom: 12 })
      .backgroundColor(Color.White)
      .borderRadius(12)
      .shadow({ radius: 10, color: 0x42000000, offsetX: 0, offsetY: 4 })
      .hitTestBehavior(HitTestMode.Block)
      .position({
        x: createPopupRect(this.anchorX, this.anchorY, this.anchorW, this.anchorH, this.screenW,
          this.screenH).x,
        y: createPopupRect(this.anchorX, this.anchorY, this.anchorW, this.anchorH, this.screenW,
          this.screenH).y
      })
    }
    .width('100%')
    .height('100%')
  }
}
