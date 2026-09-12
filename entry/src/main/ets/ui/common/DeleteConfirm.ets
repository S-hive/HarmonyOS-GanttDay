export function deleteConfirmMessage(title: string): string {
  return `删除「${title}」？此操作无法撤销。`;
}

export class DeleteConfirm {
  static show(title: string): Promise<boolean> {
    return new Promise<boolean>((resolve: (ok: boolean) => void) => {
      let settled: boolean = false;
      const finish = (ok: boolean): void => {
        if (settled) {
          return;
        }
        settled = true;
        resolve(ok);
      };
      AlertDialog.show({
        message: deleteConfirmMessage(title),
        autoCancel: true,
        alignment: DialogAlignment.Center,
        primaryButton: {
          value: '取消',
          action: () => {
            finish(false);
          }
        },
        secondaryButton: {
          value: '删除',
          fontColor: Color.Red,
          action: () => {
            finish(true);
          }
        },
        cancel: () => {
          finish(false);
        }
      });
    });
  }
}
