export const SIDE_DRAWER_MIN: number = 360;
export const SIDE_DRAWER_MAX: number = 480;
export const SIDE_DRAWER_FRACTION: number = 0.4;
export const DRAWER_SWIPE_DISMISS_FRACTION: number = 0.25;

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

export function shouldDismissDrawerSwipe(offsetX: number, panelWidth: number): boolean {
  if (panelWidth <= 0) {
    return false;
  }
  return offsetX >= panelWidth * DRAWER_SWIPE_DISMISS_FRACTION;
}

let drawerCloser: (() => void) | null = null;

export function bindDrawerCloser(closer: (() => void) | null): void {
  drawerCloser = closer;
}

export function consumeDrawerSystemBack(): boolean {
  if (drawerCloser === null) {
    return false;
  }
  drawerCloser();
  return true;
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

  aboutToAppear(): void {
    bindDrawerCloser(() => {
      this.onClose();
    });
  }

  aboutToDisappear(): void {
    bindDrawerCloser(null);
  }

  onBackPress(): boolean {
    this.onClose();
    return true;
  }

  private finishPanelSwipe(offsetX: number): void {
    if (shouldDismissDrawerSwipe(offsetX, sideDrawerWidthFor(this.screenWidth))) {
      this.onClose();
    }
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
      .gesture(
        PanGesture({ direction: PanDirection.Right, distance: 16 })
          .onActionEnd((event: GestureEvent) => {
            this.finishPanelSwipe(event.offsetX);
          })
      )
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.End)
    .transition(TransitionEffect.move(TransitionEdge.END))
  }
}
