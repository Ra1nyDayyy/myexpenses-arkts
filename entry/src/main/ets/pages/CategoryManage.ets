import { Category, buildCategoryTree } from '../model/Category';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { router, promptAction } from '@kit.ArkUI';

/**
 * 分类输入对话框（鸿蒙原生 CustomDialog）
 */
@CustomDialog
export struct CategoryInputDialog {
  controller?: CustomDialogController;
  title: string = '新建分类';
  placeholder: string = '分类名称';
  @State label: string = '';
  onConfirm: (label: string) => void = () => {
  };

  build() {
    Column() {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 16 })

      TextInput({ placeholder: this.placeholder, text: this.label })
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
 * 分类管理页：对应 Android ManageCategories
 * 支持：新增主分类/子分类、编辑、删除
 */
@Entry
@Component
struct CategoryManage {
  @State categories: Category[] = [];
  @State expandedIds: number[] = [];
  @State dragEditMode: boolean = false;

  private repository: Repository = Repository.getInstance();
  private editTarget: Category | null = null;
  private dialog: CustomDialogController = new CustomDialogController({
    builder: CategoryInputDialog({
      title: '新建分类',
      onConfirm: (label: string) => {
        this.addCategory(label, 0);
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
    const all = await this.repository.getCategories();
    this.categories = buildCategoryTree(all);
  }

  private isExpanded(id: number): boolean {
    return this.expandedIds.indexOf(id) >= 0;
  }

  private toggleExpand(id: number): void {
    animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
      const idx = this.expandedIds.indexOf(id);
      if (idx >= 0) {
        this.expandedIds.splice(idx, 1);
        this.expandedIds = [...this.expandedIds];
      } else {
        this.expandedIds = [...this.expandedIds, id];
      }
    });
  }

  private async addCategory(label: string, parentId: number): Promise<void> {
    if (!label.trim()) {
      return;
    }
    const cat = new Category();
    cat.label = label.trim();
    cat.labelNormalized = cat.label;
    cat.parentId = parentId;
    cat.type = parentId === 0 ? -1 : this.editTarget?.type || -1;
    await this.repository.insertCategory(cat);
    this.editTarget = null;
    await this.load();
  }

  private openAddDialog(parentId: number, target: Category | null): void {
    this.editTarget = target;
    this.dialog = new CustomDialogController({
      builder: CategoryInputDialog({
        title: target ? '编辑分类' : '新建分类',
        onConfirm: (label: string) => {
          this.addCategory(label, parentId);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: false,
      cornerRadius: 12
    });
    this.dialog.open();
  }

  private async deleteCategory(cat: Category): Promise<void> {
    await this.repository.deleteCategory(cat.id);
    promptAction.showToast({ message: $r('app.string.toast_deleted') });
    await this.load();
  }

  build() {
    Column() {
      PageHeader({
        title: '类别',
        rightText: '+',
        onBack: () => {
          router.back();
        },
        onRight: () => {
          this.openAddDialog(0, null);
        }
      })

      List({ space: 8 }) {
        ForEach(this.categories, (cat: Category) => {
          ListItem() {
            this.categoryRow(cat, 0)
          }
        }, (cat: Category) => `root_${cat.id}`)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 12, right: 12 })
      .editMode(this.dragEditMode)
      .onItemMove((from: number, to: number) => {
        this.reorderCategories(from, to);
        return true;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  /**
   * 长按进入分类拖拽排序（对齐安卓拖拽排序）
   */
  private enableDrag(): void {
    this.dragEditMode = true;
  }

  /**
   * 分类拖拽重排（内存重排根分类 + 持久化排序号）
   */
  private reorderCategories(from: number, to: number): void {
    if (from < 0 || to < 0 || from >= this.categories.length || to >= this.categories.length || from === to) {
      return;
    }
    const item = this.categories.splice(from, 1)[0];
    this.categories.splice(to, 0, item);
    this.categories = [...this.categories];
    // 持久化根分类顺序
    const rootIds = this.categories.map((c: Category) => c.id);
    this.repository.updateCategoryOrders(rootIds);
  }

  @Builder
  categoryRow(cat: Category, depth: number) {
    Column() {
      Row() {
        if (cat.hasChildren) {
          Image(this.isExpanded(cat.id) ? $r('sys.media.ohos_ic_public_arrow_down') : $r('sys.media.ohos_ic_public_arrow_right'))
            .width(16)
            .height(16)
            .onClick(() => {
              this.toggleExpand(cat.id);
            })
        } else {
          Blank()
            .width(16)
        }
        Text(cat.label)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .margin({ left: 4 })

        Image($r('sys.media.ohos_ic_public_add'))
          .width(18)
          .height(18)
          .opacity(0.6)
          .margin({ right: 12 })
          .onClick(() => {
            this.openAddDialog(cat.id, cat);
          })

        Image($r('sys.media.ohos_ic_public_close'))
          .width(18)
          .height(18)
          .opacity(0.6)
          .onClick(() => {
            this.deleteCategory(cat);
          })
      }
      .width('100%')
      .height(60)
      .padding({ left: 16 + depth * 20, right: 12 })
      .backgroundColor($r('app.color.surfacePrimary'))
      .borderRadius($r('app.float.native_card_radius'))

      if (cat.hasChildren && this.isExpanded(cat.id)) {
        ForEach(cat.children, (child: Category) => {
          this.categoryRow(child, depth + 1)
        }, (child: Category) => `child_${cat.id}_${child.id}`)
      }
    }
    .width('100%')
  }
}
