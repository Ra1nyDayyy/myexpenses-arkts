import { Tag } from '../model/SupportEntities';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { router } from '@kit.ArkUI';

/**
 * 标签选择页面（对齐安卓 ManageTags + TagList）
 * - 顶部搜索输入框:创建新标签
 * - 标签列表:可多选
 * - 右下角FAB:确认选择
 */
@Entry
@Component
struct TagSelect {
  @State tags: Tag[] = [];
  @State selectedTagIds: number[] = [];
  @State newTagLabel: string = '';
  private repository: Repository = Repository.getInstance();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['selectedTagIds']) {
      this.selectedTagIds = params['selectedTagIds'] as number[];
    }
    this.load();
  }

  async load(): Promise<void> {
    this.tags = await this.repository.getTags();
  }

  /**
   * 创建新标签
   */
  private async createTag(): Promise<void> {
    if (!this.newTagLabel.trim()) {
      return;
    }
    await this.repository.insertTag(this.newTagLabel.trim(), 0x0050A7);
    this.newTagLabel = '';
    await this.load();
    // 自动选中新创建的标签
    if (this.tags.length > 0) {
      const lastTag = this.tags[this.tags.length - 1];
      if (!this.selectedTagIds.includes(lastTag.id)) {
        this.selectedTagIds.push(lastTag.id);
      }
    }
  }

  /**
   * 切换标签选中状态
   */
  private toggleTag(tagId: number): void {
    const index = this.selectedTagIds.indexOf(tagId);
    if (index >= 0) {
      this.selectedTagIds.splice(index, 1);
    } else {
      this.selectedTagIds.push(tagId);
    }
    this.selectedTagIds = [...this.selectedTagIds];
  }

  /**
   * 确认选择
   */
  private confirm(): void {
    AppStorage.setOrCreate('selectedTags', this.selectedTagIds);
    router.back();
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        PageHeader({
          title: '创建或选择标签',
          onBack: () => {
            router.back();
          }
        })

        // 搜索/创建输入框（对齐安卓 SearchView）
        Row() {
          TextInput({ placeholder: '输入标签名称', text: this.newTagLabel })
            .layoutWeight(1)
            .backgroundColor(Color.White)
            .onChange((v: string) => {
              this.newTagLabel = v;
            })
            .onSubmit(() => {
              this.createTag();
            })

          Button('创建')
            .fontSize(14)
            .margin({ left: 8 })
            .backgroundColor($r('app.color.primaryColor'))
            .fontColor(Color.White)
            .onClick(() => {
              this.createTag();
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.pageBackground'))

        // 标签列表
        if (this.tags.length === 0) {
          Column() {
            Text('暂无标签')
              .fontSize(15)
              .fontColor($r('app.color.textSecondary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.tags, (tag: Tag) => {
              ListItem() {
                Row() {
                  // 标签色块
                  Row()
                    .width(4)
                    .height('100%')
                    .backgroundColor(this.colorToResourceColor(tag.color))

                  // 标签名称
                  Text(tag.label)
                    .fontSize(16)
                    .fontColor($r('app.color.textPrimary'))
                    .layoutWeight(1)
                    .margin({ left: 16 })

                  // 选中状态
                  if (this.selectedTagIds.includes(tag.id)) {
                    Image($r('sys.media.ohos_ic_public_ok'))
                      .width(24)
                      .height(24)
                      .fillColor($r('app.color.primaryColor'))
                  }
                }
                .width('100%')
                .height(56)
                .padding({ right: 16 })
                .backgroundColor(Color.White)
                .onClick(() => {
                  this.toggleTag(tag.id);
                })
              }
              .backgroundColor(Color.White)
            })
          }
          .layoutWeight(1)
          .backgroundColor($r('app.color.pageBackground'))
          .divider({ strokeWidth: 0.5, color: $r('app.color.dividerColor') })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.pageBackground'))

      // 右下角FAB:确认（对齐安卓 floatingActionButton）
      Stack({ alignContent: Alignment.Center }) {
        Image($r('sys.media.ohos_ic_public_ok'))
          .width(26)
          .height(26)
          .fillColor(Color.White)
      }
      .width(56)
      .height(56)
      .borderRadius(16)
      .backgroundColor($r('app.color.primaryColor'))
      .shadow({ radius: 10, color: '#33000000', offsetY: 3 })
      .markAnchor({ x: '100%', y: '100%' })
      .position({ x: '94%', y: '95%' })
      .onClick(() => {
        this.confirm();
      })
    }
    .width('100%')
    .height('100%')
  }

  /**
   * color 数值 → 颜色
   */
  private colorToResourceColor(color: number): ResourceColor {
    if (color === 0) {
      return $r('app.color.defaultTagColor');
    }
    const c = color & 0xFFFFFF;
    return `#${c.toString(16).padStart(6, '0')}` as ResourceColor;
  }
}