/**
 * 分类实体：对应 Android db2 的 Category
 */
export class Category {
  id: number = 0;
  label: string = '';
  labelNormalized: string = '';
  parentId: number = 0; // 0 = 主分类
  usages: number = 0;
  lastUsed: number = 0;
  color: number = 0;
  icon: string = '';
  uuid: string = '';
  type: number = 0; // -1 支出 / 1 收入 / 0 中性
  // 树形展示
  children: Category[] = [];
  hasChildren: boolean = false;
}

export enum CategoryType {
  EXPENSE = -1,
  NEUTRAL = 0,
  INCOME = 1
}

/**
 * 构建分类树
 */
export function buildCategoryTree(all: Category[]): Category[] {
  const map: Map<number, Category> = new Map();
  for (let c of all) {
    c.children = [];
    map.set(c.id, c);
  }
  const roots: Category[] = [];
  for (let c of all) {
    if (c.parentId === 0) {
      roots.push(c);
    } else {
      const parent = map.get(c.parentId);
      if (parent) {
        parent.children.push(c);
        parent.hasChildren = true;
      } else {
        roots.push(c);
      }
    }
  }
  return roots;
}