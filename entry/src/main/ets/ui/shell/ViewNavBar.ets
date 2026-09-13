import { AppColors } from '../theme/AppColors';

@Component
export struct ViewNavBar {
  @Prop selectedIndex: number = 0;
  onSelect: (index: number) => void = (_index: number) => {
  };

  build() {
    Row() {
      this.tabItem(0)
      this.tabItem(1)
      this.tabItem(2)
    }
    .width('100%')
    .height(AppColors.CHROME_BAR_HEIGHT)
    .backgroundColor(AppColors.NAV_BACKGROUND)
  }

  @Builder
  tabItem(index: number) {
    Column() {
      if (this.selectedIndex === index) {
        this.tabGlyph(index, AppColors.AZURE)
      } else {
        this.tabGlyph(index, AppColors.NAV_ICON_IDLE)
      }
    }
    .width('33.33%')
    .height(AppColors.CHROME_BAR_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onSelect(index);
    })
  }

  @Builder
  tabGlyph(index: number, color: ResourceColor) {
    if (index === 0) {
      SymbolGlyph($r('sys.symbol.hourglass'))
        .fontSize(22)
        .fontColor([color])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
    } else if (index === 1) {
      SymbolGlyph($r('sys.symbol.rectangle_split_3x1'))
        .fontSize(22)
        .fontColor([color])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
    } else {
      SymbolGlyph($r('sys.symbol.calendar'))
        .fontSize(22)
        .fontColor([color])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
    }
  }
}
