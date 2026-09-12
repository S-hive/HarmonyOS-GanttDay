export class ColorSwatch {
  id: string;
  name: string;
  argb: number;
  hue: number;
  saturation: number;
  lightness: number;
  sortOrder: number;
  isDefault: boolean;
  slate: boolean;

  constructor(
    id: string,
    name: string,
    argb: number,
    hue: number,
    saturation: number,
    lightness: number,
    sortOrder: number,
    isDefault: boolean = false,
    slate: boolean = false
  ) {
    this.id = id;
    this.name = name;
    this.argb = argb;
    this.hue = hue;
    this.saturation = saturation;
    this.lightness = lightness;
    this.sortOrder = sortOrder;
    this.isDefault = isDefault;
    this.slate = slate;
  }
}
