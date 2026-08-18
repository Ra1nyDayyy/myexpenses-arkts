import { Tag } from '../model/SupportEntities';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { router, promptAction } from '@kit.ArkUI';

/**
 * 标签输入对话框（鸿蒙原生 CustomDialog）
 */
@CustomDialog
export struct TagInputDialog {
  controller?: CustomDialogController;
  title: string = '新建标签';
  @State label: string = '';
  onConfirm: (label: string) => void = () => {
  };

  build() {
    Column() {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 16 })

      TextInput({ placeholder: '标签名称', text: this.label })
        .width('100%')
        .height(44)
        .backgroundColor($r('app.color.surfaceSecondary'))
        .onChange((v: string) => {
          this.label = v;
        })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor($r('app.color.surfaceSecondary'))
          .fontColor($r('app.color.textPrimary'))
          .onClick(() => {
            this.controller?.close();
          })
        Button('确定')
          .layoutWeight(1)
          .backgroundColor($r('app.color.primaryColor'))
          .onClick(() => {
            this.onConfirm(this.label);
            this.controller?.close();
          })
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .padding(20)
    .width('100%')
  }
}

/**
 * 标签管理页：对应 Android ManageTags
 */
@Entry
@Component
struct TagManage {
  @State tags: Tag[] = [];

  private repository: Repository = Repository.getInstance();
  private dialog: CustomDialogController = new CustomDialogController({
    builder: TagInputDialog({
      title: '新建标签',
      onConfirm: (label: string) => {
        this.addTag(label);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: false,
    cornerRadius: 12
  });

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.tags = await this.repository.getTags();
  }

  private openAddDialog(): void {
    this.dialog = new CustomDialogController({
      builder: TagInputDialog({
        title: '新建标签',
        onConfirm: (label: string) => {
          this.addTag(label);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: false,
      cornerRadius: 12
    });
    this.dialog.open();
  }

  private async addTag(label: string): Promise<void> {
    const trimmed = label.trim();
    if (!trimmed) {
      promptAction.showToast({ message: '请输入标签名称' });
      return;
    }
    try {
      await this.repository.insertTag(trimmed, 0xFF0050A7);
      await this.load();
      promptAction.showToast({ message: '标签已保存' });
    } catch (e) {
      promptAction.showToast({ message: `保存失败: ${(e as Error).message}` });
    }
  }

  private async deleteTag(tag: Tag): Promise<void> {
    promptAction.showDialog({
      title: '删除标签',
      message: `确定删除"${tag.label}"吗？`,
      buttons: [
        { text: '取消', color: '#808080' },
        { text: '删除', color: '#E53935' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.doDeleteTag(tag.id);
      }
    });
  }

  private async doDeleteTag(tagId: number): Promise<void> {
    try {
      await this.repository.deleteTag(tagId);
      await this.load();
      promptAction.showToast({ message: '标签已删除' });
    } catch (e) {
      promptAction.showToast({ message: `删除失败: ${(e as Error).message}` });
    }
  }

  build() {
    Column() {
      PageHeader({
        title: '标签',
        rightText: '+',
        onBack: () => {
          router.back();
        },
        onRight: () => {
          this.openAddDialog();
        }
      })

      List({ space: 8 }) {
        ForEach(this.tags, (tag: Tag) => {
          ListItem() {
            Row() {
              Circle()
                .width(12)
                .height(12)
                .fill(this.tagColor(tag.color))
                .margin({ right: 10 })
              Text(tag.label)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
              Image($r('sys.media.ohos_ic_public_close'))
                .width(18)
                .height(18)
                .opacity(0.6)
                .onClick(() => {
                  this.deleteTag(tag);
                })
            }
            .width('100%')
            .height(60)
            .padding({ left: 16, right: 12 })
            .margin({ left: 12, right: 12 })
            .borderRadius($r('app.float.native_card_radius'))
            .backgroundColor($r('app.color.surfacePrimary'))
          }
        }, (tag: Tag) => `tag_${tag.id}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  private tagColor(color: number): ResourceColor {
    if (!color) {
      return $r('app.color.defaultTagColor');
    }
    const rgb = color & 0xFFFFFF;
    return '#' + rgb.toString(16).padStart(6, '0').toUpperCase();
  }
}
