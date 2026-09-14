export const DELETE_VEIL_TOP: number = 0x73FF8A80;
export const DELETE_VEIL_BOTTOM: number = 0x7381C784;

let veilCloser: (() => void) | null = null;

export function bindDeleteVeilCloser(closer: (() => void) | null): void {
  veilCloser = closer;
}

export function consumeDeleteVeilBack(): boolean {
  if (veilCloser === null) {
    return false;
  }
  veilCloser();
  return true;
}

export function isDeleteVeilTop(y: number, height: number): boolean {
  return y * 2 < height;
}
