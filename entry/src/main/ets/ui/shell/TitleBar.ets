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
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1a1b20')
        .flexShrink(0)
      Text('<')
        .fontSize(28)
        .fontColor('#1a1b20')
        .flexShrink(0)
        .padding({ left: 24, right: 8 })
        .onClick(() => {
          this.onPrev();
        })
      Text(this.dateLabel)
        .fontSize(16)
        .fontColor('#1a1b20')
        .flexShrink(0)
        .margin({ left: 4, right: 4 })
      Text('>')
        .fontSize(28)
        .fontColor('#1a1b20')
        .flexShrink(0)
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          this.onNext();
        })
      Text('今天')
        .fontSize(16)
        .fontColor(AppColors.AZURE)
        .flexShrink(0)
        .padding({ left: 12, right: 8 })
        .onClick(() => {
          this.onToday();
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White)
  }
}
