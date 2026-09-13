import { AppColors } from '../theme/AppColors';

@Component
export struct TitleBar {
  @Prop dateLabel: string = '';
  onPrev: () => void = () => {
  };
  onNext: () => void = () => {
  };
  onToday: () => void = () => {
  };

  build() {
    Row() {
      Text('GanttDay')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1a1b20')
        .flexShrink(0)
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(22)
        .fontColor(['#1a1b20'])
        .flexShrink(0)
        .padding({ left: 24, right: 8 })
        .onClick(() => {
          this.onPrev();
        })
      Text(this.dateLabel)
        .fontSize(14)
        .fontColor('#1a1b20')
        .flexShrink(0)
        .margin({ left: 4, right: 4 })
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(22)
        .fontColor(['#1a1b20'])
        .flexShrink(0)
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          this.onNext();
        })
      Text('今天')
        .fontSize(14)
        .fontColor(AppColors.AZURE)
        .flexShrink(0)
        .padding({ left: 12, right: 8 })
        .onClick(() => {
          this.onToday();
        })
    }
    .width('100%')
    .height(AppColors.CHROME_BAR_HEIGHT)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White)
  }
}
