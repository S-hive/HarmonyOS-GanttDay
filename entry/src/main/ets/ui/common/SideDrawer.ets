export const SIDE_DRAWER_MIN: number = 360;
export const SIDE_DRAWER_MAX: number = 480;
export const SIDE_DRAWER_FRACTION: number = 0.4;

export function sideDrawerWidthFor(screenWidth: number): number {
  let width: number = screenWidth * SIDE_DRAWER_FRACTION;
  if (width < SIDE_DRAWER_MIN) {
    width = SIDE_DRAWER_MIN;
  }
  if (width > SIDE_DRAWER_MAX) {
    width = SIDE_DRAWER_MAX;
  }
  return width;
}

@Component
export struct SideDrawer {
  @Prop screenWidth: number = 800;
  onClose: () => void = () => {
  };
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(0x40000000)
        .backdropBlur(8)
        .onClick(() => {
          this.onClose();
        })
      Column() {
        this.content()
      }
      .width(sideDrawerWidthFor(this.screenWidth))
      .height('100%')
      .backgroundColor(Color.White)
      .borderRadius({ topLeft: 16, bottomLeft: 16 })
      .shadow({ radius: 16, color: 0x33000000, offsetX: -2, offsetY: 0 })
      .hitTestBehavior(HitTestMode.Block)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.End)
    .transition(TransitionEffect.move(TransitionEdge.END))
  }
}
