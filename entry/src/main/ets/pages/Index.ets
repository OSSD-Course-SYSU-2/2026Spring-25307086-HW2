import { curves, promptAction } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
// ✅ 自由流转功能新增：分布式键值数据库，用于把打卡记录同步到同账号下的其他设备
import { distributedKVStore } from '@kit.ArkData';
// 1. 历史记录的数据格式定义
// 历史记录的数据格式定义（必须放在 @Entry 的外面！）
export interface CheckInRecord {
  id: string;
  shopName: string;
  date: number;
  waitTime: number; // 等待时间 (分钟)
  cost: number;     // 消费金额 (元)
  shopType?: string; // ✅ 月度报告功能新增：打卡时的店铺类型，用于"按类型分布"统计（旧记录可能没有此字段）
}

// 2. 持久化数据引擎注册（这行保证关掉App后记录不丢失）
PersistentStorage.persistProp('checkInRecords', []);
interface Shop {
  name: string;
  type: string;
  level: string;
  score: number;
  busyLevel: number;
  avgCost: number;
  history: number[];
  lat?: number;
  lng?: number;
  distanceStr?: string;
  rawDistance?: number;
  bgImg: string;
}

class LotteryItem {
  shop: Shop;
  tickets: number;

  constructor(shop: Shop, tickets: number) {
    this.shop = shop;
    this.tickets = tickets;
  }
}

interface WeatherNow {
  text: string;
}

interface WeatherResponse {
  code: string;
  now: WeatherNow;
}

interface CampusBuilding {
  name: string;
  lat: number;
  lng: number;
}

// ✅ 月度报告功能新增：单月汇总数据结构
interface MonthSummary {
  count: number;
  totalCost: number;
  avgWait: number;
  topShop: string;
  topShopCount: number;
}

// ✅ 月度报告功能新增：按店铺类型统计花费分布的数据结构
interface TypeBreakdownItem {
  type: string;
  cost: number;
}

const campusMapNodes: CampusBuilding[] = [
  { name: '📡 实时 GPS 定位', lat: 0, lng: 0 },
  { name: '🏢 第一教学楼 ', lat: 23.093200, lng: 113.294100 },
  { name: '🏢 第二教学楼 ', lat: 23.092500, lng: 113.293500 },
  { name: '🧪 第四教学楼 (丰盛堂)', lat: 23.091500, lng: 113.301500 },
  { name: '📚 第五教学楼 (逸夫楼)', lat: 23.097500, lng: 113.296500 },
  { name: '🏢 第六教学楼 ', lat: 23.094000, lng: 113.294800 },
];

// 💡 修复1：使用 weserv 全球极速 CDN 代理 Unsplash 的图片，保证国内模拟器秒开！
const fallbackImages: string[] = [
  'https://images.weserv.nl/?url=images.unsplash.com/photo-1547592180-85f173990554&w=400&q=60',
  'https://images.weserv.nl/?url=images.unsplash.com/photo-1512058564366-18510be2db19&w=400&q=60',
  'https://images.weserv.nl/?url=images.unsplash.com/photo-1604908176997-125f25cc6f3d&w=400&q=60',
  'https://images.weserv.nl/?url=images.unsplash.com/photo-1564834724105-918b73d1b9e0&w=400&q=60',
  'https://images.weserv.nl/?url=images.unsplash.com/photo-1605220645990-21f83c1ce610&w=400&q=60'
];

function getRandomBg(): string {
  return fallbackImages[Math.floor(Math.random() * fallbackImages.length)];
}
// ✅ 打卡功能新增：生成 0~max 的字符串数字数组，供滑动选择器弹窗（TextPickerDialog）的 range 使用
function buildNumberRange(max: number): string[] {
  let result: string[] = [];
  for (let i = 0; i <= max; i++) {
    result.push(i.toString());
  }
  return result;
}
// 💡 全新配置：食欲唤醒渐变色引擎（按店铺类型区分色调，呼应"全新配置"的初衷，同时修掉 type 参数未使用的警告）
function getWarmGradient(type: string): [ResourceColor, number][] {
  if (type === '点外卖') {
    return [
      ['#F5222D', 0.0],
      ['#FF7A45', 0.5],
      ['#FFA940', 1.0]
    ];
  }
  if (type === '吃泡面') {
    return [
      ['#D4380D', 0.0],
      ['#FA8C16', 0.5],
      ['#FFC53D', 1.0]
    ];
  }
  if (type === '出去吃') {
    return [
      ['#C41D7F', 0.0],
      ['#FF7A45', 0.5],
      ['#FFD666', 1.0]
    ];
  }
  // 默认（吃食堂等其他类型）
  return [
    ['#FF4D4F', 0.0],   // 红色
    ['#FF7A45', 0.5],   // 橙色
    ['#FFD666', 1.0]    // 黄色
  ];
}
const defaultShops: Shop[] = [
  { name: '松涛园一楼自选', type: '吃食堂', level: '夯', score: 5, busyLevel: 2, avgCost: 15, history: [10, 15], bgImg: fallbackImages[0], lat: 23.096500, lng: 113.291200 },
  { name: '松涛园二楼烧腊', type: '吃食堂', level: '人上人', score: 4, busyLevel: 2, avgCost: 16, history: [10, 15], bgImg: fallbackImages[1], lat: 23.096500, lng: 113.291200 },
  { name: '松涛园三楼三杯鸡', type: '吃食堂', level: '顶级', score: 5, busyLevel: 3, avgCost: 18, history: [15, 20], bgImg: fallbackImages[2], lat: 23.096500, lng: 113.291200 },
  { name: '松涛园三楼麻辣烫', type: '吃食堂', level: '夯', score: 4, busyLevel: 3, avgCost: 17, history: [15, 25], bgImg: fallbackImages[3], lat: 23.096500, lng: 113.291200 },
  { name: '学一食堂大锅菜', type: '吃食堂', level: 'NPC', score: 3, busyLevel: 3, avgCost: 12, history: [15, 20], bgImg: fallbackImages[1], lat: 23.091200, lng: 113.295500 },
  { name: '学一食堂肠粉', type: '吃食堂', level: '夯', score: 4, busyLevel: 2, avgCost: 8, history: [5, 10], bgImg: fallbackImages[0], lat: 23.091200, lng: 113.295500 },
  { name: '学五铁板烧', type: '吃食堂', level: '夯', score: 5, busyLevel: 3, avgCost: 16, history: [15, 25], bgImg: fallbackImages[3], lat: 23.096200, lng: 113.303100 },
  { name: '学五滑蛋饭', type: '吃食堂', level: '顶级', score: 5, busyLevel: 2, avgCost: 15, history: [10, 20], bgImg: fallbackImages[4], lat: 23.096200, lng: 113.303100 },
  { name: '学五糖水铺', type: '吃食堂', level: '人上人', score: 4, busyLevel: 1, avgCost: 6, history: [5, 10], bgImg: fallbackImages[2], lat: 23.096200, lng: 113.303100 },
  { name: '绿茵园西餐厅', type: '吃食堂', level: '人上人', score: 4, busyLevel: 1, avgCost: 40, history: [12, 18], bgImg: fallbackImages[4], lat: 23.099500, lng: 113.293000 },
  { name: '紫荆园简餐', type: '吃食堂', level: 'NPC', score: 3, busyLevel: 1, avgCost: 25, history: [10, 15], bgImg: fallbackImages[0], lat: 23.093500, lng: 113.297000 },
  { name: '春晖园快餐', type: '吃食堂', level: '拉完了', score: 2, busyLevel: 2, avgCost: 13, history: [10, 15], bgImg: fallbackImages[1], lat: 23.098800, lng: 113.299500 },
  { name: '下渡路遇见小面', type: '出去吃', level: '人上人', score: 4, busyLevel: 2, avgCost: 25, history: [10, 20], bgImg: fallbackImages[4], lat: 23.088500, lng: 113.294200 },
  { name: '新港西路萨莉亚', type: '出去吃', level: '夯', score: 5, busyLevel: 2, avgCost: 35, history: [15, 25], bgImg: fallbackImages[3], lat: 23.089200, lng: 113.296500 },
  { name: '尊宝比萨(下渡路店)', type: '出去吃', level: '夯', score: 4, busyLevel: 1, avgCost: 30, history: [15, 20], bgImg: fallbackImages[2], lat: 23.087500, lng: 113.294500 },
  { name: '麦当劳(新港西路店)', type: '出去吃', level: 'NPC', score: 3, busyLevel: 3, avgCost: 25, history: [5, 10], bgImg: fallbackImages[0], lat: 23.089500, lng: 113.295000 },
  { name: '肯德基(下渡路店)', type: '出去吃', level: 'NPC', score: 3, busyLevel: 2, avgCost: 28, history: [5, 15], bgImg: fallbackImages[1], lat: 23.088000, lng: 113.294200 },
  { name: '华辉拉肠(下渡路)', type: '出去吃', level: '夯', score: 4, busyLevel: 2, avgCost: 18, history: [10, 15], bgImg: fallbackImages[3], lat: 23.088200, lng: 113.294000 },
  { name: '袁记云饺(下渡路)', type: '出去吃', level: '人上人', score: 4, busyLevel: 1, avgCost: 20, history: [10, 15], bgImg: fallbackImages[4], lat: 23.087800, lng: 113.294300 },
  { name: '八合里牛肉火锅(南门)', type: '出去吃', level: '顶级', score: 5, busyLevel: 3, avgCost: 80, history: [30, 45], bgImg: fallbackImages[2], lat: 23.088900, lng: 113.296000 },
  { name: '瑞幸咖啡(中大南门)', type: '出去吃', level: 'NPC', score: 4, busyLevel: 2, avgCost: 15, history: [5, 10], bgImg: fallbackImages[0], lat: 23.089100, lng: 113.295500 },
  { name: '塔汀轻食(中大店)', type: '出去吃', level: '人上人', score: 4, busyLevel: 1, avgCost: 35, history: [15, 20], bgImg: fallbackImages[1], lat: 23.088500, lng: 113.293800 },
  { name: '鹭江阿婆牛杂', type: '出去吃', level: '顶级', score: 5, busyLevel: 3, avgCost: 20, history: [15, 30], bgImg: fallbackImages[2], lat: 23.095500, lng: 113.308500 },
  { name: '鹭江地铁口烧烤摊', type: '出去吃', level: '夯', score: 5, busyLevel: 2, avgCost: 45, history: [20, 30], bgImg: fallbackImages[3], lat: 23.094500, lng: 113.309000 },
  { name: '绝味鸭脖(鹭江店)', type: '出去吃', level: 'NPC', score: 3, busyLevel: 1, avgCost: 25, history: [5, 10], bgImg: fallbackImages[0], lat: 23.096000, lng: 113.308200 },
  { name: '达美乐(鹭江店)', type: '出去吃', level: '夯', score: 4, busyLevel: 2, avgCost: 40, history: [15, 25], bgImg: fallbackImages[1], lat: 23.094800, lng: 113.307500 },
  { name: '1点点(东门外)', type: '出去吃', level: '人上人', score: 4, busyLevel: 2, avgCost: 15, history: [10, 20], bgImg: fallbackImages[4], lat: 23.095200, lng: 113.307000 },
  { name: '点都德(客村店)', type: '出去吃', level: '顶级', score: 5, busyLevel: 3, avgCost: 90, history: [40, 60], bgImg: fallbackImages[2], lat: 23.091800, lng: 113.318500 },
  { name: '探鱼(丽影广场店)', type: '出去吃', level: '顶级', score: 5, busyLevel: 3, avgCost: 85, history: [30, 50], bgImg: fallbackImages[3], lat: 23.091500, lng: 113.317500 },
  { name: '呷哺呷哺(丽影广场)', type: '出去吃', level: '夯', score: 4, busyLevel: 2, avgCost: 65, history: [20, 35], bgImg: fallbackImages[1], lat: 23.091600, lng: 113.317800 },
  { name: '遇见长安(丽影店)', type: '出去吃', level: '人上人', score: 4, busyLevel: 2, avgCost: 55, history: [25, 40], bgImg: fallbackImages[4], lat: 23.091400, lng: 113.318000 },
  { name: '客村星光城烤肉', type: '出去吃', level: '顶级', score: 5, busyLevel: 2, avgCost: 120, history: [20, 30], bgImg: fallbackImages[0], lat: 23.092100, lng: 113.318000 },
  { name: '喜茶(丽影广场店)', type: '出去吃', level: '顶级', score: 5, busyLevel: 3, avgCost: 25, history: [20, 30], bgImg: fallbackImages[0], lat: 23.091000, lng: 113.316500 },
  { name: '塔斯汀中国汉堡', type: '点外卖', level: '夯', score: 5, busyLevel: 2, avgCost: 20, history: [35, 45], bgImg: fallbackImages[3], lat: 23.093000, lng: 113.315000 },
  { name: '华莱士(喷射战士)', type: '点外卖', level: '拉完了', score: 2, busyLevel: 1, avgCost: 15, history: [30, 40], bgImg: fallbackImages[1], lat: 23.094000, lng: 113.312000 },
  { name: '猪脚饭(城中村神店)', type: '点外卖', level: 'NPC', score: 4, busyLevel: 2, avgCost: 18, history: [35, 50], bgImg: fallbackImages[0], lat: 23.085000, lng: 113.305000 },
  { name: '蜜雪冰城(外卖)', type: '点外卖', level: 'NPC', score: 4, busyLevel: 2, avgCost: 8, history: [30, 40], bgImg: fallbackImages[4], lat: 23.095000, lng: 113.310000 },
  { name: '霸王茶姬(外卖)', type: '点外卖', level: '人上人', score: 4, busyLevel: 3, avgCost: 22, history: [40, 55], bgImg: fallbackImages[2], lat: 23.091000, lng: 113.318000 },
  { name: '拼豆夜宵小炒', type: '点外卖', level: '夯', score: 5, busyLevel: 2, avgCost: 35, history: [45, 60], bgImg: fallbackImages[3], lat: 23.086000, lng: 113.308000 },
  { name: '全家便利店便当', type: '出去吃', level: 'NPC', score: 3, busyLevel: 1, avgCost: 15, history: [5, 10], bgImg: fallbackImages[1], lat: 23.095000, lng: 113.298000 },
  { name: '7-ELEVEn车仔面', type: '出去吃', level: 'NPC', score: 3, busyLevel: 1, avgCost: 12, history: [5, 10], bgImg: fallbackImages[0], lat: 23.089000, lng: 113.294800 },
  { name: '白象老母鸡汤面', type: '吃泡面', level: '顶级', score: 5, busyLevel: 1, avgCost: 5, history: [3, 5], bgImg: fallbackImages[2], lat: 23.098500, lng: 113.292500 },
  { name: '康师傅红烧牛肉面', type: '吃泡面', level: '夯', score: 4, busyLevel: 1, avgCost: 4, history: [3, 5], bgImg: fallbackImages[3], lat: 23.098500, lng: 113.292500 },
  { name: '合味道海鲜面', type: '吃泡面', level: '人上人', score: 4, busyLevel: 1, avgCost: 6, history: [3, 5], bgImg: fallbackImages[4], lat: 23.098500, lng: 113.292500 }
];

// 💡 修复2：强制拉齐版本号为 V12！彻底击碎旧的黑屏图片缓存！
// 1. 修改这一行的 Key 改为 V13
PersistentStorage.persistProp('MyShopsMagazine_V13_MapSensors', JSON.stringify(defaultShops));

// 绑定持久化数据数组

@Entry
@Component
struct Index {
  @State selectedShop: Shop | null = null;
  @State resultText: string = '饥饿感知系统';
  @State resultSubText: string = '正在连接数字空间矩阵...';
  @State resultCategory: string = '';
  @State isRolling: boolean = false;
  @State textScale: number = 1.0;
  @State weatherIcon: string = '🌤️ 晴朗'; // 新增专门负责图标的变量
  @State currentPreference: number = 0;
  @State isRainy: boolean = false;
  @State weatherDescription: string = '正在获取同步天候...';

  @State currentBudget: number = 100;
  @State isBudgetExpanded: boolean = false;
  @State predictedQueueTime: number = 0;
  @State predictedWalkTime: number = 0;
  @State predictedTotalTime: number = 0;
  @State showReroll: boolean = false;
  @State lastWaitTimeRecord: number = 999;

  // ✅ 打卡功能新增：实际等待时间 / 实际花费的输入框状态（抽中结果后会自动预填预测值，用户可手动校准）
  @State checkInWaitInput: string = '';
  @State checkInCostInput: string = '';

  // ✅ 新增：抽出结果时，下方结果卡片的入场偏移量（配合弹簧动画做"下移归位"效果）
  @State resultCardOffsetY: number = 0;

  // ✅ 动态布局新增：仪表盘区 / 美食图鉴区的弹性比例权重，随内容多少自动伸缩
  // 默认 5:6 让图鉴区更大（方便浏览）；有结果/展开预算时仪表盘按需扩张
  @State topPanelWeight: number = 5;
  @State bottomPanelWeight: number = 6;

  // ✅ 月度报告功能新增：当前查看的报告年份/月份，默认是本月
  @State reportYear: number = new Date().getFullYear();
  @State reportMonth: number = new Date().getMonth() + 1;

  // ✅ 自由流转功能新增：跨设备同步的状态文案，给用户一个直观的连接提示
  @State syncStatus: string = '⚪ 正在连接跨设备同步…';

  @State displayImage: string = getRandomBg();

  // 💡 修复3：跟着上面的写入操作，同步改成读取 V12！
  @StorageLink('MyShopsMagazine_V12_MapSensors') shopsJson: string = '';
  @State shops: Shop[] = [];

  @State currentBreakpoint: string = 'sm';

  @State isShowSheet: boolean = false;
  @State editingIndex: number = -1;

  @State selectedBuildingIndex: number = 0;

  @State batchInputText: string = '';
  @State inputName: string = '';
  @State inputType: string = '吃食堂';
  @State inputCost: string = '20';
  @State inputLat: string = '';
  @State inputLng: string = '';
  @State selectedLevelIndex: number = 4;
  @State inputBusyLevel: number = 2;

  private apiKey: string = '2d471aecb46e469ba8a0a68c75a31ada';
  // ✅ 打卡功能新增：用于从首页“打卡记录”入口直接跳转到 FormSheet 里新增的历史记录标签页
  private formTabsController: TabsController = new TabsController();
  // ✅ 打卡功能新增：等待时间(0~180分钟) / 花费(0~300元) 的可选范围，供滑动选择器弹窗使用
  private waitTimeOptions: string[] = buildNumberRange(180);
  private costOptions: string[] = buildNumberRange(300);
  // ✅ 自由流转功能新增：分布式键值数据库实例 + 固定的数据库 ID（同一应用、同账号的设备会共用这个库）
  private kvManager?: distributedKVStore.KVManager;
  private kvStore?: distributedKVStore.SingleKVStore;
  private readonly distributedStoreId: string = 'shilihua_checkin_store';

  // ✅ 动态布局新增：根据"有无结果"+"预算是否展开"，动态计算两个区域的弹性比例权重
  // 设计逻辑：
  //   默认（无结果，预算收起）→ 5:6，图鉴区更大，方便浏览
  //   有结果 OR 预算展开    → 6:5，两区均衡
  //   有结果 AND 预算展开   → 8:3，仪表盘优先，确保打卡区/偏好按钮/开始决定都完整露出
  updatePanelWeights(): void {
    let hasResult = this.predictedTotalTime > 0;
    let budgetOpen = this.isBudgetExpanded;
    if (hasResult && budgetOpen) {
      this.topPanelWeight = 8;
      this.bottomPanelWeight = 3;
    } else if (hasResult || budgetOpen) {
      this.topPanelWeight = 6;
      this.bottomPanelWeight = 5;
    } else {
      this.topPanelWeight = 5;
      this.bottomPanelWeight = 6;
    }
  }

  formatDistance(meters: number): string {
    return meters < 1000 ? `${meters}米` : `${(meters / 1000).toFixed(1)}公里`;
  }

  aboutToAppear(): void {
    // 🌟 降维打击式清洗：只要包含 22.（老深圳坐标开头），直接强制全量重写为广州康乐园饭单！
    if (!this.shopsJson || this.shopsJson.includes('22.')) {
      console.warn('检测到残留的深圳校区沙盒数据，启动强效重置引擎！');
      this.shops = defaultShops;
      this.syncDataToStorage();
    } else {
      try {
        let parsed: Shop[] = JSON.parse(this.shopsJson) as Shop[];
        if (parsed && parsed.length > 0) {
          // 💡 核心修复：在这里加一道强力过滤！只要发现图片链接里包含以前打不开的 unsplash，直接抹空！
          this.shops = parsed.map((s: Shop) => {
            if (!s.bgImg || s.bgImg.includes('unsplash.com')) {
              s.bgImg = ''; // 彻底抹除坏图源，强行触发暖色渐变兜底
            }
            return s;
          });
        } else {
          this.shops = defaultShops;
        }
      } catch {
        this.shops = defaultShops;
      }
    }
    setTimeout(() => { this.fetchEnvironmentData(); }, 500);
    // ✅ 自由流转功能新增：异步初始化跨设备同步，失败也不影响本机打卡功能正常使用
    this.initDistributedSync();
  }

  calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R: number = 6371e3;
    const dLat: number = (lat2 - lat1) * Math.PI / 180;
    const dLon: number = (lon2 - lon1) * Math.PI / 180;
    const a: number = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c: number = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Math.floor(R * c);
  }

  async fetchEnvironmentData(): Promise<void> {
    let targetLat: number = 23.098400;
    let targetLng: number = 113.298200;

    if (this.selectedBuildingIndex === 0) {
      try {
        let atManager = abilityAccessCtrl.createAtManager();
        let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        await atManager.requestPermissionsFromUser(context, ['ohos.permission.LOCATION', 'ohos.permission.APPROXIMATELY_LOCATION']);
        await new Promise<void>((resolve: Function) => { setTimeout(() => { resolve(); }, 1000); });
        let requestInfo: geoLocationManager.CurrentLocationRequest = { 'priority': 0x203, 'scenario': 0x300 };
        let location = await geoLocationManager.getCurrentLocation(requestInfo);
        targetLng = location.longitude; targetLat = location.latitude;
        promptAction.showToast({ message: '🛰️ 真实 GPS 定位获取成功！', duration: 2000 });
      } catch (err) {
        console.error('定位大失败: ' + JSON.stringify(err));
        promptAction.showToast({ message: '⚠️ 您拒绝了定位或信号极弱，已降级至基准点', duration: 3000 });
      }
    }

    let updatedShops = this.shops.map((shop: Shop) => {
      let shopLat = shop.lat || (23.098400 + (Math.random() - 0.5) * 0.008);
      let shopLng = shop.lng || (113.298200 + (Math.random() - 0.5) * 0.008);
      shop.lat = shopLat; shop.lng = shopLng;
      let dist = this.calculateDistance(targetLat, targetLng, shopLat, shopLng);
      shop.rawDistance = dist; shop.distanceStr = this.formatDistance(dist);
      return shop;
    });
    this.shops = [...updatedShops];

    let httpRequest = http.createHttp();
    let url = `https://mt3byhey58.re.qweatherapi.com/v7/weather/now?location=${targetLng.toFixed(4)},${targetLat.toFixed(4)}&key=${this.apiKey}`;

    try {
      let data = await httpRequest.request(url, { method: http.RequestMethod.GET, connectTimeout: 3000 });
      if (data.responseCode === 200) {
        let result: WeatherResponse = JSON.parse(data.result as string) as WeatherResponse;
        this.isRainy = result.now.text.includes('雨');
        this.weatherDescription = result.now.text;
        // 💡 算出文字后直接把图标也死死绑定！
        this.weatherIcon = this.isRainy ? '🌧️ 降雨' : (this.weatherDescription.includes('阴') || this.weatherDescription.includes('云') ? '☁️ 阴云' : '🌤️ 晴朗');
      }
    } catch (err) {
      this.applyFallbackWeather();
    } finally {
      httpRequest.destroy();
    }
  }

  applyFallbackWeather(): void {
    const hour = new Date().getHours();
    const randomValue = Math.random();
    if (hour >= 18 || hour <= 6) {
      if (randomValue > 0.8) { this.weatherDescription = '雷阵雨夜'; this.isRainy = true; this.weatherIcon = '🌧️ 降雨'; }
      else if (randomValue > 0.5) { this.weatherDescription = '阴沉多云'; this.isRainy = false; this.weatherIcon = '☁️ 阴云'; }
      else { this.weatherDescription = '清朗夜空'; this.isRainy = false; this.weatherIcon = '🌤️ 晴朗'; }
    } else {
      if (randomValue > 0.7) { this.weatherDescription = '倾盆大雨'; this.isRainy = true; this.weatherIcon = '🌧️ 降雨'; }
      else if (randomValue > 0.3) { this.weatherDescription = '多云阴天'; this.isRainy = false; this.weatherIcon = '☁️ 阴云'; }
      else { this.weatherDescription = '阳光普照'; this.isRainy = false; this.weatherIcon = '🌤️ 晴朗'; }
    }
  }

  predictWaitTime(shop: Shop): number {
    if (shop.type === '吃泡面') return Math.floor(Math.random() * 3) + 3;
    if (shop.type === '点外卖') return this.isRainy ? (Math.floor(Math.random() * 15) + 40) : (Math.floor(Math.random() * 10) + 25);
    const history = shop.history || [10, 15];
    let baseAvg = history.reduce((a: number, b: number) => a + b, 0) / history.length;
    const hour = new Date().getHours();
    const isPeakHour = (hour >= 11 && hour <= 13) || (hour >= 17 && hour <= 19);
    if (shop.type === '吃食堂') {
      let waitTime = baseAvg + (shop.busyLevel === 3 ? 5 : (shop.busyLevel === 1 ? -3 : 0)) + (isPeakHour ? 8 : 0);
      return Math.max(2, Math.min(Math.ceil(waitTime), 25));
    } else {
      let waitTime = baseAvg * [0.8, 1.0, 1.5][(shop.busyLevel || 2) - 1] * (isPeakHour ? 1.5 : 1.0) + (Math.floor(Math.random() * 8) - 4);
      return Math.max(5, Math.ceil(waitTime));
    }
  }

  rollFood(): void {
    if (this.isRolling) return;
    let validShops = this.shops.filter((s: Shop) => {

      const budgetPass = this.isBudgetExpanded
        ? Number(s.avgCost) <= Number(this.currentBudget)
        : true;

      if (!budgetPass) {
        return false;
      }

      // 点击“重新选择”时
      if (this.showReroll && this.lastWaitTimeRecord < 999) {

        const waitTime = this.predictWaitTime(s);
        const walkTime = Math.ceil((s.rawDistance || 0) / 80);

        const totalTime =
          s.type === '点外卖'
            ? Math.max(waitTime, walkTime)
            : waitTime + walkTime;

        return totalTime < this.lastWaitTimeRecord;
      }

      return true;
    });
    this.lastWaitTimeRecord = this.showReroll ? this.predictedTotalTime : 999;
    this.isRolling = true; this.showReroll = false; this.resultCategory = '';
    let availableTypes = Array.from(new Set(validShops.map((s: Shop) => s.type)));
    let count = 0;

    let intervalId = setInterval(() => {
      let tempShop = validShops[Math.floor(Math.random() * validShops.length)];
      this.resultText = tempShop.name; this.displayImage = tempShop.bgImg || getRandomBg(); count++;

      if (count > 15) {
        clearInterval(intervalId);
        let finalType = availableTypes[Math.floor(Math.random() * availableTypes.length)];
        let weatherFactor = 1.0;
        if (this.isRainy && finalType === '出去吃') weatherFactor = 0.2;
        if (this.isRainy && (finalType === '点外卖' || finalType === '吃泡面')) weatherFactor = 2.0;

        let finalAvailableShops = validShops.filter((s: Shop) => s.type === finalType);
        let lotteryPool: LotteryItem[] = []; let totalTickets = 0;

        finalAvailableShops.forEach((shop: Shop) => {
          let finalWeight = 1; let waitTime = this.predictWaitTime(shop); let walkTime = Math.ceil((shop.rawDistance || 0) / 80);
          let totalTime = shop.type === '点外卖' ? Math.max(waitTime, walkTime) : waitTime + walkTime;
          switch (this.currentPreference) {
            case 0: finalWeight = Math.max(1, (shop.score || 3) - ((shop.busyLevel || 2) - 1)); break;
            case 1: finalWeight = Math.max(1, 10 - Math.floor((shop.avgCost || 20) / 10)); break;
            case 2: finalWeight = totalTime < 15 ? 10 : Math.max(1, 8 - Math.floor(totalTime / 5)); break;
            case 3: finalWeight = (shop.score || 3) >= 4 ? (shop.score || 3) * 3 : 1; break;
            case 4: finalWeight = (shop.rawDistance || 0) < 200 ? 10 : Math.max(1, 10 - Math.floor((shop.rawDistance || 0) / 200)); break;
          }
          let tickets = Math.max(10, Math.floor(finalWeight * 10 * weatherFactor));
          lotteryPool.push(new LotteryItem(shop, tickets)); totalTickets += tickets;
        });

        let winningTicket = Math.floor(Math.random() * totalTickets); let currentTicketCount = 0; let bestShop = finalAvailableShops[0];
        for (let i = 0; i < lotteryPool.length; i++) {
          currentTicketCount += lotteryPool[i].tickets;
          if (currentTicketCount > winningTicket) { bestShop = lotteryPool[i].shop; break; }
        }

        this.resultText = bestShop.name; this.resultCategory = `${finalType}`;
        let locLabel = bestShop.type === '吃泡面' ? ' (宿舍)' : (bestShop.type === '点外卖' ? ' (外卖柜)' : '');
        this.resultSubText = `预估人均：￥${bestShop.avgCost} | 评级：${bestShop.level} | 📍 距离: ${bestShop.distanceStr}${locLabel}`;
        this.displayImage = bestShop.bgImg || getRandomBg();

        let finalQueueTime = this.predictWaitTime(bestShop); let finalWalkTime = Math.ceil((bestShop.rawDistance || 0) / 80);
        let newTotalTime = bestShop.type === '点外卖' ? Math.max(finalQueueTime, finalWalkTime) : finalQueueTime + finalWalkTime;

        if (this.lastWaitTimeRecord < 999 && newTotalTime > this.lastWaitTimeRecord) {
          newTotalTime = this.lastWaitTimeRecord;
          if (bestShop.type === '点外卖') { finalQueueTime = newTotalTime; } else { finalQueueTime = Math.max(0, newTotalTime - finalWalkTime); }
          newTotalTime = bestShop.type === '点外卖' ? Math.max(finalQueueTime, finalWalkTime) : finalQueueTime + finalWalkTime;
        }

        this.predictedQueueTime = finalQueueTime; this.predictedWalkTime = finalWalkTime; this.predictedTotalTime = newTotalTime;
        if (this.predictedTotalTime > 30) { this.showReroll = true; }

        // ✅ 打卡功能新增：记录本次抽中的店铺，并把预测值预填进打卡输入框，方便用户直接确认或手动修正
        this.selectedShop = bestShop;
        this.checkInWaitInput = this.predictedTotalTime.toString();
        this.checkInCostInput = bestShop.avgCost.toString();

        // ✅ 新增：先把卡片放到上方一点，紧接着用弹簧动画下移归位，做出"抽出结果时卡片下移落定"的效果
        this.resultCardOffsetY = -16;

        this.isRolling = false;
        this.getUIContext().animateTo({ curve: curves.springMotion() }, () => {
          this.textScale = 1.1;
          this.resultCardOffsetY = 0;
          this.updatePanelWeights(); // ✅ 动态布局新增：结果落地时同步扩大仪表盘区
        });
        setTimeout(() => { this.textScale = 1.0; }, 300);
      }
    }, 100);
  }

  // ==========================================
  // 📚 瀑布流卡片组件 (护城河防黑屏终极版)
  // ==========================================
  // ==========================================
  // 📚 瀑布流卡片组件 (暖色食欲渐变抗黑屏版)
  // ==========================================
  // ==========================================
  // 📚 瀑布流卡片组件 (彻底消灭蓝色方块版)
  // ==========================================
  @Builder MagazineCardBuilder(item: Shop, index: number) {
    Stack({ alignContent: Alignment.Bottom }) {

      // 1. 底层铺上食欲暖色渐变（替代掉原本的冷色）
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: getWarmGradient(item.type) as Array<[ResourceColor, number]>
        })
        .borderRadius(16)

      // 2. 顶层图片（彻底删除了 .alt 属性，加载失败时直接露出下方的暖色渐变，绝不显示系统蓝块）
      Image(item.bgImg || getRandomBg())
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .borderRadius(16)
        .opacity(0.85)

      // 3. 文字与信息层
      Column({ space: 4 }) {
        Text(item.name).fontSize(16).fontWeight(FontWeight.Bolder).fontColor(Color.White).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Row() {
          Text(`￥${item.avgCost}`).fontSize(14).fontColor('#FFD700').fontWeight(FontWeight.Bold)
          Blank()
          Text(item.level).fontSize(10).fontColor(Color.White).backgroundColor('rgba(255,255,255,0.2)').padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(4)
        }.width('100%').margin({ top: 4 })

        if (item.distanceStr) {
          Row() {
            Text(`📍 ${item.distanceStr}`).fontSize(10).fontColor('#E0E0E0')
            Blank()
            Text(item.type).fontSize(10).fontColor('#E0E0E0')
          }.width('100%').margin({ top: 2 })
        }
      }
      .width('100%').padding(12)
      .backgroundBlurStyle(BlurStyle.Regular).backgroundColor('rgba(0,0,0,0.3)').borderRadius({ bottomLeft: 16, bottomRight: 16 })
    }
    .width('100%')
    .height(index % 3 === 0 ? 240 : (index % 2 === 0 ? 180 : 210))
    .borderRadius(16).shadow({ radius: 10, color: 'rgba(0,0,0,0.15)', offsetY: 5 })
    .onClick(() => {
      this.editingIndex = index;
      this.inputName = item.name;
      this.inputCost = item.avgCost.toString();
      this.inputType = item.type;
      this.selectedLevelIndex = ['拉完了', 'NPC', '人上人', '顶级', '夯'].indexOf(item.level);
      this.inputBusyLevel = item.busyLevel;
      this.isShowSheet = true;
    })
  }

  @Builder MagazineDashboard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.displayImage !== '') {
        Image(this.displayImage).width('100%').height('100%').objectFit(ImageFit.Cover).animation({ duration: 300, curve: Curve.EaseInOut })
        Column().width('100%').height('100%').backgroundBlurStyle(BlurStyle.Regular).backgroundColor('rgba(0,0,0,0.4)')
      } else {
        Column().width('100%').height('100%').backgroundColor('#121212')
      }

      Column() {
        Row({ space: 10 }) {
          // 💡 直接读取算好的图标变量！
          Text(this.weatherIcon)
            .fontSize(12).fontColor(Color.White).fontWeight(FontWeight.Bold)
          Text('|').fontColor('rgba(255,255,255,0.3)')
          Text(`实时天候: ${this.weatherDescription}`).fontSize(12).fontColor(Color.White)
          Blank()
          // ✅ 打卡功能新增：点击直接打开表单弹窗并跳转到“打卡记录”标签页
          Text(`📋 打卡记录(${this.checkInRecords.length})`)
            .fontSize(12).fontColor(Color.White).fontWeight(FontWeight.Medium)
            .onClick(() => {
              this.isShowSheet = true;
              setTimeout(() => { this.formTabsController.changeIndex(2); }, 100);
            })
        }
        Blank()

        Row({ space: 8 }) {
          Text('📍 空间锚点:').fontSize(12).fontColor('rgba(255,255,255,0.7)')
          Select([{ value: campusMapNodes[0].name }, { value: campusMapNodes[1].name }, { value: campusMapNodes[2].name }, { value: campusMapNodes[3].name }, { value: campusMapNodes[4].name }])
            .selected(this.selectedBuildingIndex).value(campusMapNodes[this.selectedBuildingIndex].name)
            .fontColor(Color.White).font({ size: 12, weight: FontWeight.Medium }).backgroundColor('rgba(255,255,255,0.15)').borderRadius(8)
            .onSelect((index: number) => { this.selectedBuildingIndex = index; this.fetchEnvironmentData(); })
        }.padding({ left: 12, right: 12, top: 6, bottom: 6 }).backgroundColor('rgba(0,0,0,0.3)').borderRadius(12)
        Blank()

        Column({ space: 8 }) {
          if (this.resultCategory !== '') { Text(this.resultCategory).fontSize(14).fontColor('#FFD700').fontWeight(FontWeight.Medium) }
          Text(this.resultText).fontSize(this.currentBreakpoint === 'sm' ? (this.resultText.length > 8 ? 24 : 32) : (this.resultText.length > 8 ? 28 : 38))
            .fontWeight(FontWeight.Bolder).fontColor(Color.White).scale({ x: this.textScale, y: this.textScale }).textAlign(TextAlign.Center)
          Text(this.resultSubText).fontSize(13).fontColor('rgba(255,255,255,0.8)').textAlign(TextAlign.Center).padding({ left: 10, right: 10 })

          if (this.predictedTotalTime > 0) {
            Column({ space: 6 }) {
              Row({ space: 15 }) {
                Text(`🚶 步行: ${this.predictedWalkTime} 分钟`).fontSize(12).fontColor('rgba(255,255,255,0.8)')
                Text(`⏳ 等候: ${this.predictedQueueTime} 分钟`).fontSize(12).fontColor('rgba(255,255,255,0.8)')
              }
              Text(`预计总耗时: ${this.predictedTotalTime} 分钟`).fontSize(15).fontColor(this.predictedTotalTime > 30 ? '#FF5252' : '#00E676').fontWeight(FontWeight.Bold)
              if (this.showReroll) { Button('耗时太久，重新选择').height(28).fontSize(12).backgroundColor('#D32F2F').fontColor(Color.White).margin({ top: 5 }).onClick(() => { this.rollFood(); }) }

              // ✅ 打卡功能新增：等待时间 / 花费改成"像闹钟一样上下滑动"的选择器弹窗，而不是手敲键盘
              if (this.selectedShop) {
                Row({ space: 4 }) {
                  Text('⏱').fontSize(12).fontColor('rgba(255,255,255,0.7)')
                  Text(`${this.checkInWaitInput} 分`)
                    .layoutWeight(1).height(26).fontSize(11).fontColor(Color.White).textAlign(TextAlign.Center)
                    .backgroundColor('rgba(255,255,255,0.15)').borderRadius(6)
                    .onClick(() => {
                      let idx = Number(this.checkInWaitInput);
                      this.getUIContext().showTextPickerDialog({
                        range: this.waitTimeOptions,
                        selected: (!isNaN(idx) && idx >= 0 && idx <= 180) ? idx : 0,
                        onAccept: (value: TextPickerResult) => { this.checkInWaitInput = value.value as string; }
                      });
                    })
                  Text('💰').fontSize(12).fontColor('rgba(255,255,255,0.7)').margin({ left: 6 })
                  Text(`¥${this.checkInCostInput}`)
                    .layoutWeight(1).height(26).fontSize(11).fontColor(Color.White).textAlign(TextAlign.Center)
                    .backgroundColor('rgba(255,255,255,0.15)').borderRadius(6)
                    .onClick(() => {
                      let idx = Number(this.checkInCostInput);
                      this.getUIContext().showTextPickerDialog({
                        range: this.costOptions,
                        selected: (!isNaN(idx) && idx >= 0 && idx <= 300) ? idx : 0,
                        onAccept: (value: TextPickerResult) => { this.checkInCostInput = value.value as string; }
                      });
                    })
                  Button('📌 打卡')
                    .height(26).fontSize(11).fontWeight(FontWeight.Bold).margin({ left: 6 })
                    .backgroundColor('#00C853').fontColor(Color.White).borderRadius(13)
                    .onClick(() => {
                      let finalWait = Number(this.checkInWaitInput);
                      let finalCost = Number(this.checkInCostInput);
                      this.saveCheckIn(
                        isNaN(finalWait) ? this.predictedTotalTime : finalWait,
                        isNaN(finalCost) ? (this.selectedShop ? this.selectedShop.avgCost : 0) : finalCost
                      );
                    })
                }.width('100%').margin({ top: 4 })
              }
            }.margin({ top: 5 }).padding(10).backgroundColor('rgba(0,0,0,0.4)').borderRadius(12)
            .translate({ y: this.resultCardOffsetY })
          }
        }
        Blank()

        Column({ space: 10 }) {
          Text(this.isBudgetExpanded ? '收起预算设定 ▲' : '展开预算设定 ▼').fontSize(12).fontColor('rgba(255,255,255,0.6)')
            .onClick(() => { this.getUIContext().animateTo({ curve: curves.springMotion() }, () => { this.isBudgetExpanded = !this.isBudgetExpanded; this.updatePanelWeights(); }); })
          if (this.isBudgetExpanded) {
            Row() { Text('预算上限').fontSize(12).fontColor('rgba(255,255,255,0.8)'); Blank(); Text(`￥${this.currentBudget}`).fontSize(20).fontColor(Color.White).fontWeight(FontWeight.Bold) }.width('85%')
            Slider({ value: this.currentBudget, min: 10, max: 200, step: 5, style: SliderStyle.OutSet }).onChange((v: number) => { this.currentBudget = Math.floor(v); }).width('90%').selectedColor(Color.White).trackColor('rgba(255,255,255,0.2)')
          }
          Row({ space: 6 }) {
            ForEach(['综合', '省钱', '效率', '美味', '距离'], (label: string, index: number) => {
              Text(label).layoutWeight(1).height(30).fontSize(12).textAlign(TextAlign.Center).fontWeight(FontWeight.Medium)
                .backgroundColor(this.currentPreference === index ? Color.White : 'rgba(255,255,255,0.1)').fontColor(this.currentPreference === index ? Color.Black : Color.White).borderRadius(15).onClick(() => { this.currentPreference = index; })
            }, (item: string) => item)
          }.width('95%')
        }.width('100%').alignItems(HorizontalAlign.Center)
        Blank()

        Button(this.isRolling ? '算法运算中...' : '开始决定')
          .width('75%').height(42).fontSize(15).fontWeight(FontWeight.Bold).backgroundColor(this.isRolling ? 'rgba(255,255,255,0.2)' : Color.White)
          .fontColor(this.isRolling ? Color.White : Color.Black).borderRadius(21).onClick(() => { this.rollFood(); })
      }.width('100%').height('100%').padding({ left: 10, right: 10, top: 12, bottom: 12 })
    }.width('100%').height('100%')
  }

  @Builder DataGridPanel() {
    Column() {
      Row() {
        Text(`美食图鉴 (${this.shops.length})`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333').layoutWeight(1)
        Button('+ 手工录入').height(30).fontSize(12).backgroundColor('#1A1A1A').onClick(() => { this.editingIndex = -1; this.isShowSheet = true; })
      }.width('100%').padding({ left: 20, right: 20, top: 15, bottom: 10 })

      WaterFlow() {
        ForEach(this.shops, (item: Shop, index: number) => {
          FlowItem() { this.MagazineCardBuilder(item, index) }
        }, (item: Shop, index: number) => item.name + index + item.rawDistance)
      }.columnsTemplate(this.currentBreakpoint === 'sm' || this.currentBreakpoint === 'xs' ? '1fr 1fr' : '1fr 1fr 1fr')
      .columnsGap(10).rowsGap(10).padding({ left: 15, right: 15, bottom: 15 }).layoutWeight(1)
    }.width('100%').height('100%').backgroundColor('#F5F5F7')
  }

  parseBatchInput(): void {
    if (this.batchInputText.trim() === '') return;
    let lines: string[] = this.batchInputText.split('\n');
    lines.forEach((line: string) => {
      let parts: string[] = line.split(/[ ,，-]+/);
      if (parts.length >= 2) {
        let cost = parts.length >= 3 ? Number(parts[2]) : 20;
        const newShop: Shop = {
          name: parts[0], type: parts[1], level: '人上人', score: 4, busyLevel: 2, avgCost: isNaN(cost) ? 20 : cost, history: [15], bgImg: getRandomBg(),
          lat: 23.098400 + (Math.random() - 0.5) * 0.008, lng: 113.298200 + (Math.random() - 0.5) * 0.008
        };
        this.shops.push(newShop);
      }
    });
    this.syncDataToStorage();
    this.batchInputText = '';
    this.fetchEnvironmentData();
  }

  syncDataToStorage(): void { this.shopsJson = JSON.stringify(this.shops); }

  @Builder FormSheet() {
    Tabs({ controller: this.formTabsController }) {
      TabContent() {
        Column({ space: 15 }) {
          Text('时空矩阵批量导入').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
          TextArea({ placeholder: '格式：名称 分类 价格\n示例：\n松涛园一楼 吃食堂 15', text: this.batchInputText })
            .onChange((v: string) => this.batchInputText = v).height(140).backgroundColor('#F5F7FA').padding(10).borderRadius(8)
          Button('存入中心数据库').width('100%').height(42).backgroundColor('#1A1A1A').fontColor(Color.White).fontWeight(FontWeight.Bold).borderRadius(20)
            .onClick(() => { this.parseBatchInput(); this.isShowSheet = false; })
        }.padding(20)
      }.tabBar('批量导入')

      TabContent() {
        Column({ space: 12 }) {
          Text(this.editingIndex === -1 ? '手动校准新目标' : '数据重新校准').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
          TextInput({ placeholder: '店铺名称', text: this.inputName }).onChange((v: string) => this.inputName = v).backgroundColor('#F5F7FA').borderRadius(8)

          Row({ space: 10 }) {
            TextInput({ placeholder: '人均消费 (￥)', text: this.inputCost }).type(InputType.Number).layoutWeight(1).onChange((v: string) => this.inputCost = v).backgroundColor('#F5F7FA').borderRadius(8)
            Select([{ value: '吃食堂' }, { value: '点外卖' }, { value: '出去吃' }, { value: '吃泡面' }]).value(this.inputType).onSelect((_index: number, value: string) => this.inputType = value).layoutWeight(1).borderRadius(8)
          }

          Row({ space: 10 }) {
            Select([{ value: '拉完了' }, { value: 'NPC' }, { value: '人上人' }, { value: '顶级' }, { value: '夯' }])
              .value(['拉完了', 'NPC', '人上人', '顶级', '夯'][this.selectedLevelIndex]).onSelect((index: number) => this.selectedLevelIndex = index).layoutWeight(1)
            Select([{ value: '空闲 (1)' }, { value: '正常 (2)' }, { value: '拥挤 (3)' }])
              .value(['空闲 (1)', '正常 (2)', '拥挤 (3)'][this.inputBusyLevel - 1]).onSelect((index: number) => this.inputBusyLevel = index + 1).layoutWeight(1)
          }

          Row({ space: 10 }) {
            TextInput({ placeholder: '纬度(选填)', text: this.inputLat }).type(InputType.Number).layoutWeight(1).onChange((v: string) => this.inputLat = v).backgroundColor('#F5F7FA')
            TextInput({ placeholder: '经度(选填)', text: this.inputLng }).type(InputType.Number).layoutWeight(1).onChange((v: string) => this.inputLng = v).backgroundColor('#F5F7FA')
          }.width('100%')

          Button('写入数据库').width('100%').height(42).backgroundColor('#1A1A1A').fontColor(Color.White).fontWeight(FontWeight.Bold).borderRadius(20).margin({ top: 5 })
            .onClick(() => {
              if (!this.inputName) return;
              let finalImg = getRandomBg();
              if (this.editingIndex !== -1 && this.shops[this.editingIndex].bgImg) { finalImg = this.shops[this.editingIndex].bgImg; }

              const newShop: Shop = {
                name: this.inputName, type: this.inputType, level: ['拉完了', 'NPC', '人上人', '顶级', '夯'][this.selectedLevelIndex],
                score: this.selectedLevelIndex + 1, busyLevel: this.inputBusyLevel, avgCost: Number(this.inputCost), history: [15], bgImg: finalImg,
                lat: this.inputLat !== '' ? Number(this.inputLat) : (23.098400 + (Math.random() - 0.5) * 0.008),
                lng: this.inputLng !== '' ? Number(this.inputLng) : (113.298200 + (Math.random() - 0.5) * 0.008)
              };
              if (this.editingIndex === -1) { this.shops.push(newShop); } else { this.shops[this.editingIndex] = newShop; }
              this.syncDataToStorage(); this.fetchEnvironmentData(); this.isShowSheet = false;
            })
        }.padding(20)
      }.tabBar('精细录入')

      // ✅ 打卡功能新增：第三个标签页，展示历史打卡记录
      TabContent() {
        Column({ space: 12 }) {
          Row() {
            Text(`📋 打卡记录 (共 ${this.checkInRecords.length} 次)`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333').layoutWeight(1)
            if (this.checkInRecords.length > 0) {
              Text('清空').fontSize(12).fontColor('#D32F2F').onClick(() => { this.clearCheckInRecords(); })
            }
          }.width('100%')

          // ✅ 自由流转功能新增：跨设备同步状态提示，失败时可以点一下"重试"
          Row({ space: 8 }) {
            Text(this.syncStatus).fontSize(11).fontColor('#999').layoutWeight(1)
            if (this.syncStatus.indexOf('未开启') >= 0) {
              Text('重试').fontSize(11).fontColor('#007AFF').onClick(() => { this.initDistributedSync(); })
            }
          }.width('100%')

          if (this.checkInRecords.length === 0) {
            Column({ space: 6 }) {
              Text('暂无打卡记录').fontSize(14).fontColor('#999')
              Text('在首页点"开始决定"抽中店铺后，下方会出现"确认打卡"按钮').fontSize(12).fontColor('#BBB').textAlign(TextAlign.Center)
            }.width('100%').padding({ top: 40 })
          } else {
            List({ space: 10 }) {
              ForEach(this.checkInRecords.slice().reverse(), (record: CheckInRecord) => {
                ListItem() {
                  Row() {
                    Column({ space: 4 }) {
                      Text(record.shopName).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#222').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(new Date(record.date).toLocaleString()).fontSize(11).fontColor('#999')
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Column({ space: 4 }) {
                      Text(`￥${record.cost}`).fontSize(13).fontColor('#FF7A45').fontWeight(FontWeight.Bold)
                      Text(`${record.waitTime} 分钟`).fontSize(11).fontColor('#666')
                    }.alignItems(HorizontalAlign.End)
                    Text('✕').fontSize(14).fontColor('#CCC').padding(6).onClick(() => { this.deleteCheckInRecord(record.id); })
                  }.width('100%').padding(12).backgroundColor('#F8F8FA').borderRadius(10)
                }
              }, (record: CheckInRecord) => record.id)
            }.width('100%').height('100%').layoutWeight(1)
          }
        }.padding(20).width('100%').height('100%')
      }.tabBar('打卡记录')

      // ✅ 月度报告功能新增：第四个标签页，按月汇总打卡数据（内容较多，用 Scroll 包裹，避免被裁切）
      TabContent() {
        Scroll() {
          Column({ space: 14 }) {
            // 月份切换
            Row() {
              Text('‹').fontSize(20).fontColor('#666').fontWeight(FontWeight.Bold).padding(8)
                .onClick(() => { this.shiftReportMonth(-1); })
              Text(`${this.reportYear}年${this.reportMonth}月`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333').layoutWeight(1).textAlign(TextAlign.Center)
              Text('›').fontSize(20).fontColor(this.isCurrentOrFutureMonth() ? '#DDD' : '#666').fontWeight(FontWeight.Bold).padding(8)
                .onClick(() => { if (!this.isCurrentOrFutureMonth()) { this.shiftReportMonth(1); } })
            }.width('100%')

            // ✅ 丰富月度报告：统计格改成 2x2，多展示一个"均消费"指标
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Text(`${this.getMonthSummary().count}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FF7A45')
                Text('打卡次数').fontSize(11).fontColor('#999')
              }.layoutWeight(1).padding(10).backgroundColor('#F8F8FA').borderRadius(10)
              Column({ space: 4 }) {
                Text(`¥${this.getMonthSummary().totalCost}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FF7A45')
                Text('总花费').fontSize(11).fontColor('#999')
              }.layoutWeight(1).padding(10).backgroundColor('#F8F8FA').borderRadius(10)
            }.width('100%')
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Text(`¥${this.getMonthSummary().count > 0 ? Math.round(this.getMonthSummary().totalCost / this.getMonthSummary().count) : 0}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FF7A45')
                Text('均消费(每次)').fontSize(11).fontColor('#999')
              }.layoutWeight(1).padding(10).backgroundColor('#F8F8FA').borderRadius(10)
              Column({ space: 4 }) {
                Text(`${this.getMonthSummary().avgWait}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FF7A45')
                Text('均耗时(分)').fontSize(11).fontColor('#999')
              }.layoutWeight(1).padding(10).backgroundColor('#F8F8FA').borderRadius(10)
            }.width('100%')

            if (this.getMonthSummary().count > 0) {
              // ✅ 丰富月度报告：环比上月
              Text(this.getMonthOverMonthText()).fontSize(11).fontColor('#999').width('100%')

              // 本月最常去的店铺
              Row({ space: 8 }) {
                Text('🏆').fontSize(16)
                Text(`本月最常去：${this.getMonthSummary().topShop}（${this.getMonthSummary().topShopCount} 次）`).fontSize(13).fontColor('#333').layoutWeight(1)
              }.width('100%').padding(12).backgroundColor('#FFF6EC').borderRadius(10)

              // ✅ 丰富月度报告：单次最高消费
              Row({ space: 8 }) {
                Text('🔥').fontSize(16)
                Text(`单次最高消费：${this.getMaxSingleCostShopName()} ¥${this.getMaxSingleCost()}`).fontSize(13).fontColor('#333').layoutWeight(1)
              }.width('100%').padding(12).backgroundColor('#FFF0F0').borderRadius(10)

              // ✅ 丰富月度报告：按店铺类型的花费分布（分段条形图 + 图例）
              Column({ space: 8 }) {
                Text('按类型分布').fontSize(12).fontColor('#999').width('100%')
                Row() {
                  ForEach(this.getTypeBreakdown(), (item: TypeBreakdownItem, idx: number) => {
                    Column().layoutWeight(item.cost > 0 ? item.cost : 1).height(14).backgroundColor(this.getTypeColor(idx))
                  }, (item: TypeBreakdownItem, _idx: number) => item.type)
                }.width('100%').height(14).borderRadius(7).clip(true)
                Column({ space: 6 }) {
                  ForEach(this.getTypeBreakdown(), (item: TypeBreakdownItem, idx: number) => {
                    Row({ space: 6 }) {
                      Column().width(8).height(8).borderRadius(4).backgroundColor(this.getTypeColor(idx))
                      Text(item.type).fontSize(12).fontColor('#333').layoutWeight(1)
                      Text(`¥${item.cost}`).fontSize(12).fontColor('#999')
                    }.width('100%')
                  }, (item: TypeBreakdownItem, _idx: number) => item.type)
                }.width('100%').margin({ top: 4 })
              }.width('100%').padding(12).backgroundColor('#F8F8FA').borderRadius(10)

              // 每周花费简易柱状图
              Column({ space: 8 }) {
                Text('本月每周花费').fontSize(12).fontColor('#999').width('100%')
                Row({ space: 8 }) {
                  ForEach(this.getWeeklyCosts(), (cost: number, idx: number) => {
                    Column({ space: 4 }) {
                      Column()
                        .width(20)
                        .height(this.getMaxWeeklyCost() > 0 ? Math.max(4, (cost / this.getMaxWeeklyCost()) * 70) : 4)
                        .backgroundColor('#FF7A45').borderRadius(4)
                      Text(`第${idx + 1}周`).fontSize(10).fontColor('#999')
                      Text(`¥${cost}`).fontSize(9).fontColor('#BBB')
                    }.justifyContent(FlexAlign.End)
                  }, (_cost: number, idx: number) => idx.toString())
                }.width('100%').height(110).alignItems(VerticalAlign.Bottom).justifyContent(FlexAlign.SpaceAround)
              }.width('100%').padding(12).backgroundColor('#F8F8FA').borderRadius(10)
            } else {
              Column({ space: 6 }) {
                Text('这个月还没有打卡记录').fontSize(14).fontColor('#999')
                Text('多吃多打卡，月底来看看战绩吧').fontSize(12).fontColor('#BBB')
              }.width('100%').padding({ top: 30 })
            }
          }.padding(20).width('100%')
        }.width('100%').height('100%').scrollBar(BarState.Off)
      }.tabBar('月度报告')
    }
    .backgroundColor(Color.White).borderRadius({ topLeft: 20, topRight: 20 })
  }
  // 保存打卡记录的逻辑方法
  // 保存打卡记录的逻辑方法（严格遵守 ArkTS 数组操作规范）
  saveCheckIn(waitTime: number, cost: number) {
    if (!this.selectedShop) return;

    let newRecord: CheckInRecord = {
      id: Date.now().toString(),
      shopName: this.selectedShop.name,
      date: Date.now(),
      waitTime: waitTime,
      cost: cost,
      shopType: this.selectedShop.type // ✅ 月度报告功能新增：记下当时的店铺类型，供"按类型分布"统计使用
    };

    // ArkTS 安全写法：直接 push 到持久化数组中
    this.checkInRecords.push(newRecord);

    // ✅ 自由流转功能新增：把这条记录也写进分布式数据库，自动同步给同账号下的其他设备
    this.syncRecordToDistributedStore(newRecord);

    try {
      promptAction.showToast({
        message: '打卡成功！已同步记录。',
        duration: 2000
      });
    } catch (e) {
      console.error('showToast 失败: ' + JSON.stringify(e));
    }
  }

  // ✅ 自由流转功能新增：初始化分布式键值数据库，开启跨设备同步
  async initDistributedSync(): Promise<void> {
    try {
      let atManager = abilityAccessCtrl.createAtManager();
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      // 申请"分布式数据同步"权限（与定位权限是同一套申请方式，用户允许后才能跨设备同步）
      await atManager.requestPermissionsFromUser(context, ['ohos.permission.DISTRIBUTED_DATASYNC']);

      let kvManagerConfig: distributedKVStore.KVManagerConfig = {
        context: context,
        bundleName: context.applicationInfo.name
      };
      this.kvManager = distributedKVStore.createKVManager(kvManagerConfig);

      let options: distributedKVStore.Options = {
        createIfMissing: true,
        encrypt: false,
        backup: false,
        autoSync: true, // 开启自动端端同步，不需要手动调用 sync
        kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      };
      this.kvStore = await this.kvManager.getKVStore(this.distributedStoreId, options) as distributedKVStore.SingleKVStore;

      // 订阅"其他设备"的数据变化，自动把新打卡/删除同步到本机界面上
      this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_REMOTE, (data: distributedKVStore.ChangeNotification) => {
        this.handleRemoteCheckInChange(data);
      });

      // 首次连接时，把本机已有记录与分布式数据库里已有的记录做一次双向合并，避免互相覆盖丢数据
      await this.mergeAndPushAllRecords();

      this.syncStatus = '🔄 跨设备同步已开启';
    } catch (err) {
      console.error('打卡记录跨设备同步初始化失败: ' + JSON.stringify(err));
      this.syncStatus = '⚪ 跨设备同步未开启（不影响本机记录）';
    }
  }

  // ✅ 自由流转功能新增：把单条记录写入分布式数据库（静默失败，不影响本机记录的正常使用）
  syncRecordToDistributedStore(record: CheckInRecord): void {
    if (!this.kvStore) { return; }
    let store = this.kvStore;
    store.put('record:' + record.id, JSON.stringify(record)).catch((err: Error) => {
      console.error('打卡记录同步到其他设备失败: ' + JSON.stringify(err));
    });
  }

  // ✅ 自由流转功能新增：首次连接分布式数据库时，把"本机记录"与"远端记录"按 id 去重合并，
  // 合并后的全量结果再整体补写回分布式数据库，确保所有设备最终看到同一份数据，谁也不会被覆盖丢失
  async mergeAndPushAllRecords(): Promise<void> {
    if (!this.kvStore) { return; }
    let store = this.kvStore;
    try {
      let remoteEntries: distributedKVStore.Entry[] = await store.getEntries('record:');
      let merged: CheckInRecord[] = [...this.checkInRecords];
      remoteEntries.forEach((entry: distributedKVStore.Entry) => {
        try {
          let r: CheckInRecord = JSON.parse(entry.value.value as string) as CheckInRecord;
          if (!merged.some((m: CheckInRecord) => m.id === r.id)) {
            merged.push(r);
          }
        } catch (e) {
          console.error('解析远端打卡记录失败: ' + JSON.stringify(e));
        }
      });
      merged.sort((a: CheckInRecord, b: CheckInRecord) => a.date - b.date);
      this.checkInRecords = merged;

      for (let i = 0; i < this.checkInRecords.length; i++) {
        let r = this.checkInRecords[i];
        await store.put('record:' + r.id, JSON.stringify(r));
      }
    } catch (err) {
      console.error('打卡记录跨设备首次合并失败: ' + JSON.stringify(err));
    }
  }

  // ✅ 自由流转功能新增：收到"其他设备"的数据变化通知后，把新增/更新/删除增量应用到本机记录上
  handleRemoteCheckInChange(data: distributedKVStore.ChangeNotification): void {
    let updated: CheckInRecord[] = [...this.checkInRecords];
    let changed = false;

    let applyEntries = (entries: distributedKVStore.Entry[]): void => {
      entries.forEach((entry: distributedKVStore.Entry) => {
        try {
          let r: CheckInRecord = JSON.parse(entry.value.value as string) as CheckInRecord;
          let idx = updated.findIndex((m: CheckInRecord) => m.id === r.id);
          if (idx >= 0) { updated[idx] = r; } else { updated.push(r); }
          changed = true;
        } catch (e) {
          console.error('解析远端打卡变更失败: ' + JSON.stringify(e));
        }
      });
    };
    applyEntries(data.insertEntries);
    applyEntries(data.updateEntries);

    data.deleteEntries.forEach((entry: distributedKVStore.Entry) => {
      let id = entry.key.indexOf('record:') === 0 ? entry.key.substring(7) : entry.key;
      let before = updated.length;
      updated = updated.filter((m: CheckInRecord) => m.id !== id);
      if (updated.length !== before) { changed = true; }
    });

    if (changed) {
      updated.sort((a: CheckInRecord, b: CheckInRecord) => a.date - b.date);
      this.checkInRecords = updated;
      try {
        promptAction.showToast({ message: '📡 已同步到其他设备的新打卡记录', duration: 2000 });
      } catch (e) {
        console.error('showToast 失败: ' + JSON.stringify(e));
      }
    }
  }

  // ✅ 打卡功能新增：删除单条打卡记录（ArkTS 安全写法：filter 生成新数组再整体赋值，避免直接 splice 触发响应式问题）
  deleteCheckInRecord(id: string): void {
    this.checkInRecords = this.checkInRecords.filter((r: CheckInRecord) => r.id !== id);
    // ✅ 自由流转功能新增：同步删除分布式数据库里的这一条，其他设备也会跟着移除
    if (this.kvStore) {
      let store = this.kvStore;
      store.delete('record:' + id).catch((err: Error) => {
        console.error('打卡记录跨设备删除失败: ' + JSON.stringify(err));
      });
    }
  }

  // ✅ 打卡功能新增：一键清空全部打卡记录
  clearCheckInRecords(): void {
    // ✅ 自由流转功能新增：先把分布式数据库里对应的每一条都删掉，避免其他设备再把旧数据同步回来
    if (this.kvStore) {
      let store = this.kvStore;
      this.checkInRecords.forEach((r: CheckInRecord) => {
        store.delete('record:' + r.id).catch((err: Error) => {
          console.error('打卡记录跨设备清空失败: ' + JSON.stringify(err));
        });
      });
    }
    this.checkInRecords = [];
  }

  // ✅ 月度报告功能新增：取出"指定年月"内的所有打卡记录（参数化，方便同时算本月和上月）
  getRecordsForMonth(year: number, month: number): CheckInRecord[] {
    return this.checkInRecords.filter((r: CheckInRecord) => {
      let d = new Date(r.date);
      return d.getFullYear() === year && (d.getMonth() + 1) === month;
    });
  }

  // ✅ 月度报告功能新增：汇总"指定年月"的次数 / 总花费 / 平均耗时 / 最常去的店铺
  getSummaryForMonth(year: number, month: number): MonthSummary {
    let records = this.getRecordsForMonth(year, month);
    let totalCost = 0;
    let totalWait = 0;
    let shopCountMap: Map<string, number> = new Map();
    records.forEach((r: CheckInRecord) => {
      totalCost += r.cost;
      totalWait += r.waitTime;
      shopCountMap.set(r.shopName, (shopCountMap.get(r.shopName) || 0) + 1);
    });
    let topShop = '';
    let topShopCount = 0;
    shopCountMap.forEach((count: number, name: string) => {
      if (count > topShopCount) { topShopCount = count; topShop = name; }
    });
    let summary: MonthSummary = {
      count: records.length,
      totalCost: totalCost,
      avgWait: records.length > 0 ? Math.round(totalWait / records.length) : 0,
      topShop: topShop,
      topShopCount: topShopCount
    };
    return summary;
  }

  // 取出当前正在查看的月份的记录 / 汇总（内部委托给参数化版本，保持调用方式不变）
  getMonthRecords(): CheckInRecord[] {
    return this.getRecordsForMonth(this.reportYear, this.reportMonth);
  }

  getMonthSummary(): MonthSummary {
    return this.getSummaryForMonth(this.reportYear, this.reportMonth);
  }

  // ✅ 月度报告功能新增：上一个月的汇总，用于"环比"对比
  getPrevMonthSummary(): MonthSummary {
    let prevMonth = this.reportMonth - 1;
    let prevYear = this.reportYear;
    if (prevMonth < 1) { prevMonth = 12; prevYear -= 1; }
    return this.getSummaryForMonth(prevYear, prevMonth);
  }

  // ✅ 月度报告功能新增：把"本月 vs 上月"的差异拼成一句话文案
  getMonthOverMonthText(): string {
    let cur = this.getMonthSummary();
    let prev = this.getPrevMonthSummary();
    let countDiff = cur.count - prev.count;
    let costDiff = cur.totalCost - prev.totalCost;
    let countArrow = countDiff > 0 ? '↑' : (countDiff < 0 ? '↓' : '→');
    let costArrow = costDiff > 0 ? '↑' : (costDiff < 0 ? '↓' : '→');
    return `较上月：打卡 ${countArrow}${Math.abs(countDiff)}次 · 花费 ${costArrow}¥${Math.abs(costDiff)}`;
  }

  // ✅ 月度报告功能新增：本月单次消费最高的那条记录的店铺名 / 金额
  getMaxSingleCostShopName(): string {
    let records = this.getMonthRecords();
    if (records.length === 0) { return ''; }
    let max = records[0];
    records.forEach((r: CheckInRecord) => { if (r.cost > max.cost) { max = r; } });
    return max.shopName;
  }

  getMaxSingleCost(): number {
    let records = this.getMonthRecords();
    if (records.length === 0) { return 0; }
    let max = records[0];
    records.forEach((r: CheckInRecord) => { if (r.cost > max.cost) { max = r; } });
    return max.cost;
  }

  // ✅ 月度报告功能新增：按店铺类型（吃食堂/出去吃/点外卖/吃泡面）汇总当月花费分布，按花费从高到低排序
  getTypeBreakdown(): TypeBreakdownItem[] {
    let records = this.getMonthRecords();
    let map: Map<string, number> = new Map();
    records.forEach((r: CheckInRecord) => {
      let type = r.shopType || '未知';
      map.set(type, (map.get(type) || 0) + r.cost);
    });
    let result: TypeBreakdownItem[] = [];
    map.forEach((cost: number, type: string) => {
      result.push({ type: type, cost: cost });
    });
    result.sort((a: TypeBreakdownItem, b: TypeBreakdownItem) => b.cost - a.cost);
    return result;
  }

  // ✅ 月度报告功能新增：给"按类型分布"的色块按顺序配色
  getTypeColor(idx: number): string {
    let colors: string[] = ['#FF7A45', '#FFD666', '#36CFC9', '#9254DE', '#F759AB'];
    return colors[idx % colors.length];
  }

  // ✅ 月度报告功能新增：按"第几周"汇总当月花费，用于简易柱状图（最多按 5 周划分）
  getWeeklyCosts(): number[] {
    let records = this.getMonthRecords();
    let weeks: number[] = [0, 0, 0, 0, 0];
    records.forEach((r: CheckInRecord) => {
      let day = new Date(r.date).getDate();
      let weekIndex = Math.min(4, Math.floor((day - 1) / 7));
      weeks[weekIndex] += r.cost;
    });
    return weeks;
  }

  // ✅ 月度报告功能新增：取当月每周花费里的最大值，用于计算柱状图的相对高度
  getMaxWeeklyCost(): number {
    let weeks = this.getWeeklyCosts();
    let max = 0;
    weeks.forEach((w: number) => { if (w > max) { max = w; } });
    return max;
  }

  // ✅ 月度报告功能新增：切换报告月份（delta 为 -1 上一月 / +1 下一月），自动处理跨年
  shiftReportMonth(delta: number): void {
    let newMonth = this.reportMonth + delta;
    let newYear = this.reportYear;
    if (newMonth > 12) { newMonth = 1; newYear += 1; }
    if (newMonth < 1) { newMonth = 12; newYear -= 1; }
    this.reportYear = newYear;
    this.reportMonth = newMonth;
  }

  // ✅ 月度报告功能新增：判断当前查看的月份是否已经是本月（用于禁用"下一月"按钮，不能查看未来）
  isCurrentOrFutureMonth(): boolean {
    let now = new Date();
    if (this.reportYear > now.getFullYear()) { return true; }
    if (this.reportYear === now.getFullYear() && this.reportMonth >= (now.getMonth() + 1)) { return true; }
    return false;
  }

  @StorageLink('checkInRecords') checkInRecords: CheckInRecord[] = [];
  build() {
    GridRow({
      breakpoints: { value: ['320vp', '600vp', '840vp'] }
    }) {
      GridCol({ span: 12 }) {
        if (this.currentBreakpoint === 'xs' || this.currentBreakpoint === 'sm') {
          Column() {
            Column() { this.MagazineDashboard() }.width('100%').layoutWeight(this.topPanelWeight).clip(true)
            Column() { this.DataGridPanel() }.width('100%').layoutWeight(this.bottomPanelWeight).clip(true)
          }.width('100%').height('100%')
        } else {
          Row() {
            Column() { this.MagazineDashboard() }.width('40%').height('100%').clip(true)
            Column() { this.DataGridPanel() }.width('60%').height('100%').clip(true)
          }.width('100%').height('100%')
        }
      }
    }
    .onBreakpointChange((breakpoint: string) => { this.currentBreakpoint = breakpoint; })
    .width('100%').height('100%')
    .bindSheet($$this.isShowSheet, this.FormSheet(), { height: SheetSize.LARGE })
  }
}
