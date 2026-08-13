import { Category, buildCategoryTree } from '../model/Category';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { SortDialog } from '../components/SortDialog';
import { DefaultCategoryDef, DEFAULT_CATEGORIES } from '../model/DefaultCategories';
import { router, promptAction } from '@kit.ArkUI';

/**
 * 分类输入对话框（对齐安卓 CategoryEdit 新建/编辑类别）
 *  - 标题：动态（新建主要类别/编辑类别/新建子类别）
 *  - 类型分段切换：支出/收入（仅主类别显示）
 *  - 名称输入框
 *  - 确定按钮文字："添加"或"保存"
 */
@CustomDialog
export struct CategoryInputDialog {
  controller?: CustomDialogController;
  title: string = '新建主要类别';
  placeholder: string = '分类名称';
  @State label: string = '';
  @State selectedType: number = -1; // -1 支出 / 1 收入
  showTypeSelector: boolean = true; // 是否显示类型选择器（子类别不显示）
  isEdit: boolean = false; // 是否为编辑模式
  onConfirm: (label: string, type: number) => void = () => {
  };

  /**
   * 支出/收入分段切换（对齐安卓 TypeConfiguration）
   */
  @Builder
  typeSegments() {
    Row() {
      Column() {
        Text('支出')
          .fontSize(14)
          .fontColor(this.selectedType === -1 ? Color.White : $r('app.color.textSecondary'))
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .borderRadius(17)
      .backgroundColor(this.selectedType === -1 ? $r('app.color.primaryColor') : Color.Transparent)
      .onClick(() => {
        this.selectedType = -1;
      })

      Column() {
        Text('收入')
          .fontSize(14)
          .fontColor(this.selectedType === 1 ? Color.White : $r('app.color.textSecondary'))
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .borderRadius(17)
      .backgroundColor(this.selectedType === 1 ? $r('app.color.primaryColor') : Color.Transparent)
      .onClick(() => {
        this.selectedType = 1;
      })
    }
    .width(220)
    .height(36)
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.dividerColor') })
    .clip(true)
    .backgroundColor($r('app.color.cardBackgroundColor'))
    .margin({ bottom: 16 })
  }

  build() {
    Column() {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 16 })

      // 类型分段切换（对齐安卓 TypeConfiguration：新建主要类别时显示）
      if (this.showTypeSelector) {
        this.typeSegments()
      }

      TextInput({ placeholder: this.placeholder, text: this.label })
        .width('100%')
        .height(44)
        .onChange((v: string) => {
          this.label = v;
        })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .fontColor($r('app.color.textPrimary'))
          .onClick(() => {
            this.controller?.close();
          })
        // 对齐安卓：确定按钮文字为"添加"或"保存"
        Button(this.isEdit ? '保存' : '添加')
          .layoutWeight(1)
          .backgroundColor($r('app.color.primaryColor'))
          .onClick(() => {
            this.onConfirm(this.label, this.selectedType);
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
 * 设置应用程序默认的类别确认对话框（对齐安卓 SetupCategoriesConfirmDialogFragment）
 *  - 标题："设置应用程序默认的类别"（menu_categories_setup_default）
 *  - 内容：完整默认类别树（对齐安卓 Category 组件 DefaultExpanded，默认全部展开）
 *  - 按钮：取消（android.R.string.cancel）+ 导入（menu_import）
 */
@CustomDialog
export struct SetupCategoriesDialog {
  controller?: CustomDialogController;
  categories: DefaultCategoryDef[] = DEFAULT_CATEGORIES;
  @State expandedIds: number[] = [];
  onImport: () => void = () => {
  };

  aboutToAppear(): void {
    // 默认全部展开（对齐安卓 ExpansionMode.DefaultExpanded）
    const all: number[] = [];
    for (let i = 0; i < this.categories.length; i++) {
      all.push(i);
    }
    this.expandedIds = all;
  }

  private isExpanded(idx: number): boolean {
    return this.expandedIds.indexOf(idx) >= 0;
  }

  private toggleExpand(idx: number): void {
    const pos = this.expandedIds.indexOf(idx);
    if (pos >= 0) {
      this.expandedIds.splice(pos, 1);
      this.expandedIds = [...this.expandedIds];
    } else {
      this.expandedIds = [...this.expandedIds, idx];
    }
  }

  /**
   * 类型着色（对齐安卓 typeTextColor：收入绿/支出红）
   */
  private defTextColor(type: number): ResourceColor {
    if (type === 1) {
      return $r('app.color.colorIncome');
    }
    return $r('app.color.colorExpense');
  }

  build() {
    Column() {
      // 标题（对齐安卓 DialogFrame title = menu_categories_setup_default）
      Text('设置应用程序默认的类别')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.textPrimary'))
        .width('100%')
        .margin({ bottom: 12 })

      // 默认类别树（对齐安卓 Category DefaultExpanded：主类别 + 子类别，可展开/收起）
      Scroll() {
        Column() {
          ForEach(this.categories, (def: DefaultCategoryDef, idx: number) => {
            Column() {
              // 主类别行
              Row() {
                Image(this.isExpanded(idx) ? $r('sys.media.ohos_ic_public_arrow_down') : $r('sys.media.ohos_ic_public_arrow_right'))
                  .width(48)
                  .height(48)
                  .objectFit(ImageFit.CENTER)
                  .onClick(() => {
                    this.toggleExpand(idx);
                  })
                Text(def.label)
                  .fontSize(15)
                  .fontColor(this.defTextColor(def.type))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .height(48)
              .onClick(() => {
                this.toggleExpand(idx);
              })
              .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

              // 子类别
              if (def.children.length > 0 && this.isExpanded(idx)) {
                ForEach(def.children, (child: string) => {
                  Row() {
                    Blank()
                      .width(48)
                    Blank()
                      .width(24)
                    Text(child)
                      .fontSize(14)
                      .fontColor($r('app.color.textPrimary'))
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width('100%')
                  .height(44)
                  .padding({ left: 12 })
                  .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
                }, (child: string) => `sub_${idx}_${child}`)
              }
            }
            .width('100%')
          }, (def: DefaultCategoryDef, idx: number) => `main_${idx}`)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .borderRadius(8)
      .border({ width: 1, color: $r('app.color.dividerColor') })

      // 按钮行（对齐安卓 ButtonRow：取消 + 导入）
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .fontColor($r('app.color.textPrimary'))
          .onClick(() => {
            this.controller?.close();
          })
        Button('导入')
          .layoutWeight(1)
          .backgroundColor($r('app.color.primaryColor'))
          .onClick(() => {
            this.onImport();
            this.controller?.close();
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .padding(20)
    .width('100%')
    .height('80%')
  }
}

/**
 * 帮助对话框（对齐安卓 Help 页 help_ManageCategories_select_mapping_info）
 * 内容居中展示，包含安卓简体中文原版帮助文本，比之前更详细
 */
@CustomDialog
export struct CategoryHelpDialog {
  controller?: CustomDialogController;

  @Builder
  helpSection(title: string, body: string) {
    Column() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.textPrimary'))
        .width('100%')
      Text(body)
        .fontSize(14)
        .fontColor($r('app.color.textSecondary'))
        .width('100%')
        .lineHeight(22)
        .margin({ top: 6 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 18 })
  }

  build() {
    Column() {
      // 标题（对齐安卓 Help 标题：select_category）
      Text('选择类别')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.textPrimary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 4 })
      Text('帮助')
        .fontSize(13)
        .fontColor($r('app.color.textSecondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 20 })

      // 帮助内容（对齐安卓 help_ManageCategories_select_mapping_info + 补充操作说明）
      Scroll() {
        Column() {
          this.helpSection('选择类别',
            '除了从首选项界面管理类别时可以执行的操作(创建、编辑、删除)之外，在此界面上，您可以将某项交易映射到选定的类别。只需单击子类别。')
          this.helpSection('展开与收起',
            '点击主类别左侧的展开/收起图标，可以展开或收起其子类别。')
          this.helpSection('类别类型',
            '绿色文字表示收入类别，红色文字表示支出类别。您可以使用右上角的筛选按钮（支出/收入），或下方的分段切换，仅显示指定类型的类别。')
          this.helpSection('搜索',
            '点击右上角搜索按钮，输入关键词后只显示与您的查询匹配的主类别和子类别。')
          this.helpSection('排序',
            '点击更多菜单中的"排序方式"，类别列表可按文本标签（字母顺序）、使用次数或最后使用的进行排序。')
          this.helpSection('设置默认类别',
            '点击更多菜单中的"设置应用程序默认的类别"，将导入一组默认类别。')
          this.helpSection('短按选择父类别',
            '勾选更多菜单中的"短按选择父类别"后，单击主类别即可直接选择，而不再展开其子类别。')
          this.helpSection('新建类别',
            '点击右下角的加号按钮，可以新建一个主要类别（支出或收入）。')
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')

      // 确定按钮
      Button('确定')
        .width('100%')
        .height(44)
        .backgroundColor($r('app.color.primaryColor'))
        .borderRadius(8)
        .margin({ top: 16 })
        .onClick(() => {
          this.controller?.close();
        })
    }
    .width('100%')
    .padding(24)
  }
}

/**
 * 分类选择页：1:1 对齐 Android ManageCategories(SELECT_MAPPING)
 *  - 导航栏：返回 + 标题"选择类别" + 筛选（支出/收入）+ 搜索 + 更多
 *  - 分段切换：支出/收入（对齐 TypeConfiguration）
 *  - 类别树：48dp 行高、展开手柄、颜色圆点/图标、类型着色、分隔线、层级缩进
 *  - 空状态：无类别提示 + 设置应用程序默认的类别按钮
 *  - 右下角 FAB：新增类别
 *  - 选择行为：有子级点击展开，无子级点击选择返回
 */
@Entry
@Component
struct CategorySelect {
  @State categories: Category[] = [];
  @State filterType: number = 0; // 0 全部 / -1 支出 / 1 收入
  @State expandedIds: number[] = [];
  @State searchText: string = '';
  @State showSearchBar: boolean = false;
  @State showFilterPanel: boolean = false;
  @State filterExpense: boolean = true;
  @State filterIncome: boolean = true;
  @State parentSelectionOnTap: boolean = false; // 短按选择父类别（对齐安卓 PARENT_CATEGORY_SELECTION_ON_TAP）
  @State sortOrder: number = 1; // 1 文本标签 / 2 使用次数 / 3 最后使用的（对齐安卓 Sort）

  private repository: Repository = Repository.getInstance();
  private dialog: CustomDialogController | null = null;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['type'] !== undefined) {
      this.filterType = params['type'] as number;
    }
    // 同步筛选状态：进入时按来源类型初始化（支出→仅支出；收入→仅收入；默认→全部）
    if (this.filterType === -1) {
      this.filterExpense = true;
      this.filterIncome = false;
    } else if (this.filterType === 1) {
      this.filterExpense = false;
      this.filterIncome = true;
    } else {
      this.filterExpense = true;
      this.filterIncome = true;
    }
    this.load();
  }

  onPageShow(): void {
    this.load();
  }

  async load(): Promise<void> {
    const all = await this.repository.getCategories();
    this.categories = buildCategoryTree(all);
  }

  /**
   * 当前展示的类别树：按筛选类型（支出/收入多选）过滤
   * 对齐安卓 typeFilter（TypeConfiguration 多选）：两个都选显示全部，仅支出显示支出，仅收入显示收入
   */
  private visibleCategories(): Category[] {
    let list = this.categories;
    const showExpense = this.filterExpense;
    const showIncome = this.filterIncome;
    if (!showExpense || !showIncome) {
      // 多选过滤：保留中性 + 选中的类型
      list = list.filter((c: Category) => {
        if (c.type === 0) {
          return true;
        }
        if (c.type === -1) {
          return showExpense;
        }
        if (c.type === 1) {
          return showIncome;
        }
        return true;
      });
    }
    if (this.searchText.trim()) {
      const q = this.searchText.trim();
      const filterTree = (nodes: Category[]): Category[] => {
        const out: Category[] = [];
        for (const n of nodes) {
          if (n.label.indexOf(q) >= 0) {
            out.push(n);
          } else if (n.children.length > 0) {
            const sub = filterTree(n.children);
            if (sub.length > 0) {
              const copy = new Category();
              copy.id = n.id;
              copy.label = n.label;
              copy.labelNormalized = n.labelNormalized;
              copy.parentId = n.parentId;
              copy.usages = n.usages;
              copy.lastUsed = n.lastUsed;
              copy.color = n.color;
              copy.icon = n.icon;
              copy.uuid = n.uuid;
              copy.type = n.type;
              copy.children = sub;
              copy.hasChildren = true;
              out.push(copy);
            }
          }
        }
        return out;
      };
      list = filterTree(list);
    }
    return list;
  }

  /**
   * 当前是否有类别数据（用于空状态判断）
   */
  private hasAnyCategories(): boolean {
    return this.categories.length > 0;
  }

  private isExpanded(id: number): boolean {
    return this.expandedIds.indexOf(id) >= 0;
  }

  private toggleExpand(id: number): void {
    const idx = this.expandedIds.indexOf(id);
    if (idx >= 0) {
      this.expandedIds.splice(idx, 1);
      this.expandedIds = [...this.expandedIds];
    } else {
      this.expandedIds = [...this.expandedIds, id];
    }
  }

  private select(cat: Category): void {
    const params: Record<string, Object> = {
      'categoryId': cat.id,
      'categoryLabel': cat.label
    };
    AppStorage.setOrCreate('selectedCategory', params);
    router.back();
  }

  private onCategoryTap(cat: Category): void {
    // 对齐安卓 SingleChoiceMode：
    // - 无子级：点击选择返回
    // - 有子级：默认点击展开；勾选"短按选择父类别"后点击直接选择（selectParentOnTap）
    if (!cat.hasChildren) {
      this.select(cat);
    } else if (this.parentSelectionOnTap) {
      this.select(cat);
    } else {
      this.toggleExpand(cat.id);
    }
  }

  /**
   * 新增主要类别（对齐安卓 createCat(null)：parent=null，类型由对话框分段切换选择）
   */
  private async addCategory(label: string, type: number): Promise<void> {
    if (!label.trim()) {
      return;
    }
    const cat = new Category();
    cat.label = label.trim();
    cat.labelNormalized = cat.label;
    cat.parentId = 0;
    cat.type = type === 1 ? 1 : -1;
    await this.repository.insertCategory(cat);
    await this.load();
  }

  private openAddDialog(): void {
    let dialog: CustomDialogController | undefined = undefined;
    dialog = new CustomDialogController({
      builder: CategoryInputDialog({
        controller: dialog,
        title: '新建主要类别',
        onConfirm: (label: string, type: number) => {
          this.addCategory(label, type);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: false,
      cornerRadius: 12
    });
    dialog.open();
  }

  /**
   * 设置应用程序默认的类别（对齐安卓 SetupCategoriesConfirmDialogFragment）
   * 点击后弹出确认对话框，展示完整默认类别树；点"导入"写入数据库（幂等）
   */
  private setupDefaultCategories(): void {
    let dialog: CustomDialogController | undefined = undefined;
    dialog = new CustomDialogController({
      builder: SetupCategoriesDialog({
        controller: dialog,
        onImport: () => {
          this.importDefaultCategories();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: false,
      cornerRadius: 16
    });
    dialog.open();
  }

  /**
   * 导入默认类别（对齐安卓 importCats / METHOD_SETUP_CATEGORIES）
   * 幂等：主类别按 label 查重，子类别按 主类别下的 label 查重
   */
  private async importDefaultCategories(): Promise<void> {
    const existing = await this.repository.getCategories();
    let inserted = 0;
    for (const def of DEFAULT_CATEGORIES) {
      const mainExists = existing.find((c: Category) => c.parentId === 0 && c.label === def.label);
      let mainId: number;
      if (mainExists) {
        mainId = mainExists.id;
      } else {
        const main = new Category();
        main.label = def.label;
        main.labelNormalized = def.label;
        main.parentId = 0;
        main.type = def.type;
        mainId = await this.repository.insertCategory(main);
        inserted++;
      }
      for (const subLabel of def.children) {
        const subExists = existing.find((c: Category) => c.parentId === mainId && c.label === subLabel);
        if (subExists) {
          continue;
        }
        const sub = new Category();
        sub.label = subLabel;
        sub.labelNormalized = subLabel;
        sub.parentId = mainId;
        sub.type = 0;
        await this.repository.insertCategory(sub);
        inserted++;
      }
    }
    promptAction.showToast({ message: inserted > 0 ? `已导入 ${inserted} 个类别` : '默认类别已存在' });
    await this.load();
  }

  /**
   * 切换支出筛选（对齐安卓 typeFilter 多选：两个都选=全部）
   */
  private toggleFilterExpense(): void {
    this.filterExpense = !this.filterExpense;
    if (!this.filterExpense && !this.filterIncome) {
      this.filterIncome = true;
    }
    this.syncTypeFilter();
  }

  private toggleFilterIncome(): void {
    this.filterIncome = !this.filterIncome;
    if (!this.filterExpense && !this.filterIncome) {
      this.filterExpense = true;
    }
    this.syncTypeFilter();
  }

  /**
   * 同步分段切换高亮：仅勾选支出→支出段；仅勾选收入→收入段；两者→不强调（全部）
   */
  private syncTypeFilter(): void {
    if (this.filterExpense && !this.filterIncome) {
      this.filterType = -1;
    } else if (!this.filterExpense && this.filterIncome) {
      this.filterType = 1;
    } else {
      this.filterType = 0;
    }
  }

  /**
   * 右上角更多菜单（对齐安卓 categories.xml 完整功能）
   *  - 设置应用程序默认的类别（SETUP_CATEGORIES_DEFAULT_COMMAND）
   *  - 排序方式（SORT_COMMAND）：打开排序对话框 - 文本标签/使用次数/最后使用的
   *  - 短按选择父类别（TOGGLE_PARENT_CATEGORY_SELECTION_ON_TAP，勾选项）
   *  - 帮助（HELP_COMMAND：原封不动搬安卓 help_ManageCategories_select_mapping_info）
   */
  private moreMenu(): Array<MenuElement> {
    return [
      {
        value: '设置应用程序默认的类别',
        action: () => {
          this.setupDefaultCategories();
        }
      } as MenuElement,
      {
        value: '排序方式',
        action: () => {
          this.openSortDialog();
        }
      } as MenuElement,
      {
        value: (this.parentSelectionOnTap ? '✓ ' : '') + '短按选择父类别',
        action: () => {
          this.parentSelectionOnTap = !this.parentSelectionOnTap;
        }
      } as MenuElement,
      {
        value: '帮助',
        action: () => {
          this.showCategoryHelp();
        }
      } as MenuElement
    ];
  }

  /**
   * 分类排序（对齐安卓 Sort：1 标签 / 2 使用次数 / 3 最后使用）
   */
  private sortCategories(order: number): void {
    const sortTree = (nodes: Category[]): Category[] => {
      const sorted = [...nodes].sort((a: Category, b: Category) => {
        if (order === 2) {
          return (b.usages || 0) - (a.usages || 0);
        }
        if (order === 3) {
          return (b.lastUsed || 0) - (a.lastUsed || 0);
        }
        return a.label.localeCompare(b.label, 'zh-Hans-CN');
      });
      for (const n of sorted) {
        if (n.children.length > 0) {
          n.children = sortTree(n.children);
          n.hasChildren = n.children.length > 0;
        }
      }
      return sorted;
    };
    this.categories = sortTree(this.categories);
  }

  /**
   * 按名称自然排序（对齐安卓 Sort.LABEL）
   */
  private sortByLabel(): void {
    this.sortCategories(1);
  }

  /**
   * 帮助（对齐安卓 Help 页 help_ManageCategories_select_mapping_info）
   * 居中对话框展示，内容详细（映射、展开收起、类型、搜索、排序、默认类别、父类别、新建）
   */
  private showCategoryHelp(): void {
    let dialog: CustomDialogController | undefined = undefined;
    dialog = new CustomDialogController({
      builder: CategoryHelpDialog({
        controller: dialog
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: false,
      cornerRadius: 16
    });
    dialog.open();
  }

  /**
   * 显示类别上下文菜单（对齐安卓 menuGenerator 长按菜单）
   * 菜单项：选择/编辑/删除/子类别
   */
  private showCategoryContextMenu(cat: Category): void {
    // 对齐安卓：在SELECT_MAPPING模式下，且不是"短按选择父类别"时，长按显示"选择"选项
    const showSelectOption = !this.parentSelectionOnTap;
    
    if (showSelectOption) {
      // 显示：选择/编辑/删除/子类别
      promptAction.showActionMenu({
        title: cat.label,
        buttons: [
          { text: '选择', color: '#FF000000' },
          { text: '编辑', color: '#FF000000' },
          { text: '删除', color: '#FFE84E40' },
          { text: '子类别', color: '#FF000000' }
        ]
      }).then((result: promptAction.ActionMenuSuccessResponse) => {
        if (result.index === 0) {
          this.select(cat);
        } else if (result.index === 1) {
          this.editCategory(cat);
        } else if (result.index === 2) {
          this.confirmDeleteCategory(cat);
        } else if (result.index === 3) {
          this.createSubCategory(cat);
        }
      }).catch((err: Error) => {
        console.error('ActionMenu error: ' + err.message);
      });
    } else {
      // 显示：编辑/删除/子类别
      promptAction.showActionMenu({
        title: cat.label,
        buttons: [
          { text: '编辑', color: '#FF000000' },
          { text: '删除', color: '#FFE84E40' },
          { text: '子类别', color: '#FF000000' }
        ]
      }).then((result: promptAction.ActionMenuSuccessResponse) => {
        if (result.index === 0) {
          this.editCategory(cat);
        } else if (result.index === 1) {
          this.confirmDeleteCategory(cat);
        } else if (result.index === 2) {
          this.createSubCategory(cat);
        }
      }).catch((err: Error) => {
        console.error('ActionMenu error: ' + err.message);
      });
    }
  }

  /**
   * 编辑类别（对齐安卓 editCat）
   */
  private editCategory(cat: Category): void {
    let dialog: CustomDialogController | undefined = undefined;
    dialog = new CustomDialogController({
      builder: CategoryInputDialog({
        controller: dialog,
        title: '编辑类别',
        placeholder: '分类名称',
        label: cat.label,
        selectedType: cat.type,
        showTypeSelector: cat.parentId === 0, // 仅主类别可以修改类型
        isEdit: true,
        onConfirm: (label: string, type: number) => {
          this.updateCategory(cat, label, type);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: false,
      cornerRadius: 12
    });
    dialog.open();
  }

  /**
   * 更新类别信息
   */
  private async updateCategory(cat: Category, label: string, type: number): Promise<void> {
    if (!label.trim()) {
      return;
    }
    cat.label = label.trim();
    cat.labelNormalized = cat.label;
    if (cat.parentId === 0) {
      // 主类别可以修改类型
      cat.type = type === 1 ? 1 : -1;
    }
    await this.repository.updateCategory(cat);
    await this.load();
    promptAction.showToast({ message: '类别已更新' });
  }

  /**
   * 确认删除类别（对齐安卓 delete + checkDefaultTransferCategory）
   */
  private confirmDeleteCategory(cat: Category): void {
    const message = cat.hasChildren 
      ? `删除主类别"${cat.label}"将同时删除其所有子类别，确定要删除吗？`
      : `确定要删除类别"${cat.label}"吗？`;
    
    promptAction.showDialog({
      title: '删除类别',
      message: message,
      buttons: [
        { text: '取消', color: '#FF000000' },
        { text: '删除', color: '#FFE84E40' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.deleteCategory(cat);
      }
    }).catch((err: Error) => {
      console.error('Dialog error: ' + err.message);
    });
  }

  /**
   * 删除类别
   */
  private async deleteCategory(cat: Category): Promise<void> {
    try {
      await this.repository.deleteCategory(cat.id);
      await this.load();
      promptAction.showToast({ message: '类别已删除' });
    } catch (err) {
      promptAction.showToast({ message: '删除失败: ' + err.message });
    }
  }

  /**
   * 创建子类别（对齐安卓 createCat(parent)）
   */
  private createSubCategory(parent: Category): void {
    let dialog: CustomDialogController | undefined = undefined;
    dialog = new CustomDialogController({
      builder: CategoryInputDialog({
        controller: dialog,
        title: `新建子类别 (${parent.label})`,
        placeholder: '子类别名称',
        showTypeSelector: false, // 子类别不显示类型选择器
        isEdit: false,
        onConfirm: (label: string, type: number) => {
          this.addSubCategory(parent, label);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: false,
      cornerRadius: 12
    });
    dialog.open();
  }

  /**
   * 添加子类别
   */
  private async addSubCategory(parent: Category, label: string): Promise<void> {
    if (!label.trim()) {
      return;
    }
    const cat = new Category();
    cat.label = label.trim();
    cat.labelNormalized = cat.label;
    cat.parentId = parent.id;
    cat.type = 0; // 子类别类型为中性
    await this.repository.insertCategory(cat);
    await this.load();
    // 自动展开父类别
    if (this.expandedIds.indexOf(parent.id) < 0) {
      this.expandedIds = [...this.expandedIds, parent.id];
    }
    promptAction.showToast({ message: '子类别已创建' });
  }

  /**
   * 打开排序方式对话框（对齐安卓 SORT_COMMAND：文本标签/使用次数/最后使用的）
   */
  private openSortDialog(): void {
    let dialog: CustomDialogController | undefined = undefined;
    dialog = new CustomDialogController({
      builder: SortDialog({
        controller: dialog,
        currentSort: this.sortOrder === 1 ? 'label' : (this.sortOrder === 2 ? 'usages' : 'last_used'),
        onResult: (flagFirst: boolean, sortBy: string) => {
          if (sortBy === 'label') {
            this.sortOrder = 1;
          } else if (sortBy === 'usages') {
            this.sortOrder = 2;
          } else if (sortBy === 'last_used') {
            this.sortOrder = 3;
          } else {
            this.sortOrder = 1;
          }
          this.sortCategories(this.sortOrder);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: false,
      cornerRadius: 16
    });
    dialog.open();
  }

  /**
   * 类型着色（对齐安卓 typeTextColor：收入绿/支出红）
   */
  private categoryTextColor(type: number): ResourceColor {
    if (type === 1) {
      return $r('app.color.colorIncome');
    }
    if (type === -1) {
      return $r('app.color.colorExpense');
    }
    return $r('app.color.textPrimary');
  }

  /**
   * 类别图标：icon 存在时显示 emoji（对齐安卓 Icon），否则有 color 显示颜色圆点（24dp）
   * 都没有时占 24dp 空白（对齐安卓 Spacer(24.dp)）
   */
  @Builder
  categoryIcon(cat: Category) {
    if (cat.icon && cat.icon.length > 0) {
      Text(cat.icon)
        .fontSize(20)
        .width(48)
        .height(48)
        .textAlign(TextAlign.Center)
    } else if (cat.color !== 0) {
      Circle()
        .width(24)
        .height(24)
        .fill(this.colorToResourceColor(cat.color))
        .margin({ left: 12, right: 12 })
    } else {
      Blank()
        .width(24)
    }
  }

  /**
   * color 数值 → 颜色（安卓 color Int，取低 24 位 ARGB）
   */
  private colorToResourceColor(color: number): ResourceColor {
    if (color === 0) {
      return $r('app.color.textSecondary');
    }
    const c = color & 0xFFFFFF;
    return `#${c.toString(16).padStart(6, '0')}` as ResourceColor;
  }

  /**
   * 支出/收入分段切换（对齐安卓 TypeConfiguration / MultiChoiceSegmentedButtonRow）
   */
  @Builder
  typeSegments() {
    Row() {
      // 支出
      Column() {
        Text('支出')
          .fontSize(14)
          .fontColor(this.filterType === -1 ? Color.White : $r('app.color.textSecondary'))
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .borderRadius(17)
      .backgroundColor(this.filterType === -1 ? $r('app.color.primaryColor') : Color.Transparent)
      .onClick(() => {
        this.filterType = -1;
        // 同步筛选状态：仅显示支出（对齐安卓 SegmentedButton 与 typeFilter 联动）
        this.filterExpense = true;
        this.filterIncome = false;
        this.load();
      })

      // 收入
      Column() {
        Text('收入')
          .fontSize(14)
          .fontColor(this.filterType === 1 ? Color.White : $r('app.color.textSecondary'))
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .borderRadius(17)
      .backgroundColor(this.filterType === 1 ? $r('app.color.primaryColor') : Color.Transparent)
      .onClick(() => {
        this.filterType = 1;
        // 同步筛选状态：仅显示收入
        this.filterExpense = false;
        this.filterIncome = true;
        this.load();
      })
    }
    .width(240)
    .height(36)
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.dividerColor') })
    .clip(true)
    .backgroundColor($r('app.color.cardBackgroundColor'))
    .margin({ top: 12, bottom: 8 })
  }

  /**
   * 筛选面板（对齐安卓 TYPE_FILTER_COMMAND：支出/收入多选过滤）
   * 就近在导航栏下方展开，非弹窗
   */
  @Builder
  filterPanel() {
    Column() {
      Row() {
        Text('筛选类型')
          .fontSize(14)
          .fontColor($r('app.color.textPrimary'))
          .layoutWeight(1)
        Text('重置')
          .fontSize(14)
          .fontColor($r('app.color.primaryColor'))
          .onClick(() => {
            this.filterExpense = true;
            this.filterIncome = true;
          })
      }
      .width('100%')

      Row({ space: 12 }) {
        // 支出
        Row({ space: 6 }) {
          Checkbox()
            .select(this.filterExpense)
            .onChange((v: boolean) => {
              this.toggleFilterExpense();
            })
          Text('支出')
            .fontSize(14)
            .fontColor($r('app.color.textPrimary'))
        }
        .onClick(() => {
          this.toggleFilterExpense();
        })

        // 收入
        Row({ space: 6 }) {
          Checkbox()
            .select(this.filterIncome)
            .onChange((v: boolean) => {
              this.toggleFilterIncome();
            })
          Text('收入')
            .fontSize(14)
            .fontColor($r('app.color.textPrimary'))
        }
        .onClick(() => {
          this.toggleFilterIncome();
        })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.cardBackgroundColor'))
  }

  /**
   * 搜索栏（对齐安卓 SearchView 展开状态）
   * 展开时保留筛选和更多菜单按钮
   *  - 左侧返回箭头：退出搜索
   *  - 中间搜索输入框：输入时过滤类别
   *  - 右侧清除按钮：清空搜索词
   *  - 筛选按钮和更多菜单按钮保留
   */
  @Builder
  searchBar() {
    Row() {
      // 返回箭头：退出搜索（对齐安卓 SearchView collapseActionView）
      Image($r('sys.media.ohos_ic_public_arrow_left'))
        .width(24)
        .height(24)
        .onClick(() => {
          this.showSearchBar = false;
          this.searchText = '';
        })

      Image($r('sys.media.ohos_ic_public_search_filled'))
        .width(18)
        .height(18)
        .fillColor($r('app.color.textSecondary'))
        .margin({ left: 12 })

      TextInput({ placeholder: '搜索类别', text: this.searchText })
        .layoutWeight(1)
        .height(40)
        .backgroundColor(Color.Transparent)
        .placeholderColor($r('app.color.textSecondary'))
        .onChange((v: string) => {
          this.searchText = v;
        })

      if (this.searchText.length > 0) {
        Image($r('sys.media.ohos_ic_public_close'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.textSecondary'))
          .margin({ right: 10 })
          .onClick(() => {
            this.searchText = '';
          })
      }

      // 保留筛选按钮（对齐安卓：搜索展开时仍可见）
      Image($r('app.media.ic_filter'))
        .width(24)
        .height(24)
        .fillColor(this.showFilterPanel ? $r('app.color.primaryColor') : $r('app.color.textPrimary'))
        .margin({ left: 8, right: 8 })
        .onClick(() => {
          this.showFilterPanel = !this.showFilterPanel;
          if (this.showFilterPanel) {
            this.filterExpense = true;
            this.filterIncome = true;
            this.filterType = 0;
          } else {
            this.syncTypeFilter();
          }
        })

      // 保留更多菜单按钮
      Image($r('sys.media.ohos_ic_public_more'))
        .width(24)
        .height(24)
        .bindMenu(this.moreMenu())
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 16 })
    .backgroundColor($r('app.color.pageBackground'))
  }


  @Builder
  categoryItem(cat: Category, depth: number) {
    Column() {
      Row() {
        // 展开手柄（对齐安卓 ExpansionHandle：48dp；无子级占 48dp 空白）
        if (cat.hasChildren) {
          Image(this.isExpanded(cat.id) ? $r('sys.media.ohos_ic_public_arrow_down') : $r('sys.media.ohos_ic_public_arrow_right'))
            .width(48)
            .height(48)
            .objectFit(ImageFit.CENTER)
        } else {
          Blank()
            .width(48)
        }
        // 图标 / 颜色圆点
        this.categoryIcon(cat)
        // 类别文字
        Text(cat.label)
          .fontSize(15)
          .fontColor(this.categoryTextColor(cat.type))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(48)
      .padding({ left: 8 + depth * 12, right: 12 })
      .onClick(() => {
        this.onCategoryTap(cat);
      })
      .gesture(
        LongPressGesture({ repeat: false })
          .onAction(() => {
            this.showCategoryContextMenu(cat);
          })
      )
      .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

      if (cat.hasChildren && this.isExpanded(cat.id)) {
        ForEach(cat.children, (child: Category) => {
          this.categoryItem(child, depth + 1)
        }, (child: Category) => `child_${cat.id}_${child.id}`)
      }
    }
    .width('100%')
    .clip(true)
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // 搜索模式：搜索栏替换导航栏（对齐安卓 SearchView 展开在 Toolbar 位置）
        if (this.showSearchBar) {
          this.searchBar()
        } else {
          PageHeader({
            title: '选择类别',
            showFilter: true,
            filterActive: this.showFilterPanel,
            showSearch: true,
            searchActive: this.searchText.length > 0,
            showMore: true,
            moreMenu: this.moreMenu(),
            onBack: () => {
              router.back();
            },
            onFilter: () => {
              // 对齐安卓 TYPE_FILTER_COMMAND: toggleTypeFilterIsShown
              // 切换筛选状态:未激活→激活(显示全部,隐藏分段) / 激活→未激活(恢复分段)
              this.showFilterPanel = !this.showFilterPanel;
              if (this.showFilterPanel) {
                // 激活:展示所有类别,隐藏分段切换
                this.filterExpense = true;
                this.filterIncome = true;
                this.filterType = 0;
              } else {
                // 关闭:恢复分段切换显示
                this.syncTypeFilter();
              }
            },
            onSearch: () => {
              this.showSearchBar = true;
            }
          })
        }

        // 支出/收入分段切换（对齐安卓 TypeConfiguration；筛选按钮激活时隐藏）
        if (!this.showFilterPanel) {
          Row() {
            this.typeSegments()
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }

        // 主内容：类别树 / 空状态
        if (!this.hasAnyCategories() || this.visibleCategories().length === 0) {
          // 空状态（对齐安卓 LoadingState.Empty：无类别 + 设置默认类别按钮）
          Column() {
            Text(this.searchText.trim() ? '无匹配类别' : '无类别')
              .fontSize(15)
              .fontColor($r('app.color.textSecondary'))
              .margin({ bottom: 16 })
            if (!this.searchText.trim()) {
              Column({ space: 4 }) {
                Image($r('sys.media.ohos_ic_public_add'))
                  .width(28)
                  .height(28)
                  .fillColor($r('app.color.textPrimary'))
                  .margin({ bottom: 4 })
                Text('设置应用程序默认的类别')
                  .fontSize(14)
                  .fontColor($r('app.color.textPrimary'))
              }
              .width(280)
              .height(84)
              .justifyContent(FlexAlign.Center)
              .borderRadius(42)
              .backgroundColor($r('app.color.cardBackgroundColor'))
              .onClick(() => {
                this.setupDefaultCategories();
              })
            }
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Column() {
              ForEach(this.visibleCategories(), (cat: Category) => {
                this.categoryItem(cat, 0)
              }, (cat: Category) => `root_${cat.id}`)
            }
            .width('100%')
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.Top)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.pageBackground'))

      // 右下角 FAB：新增类别（对齐安卓 floatingActionButton）
      Stack({ alignContent: Alignment.Center }) {
        Image($r('sys.media.ohos_ic_public_add'))
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
        this.openAddDialog();
      })
    }
    .width('100%')
    .height('100%')
  }
}
