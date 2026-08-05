import { Category, buildCategoryTree } from '../model/Category';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { router } from '@kit.ArkUI';

/**
 * 分类选择页：对应 Android 分类树选择
 */
@Entry
@Component
struct CategorySelect {
  @State categories: Category[] = [];
  @State filterType: number = 0; // -1 支出 / 1 收入 / 0 全部
  @State expandedIds: number[] = [];

  private repository: Repository = Repository.getInstance();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['type'] !== undefined) {
      this.filterType = params['type'] as number;
    }
    this.load();
  }

  async load(): Promise<void> {
    let all = await this.repository.getCategories();
    if (this.filterType !== 0) {
      all = all.filter((c: Category) => c.type === 0 || c.type === this.filterType);
    }
    this.categories = buildCategoryTree(all);
  }

  private isExpanded(id: number): boolean {
    return this.expandedIds.indexOf(id) >= 0;
  }

  private select(cat: Category): void {
    const params: Record<string, Object> = {
      'categoryId': cat.id,
      'categoryLabel': cat.label
    };
    // 通过事件总线返回（简化：router.back 带参不直接支持，使用 AppStorage）
    AppStorage.setOrCreate('selectedCategory', params);
    router.back();
  }

  build() {
    Column() {
      PageHeader({
        title: '选择类别',
        onBack: () => {
          router.back();
        }
      })

      Scroll() {
        Column() {
          ForEach(this.categories, (cat: Category) => {
            this.categoryItem(cat, 0)
          }, (cat: Category) => `root_${cat.id}`)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  @Builder
  categoryItem(cat: Category, depth: number) {
    Column() {
      Row() {
        if (cat.hasChildren) {
          Image(this.isExpanded(cat.id) ? $r('sys.media.ohos_ic_public_arrow_down') : $r('sys.media.ohos_ic_public_arrow_right'))
            .width(16)
            .height(16)
        } else {
          Blank()
            .width(16)
        }
        Text(cat.label)
          .fontSize(15)
          .fontColor(this.categoryColor(cat.type))
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16 + depth * 20, right: 12 })
      .onClick(() => {
        if (cat.hasChildren) {
          animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
            const idx = this.expandedIds.indexOf(cat.id);
            if (idx >= 0) {
              this.expandedIds.splice(idx, 1);
              this.expandedIds = [...this.expandedIds];
            } else {
              this.expandedIds = [...this.expandedIds, cat.id];
            }
          });
        } else {
          this.select(cat);
        }
      })

      if (cat.hasChildren && this.isExpanded(cat.id)) {
        ForEach(cat.children, (child: Category) => {
          this.categoryItem(child, depth + 1)
        }, (child: Category) => `child_${cat.id}_${child.id}`)
      }
    }
    .width('100%')
    .clip(true)
  }

  private categoryColor(type: number): ResourceColor {
    if (type === 1) {
      return $r('app.color.colorIncome');
    }
    if (type === -1) {
      return $r('app.color.colorExpense');
    }
    return $r('app.color.textPrimary');
  }
}