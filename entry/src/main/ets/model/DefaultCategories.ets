/**
 * 默认类别树：原封不动搬 Android values-zh-rCN/categories.xml + cat_tree.xml
 * 收入 5 组（Cat_I_1 ~ Cat_I_5）+ 支出 17 组（Cat_E_1 ~ Cat_E_17）
 * 用于"设置应用程序默认的类别"对话框展示与导入
 */

/**
 * 单个默认主类别定义：label + children（子类别名）
 */
export interface DefaultCategoryDef {
  label: string;
  type: number; // -1 支出 / 1 收入
  children: string[];
}

export const DEFAULT_CATEGORIES: DefaultCategoryDef[] = [
  // ===== 收入（Cat_I_1 ~ Cat_I_5）=====
  { label: '其他的收入', type: 1, children: ['失业补助', '家庭津贴', '税收抵免', '赌博', '相互保险', '社会保障'] },
  { label: '退休', type: 1, children: ['退休基金', '养老金', '补充养老金'] },
  { label: '投资收益', type: 1, children: ['股利', '利益', '资本收益'] },
  { label: '薪水', type: 1, children: ['加班费', '请假津贴', '杂项奖金', '成功费', '净工资'] },
  { label: '杂项收入', type: 1, children: ['礼品', '退款', '二手销售'] },
  // ===== 支出（Cat_E_1 ~ Cat_E_17）=====
  { label: '餐饮', type: -1, children: ['酒吧', '面包', '食堂', '糖果', '杂货', '餐厅', '自助餐', '超级市场'] },
  { label: '宠物', type: -1, children: ['餐饮', '各种用品', '美容', '兽医'] },
  { label: '保险', type: -1, children: ['汽车保险', '健康保险', '房屋保险', '民事责任', '生活'] },
  { label: '汽车', type: -1, children: ['汽油', '维修', '保养', '停车处', '罚款'] },
  { label: '礼品', type: -1, children: [] },
  { label: '孩子', type: -1, children: ['护士', '学习'] },
  { label: '学习', type: -1, children: ['课程', '学费', '图书'] },
  { label: '财务经费', type: -1, children: ['银行收费', '贷款/抵押', '收费', '退款'] },
  { label: '专业费用', type: -1, children: ['不退还', '可退款'] },
  { label: '税', type: -1, children: ['所得税', '土地税', '销售税'] },
  { label: '住房', type: -1, children: ['旅馆', '出租', '电视', '家具', '收费', '加热', '装饰', '水', '电力', '白色家电', '设备', '加油站', '花园', '管家', '电话', '移动电话'] },
  { label: '休闲', type: -1, children: ['英式撞球(Snooker)', '保龄球', '电影', '夜店', '资讯科技', '游戏', '图书', '公园', '音乐会', '体育', '视频', '旅游', '设备', '博物馆/展览'] },
  { label: '贷款/抵押', type: -1, children: ['资本'] },
  { label: '健康', type: -1, children: ['保险', '牙医', '医院', '运动治疗师(Kinesitherapist)', '医生', '眼科医生', '整骨医生', '药费', '社会保障'] },
  { label: '保养', type: -1, children: ['美发师', '服装'] },
  { label: '运输', type: -1, children: ['公交车', '地铁', '过路费', '火车', '电车', '飞机'] },
  { label: '假期', type: -1, children: ['住房', '参观', '旅游'] }
];