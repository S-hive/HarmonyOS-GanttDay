import { ColorSwatch } from '../models/ColorSwatch';

export class FactorySwatches {
  static readonly DEFAULT_ID: string = 'azure';

  static readonly ALL: ColorSwatch[] = [
    new ColorSwatch('azure', '霁蓝', 0xFF6198F6, 218, 0.893, 0.673, 0, true, false),
    new ColorSwatch('peach', '桃', 0xFFFFDAC1, 24, 1.0, 0.878, 1, false, false),
    new ColorSwatch('leaf', '芽绿', 0xFFE2F0CB, 83, 0.551, 0.869, 2, false, false),
    new ColorSwatch('mint', '薄荷', 0xFFB5EAD7, 158, 0.559, 0.814, 3, false, false),
    new ColorSwatch('lavender', '淡紫', 0xFFDDD6FE, 251, 0.951, 0.918, 4, false, false),
    new ColorSwatch('sky', '天空', 0xFFBAE6FD, 201, 0.943, 0.861, 5, false, false),
    new ColorSwatch('cream', '奶油', 0xFFFEF3C7, 48, 0.964, 0.888, 6, false, false),
    new ColorSwatch('gray', '灰', 0xFFDEE2E6, 211, 0.137, 0.886, 7, false, true)
  ];
}
