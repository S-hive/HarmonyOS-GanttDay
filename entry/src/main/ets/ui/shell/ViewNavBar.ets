import { AppColors } from '../theme/AppColors';

@Component
export struct ViewNavBar {
  selectedIndex: number = 0;
  onSelect: (index: number) => void = (_index: number) => {
  };

  build() {
    Row() {
      this.tabItem(0, '日')
      this.tabItem(1, '周')
      this.tabItem(2, '月')
    }
    .width('100%')
    .height(56)
    .backgroundColor(AppColors.NAV_BACKGROUND)
  }

  @Builder
  tabItem(index: number, label: string) {
    Column() {
      Text(label)
        .fontSize(16)
        .fontColor(this.selectedIndex === index ? AppColors.AZURE : AppColors.ON_SURFACE_MUTED)
        .fontWeight(this.selectedIndex === index ? FontWeight.Medium : FontWeight.Regular)
    }
    .width('33.33%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onSelect(index);
    })
  }
}
