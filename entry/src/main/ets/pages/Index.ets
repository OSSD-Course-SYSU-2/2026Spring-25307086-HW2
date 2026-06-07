import { curves } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { geoLocationManager } from '@kit.LocationKit';

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

// 🌟 随机美食壁纸引擎 (用于给新录入的店或者缺失图片的店随机配图)
const fallbackImages: string[] = [
  'https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80',
  'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&q=80',
  'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=600&q=80',
  'https://images.unsplash.com/photo-1564834724105-918b73d1b9e0?w=600&q=80',
  'https://images.unsplash.com/photo-1605220645990-21f83c1ce610?w=600&q=80',
  'https://images.unsplash.com/photo-1552611052-33e04de081de?w=600&q=80',
  'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&q=80',
  'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&q=80',
  'https://images.unsplash.com/photo-1484723091781-41dbd4304ffb?w=600&q=80',
  'https://images.unsplash.com/photo-1504669521191-23b006bd16b8?w=600&q=80'
];

function getRandomBg(): string {
  return fallbackImages[Math.floor(Math.random() * fallbackImages.length)];
}

// 🌟 终极扩充版：30家无敌美食矩阵
const defaultShops: Shop[] = [
  { name: '松涛园一楼自选', type: '吃食堂', level: '夯', score: 5, busyLevel: 2, avgCost: 15, history: [10, 15], bgImg: fallbackImages[0] },
  { name: '松涛园三楼三杯鸡', type: '吃食堂', level: '顶级', score: 5, busyLevel: 3, avgCost: 18, history: [15, 20], bgImg: fallbackImages[2] },
  { name: '松涛园二楼烧腊', type: '吃食堂', level: '人上人', score: 4, busyLevel: 2, avgCost: 16, history: [10, 15], bgImg: fallbackImages[7] },
  { name: '学一食堂大锅菜', type: '吃食堂', level: 'NPC', score: 3, busyLevel: 3, avgCost: 12, history: [15, 20], bgImg: fallbackImages[1] },
  { name: '学一负一拉面饺子', type: '吃食堂', level: '人上人', score: 4, busyLevel: 2, avgCost: 13, history: [8, 12], bgImg: fallbackImages[5] },
  { name: '学五铁板烧', type: '吃食堂', level: '夯', score: 5, busyLevel: 3, avgCost: 16, history: [15, 25], bgImg: fallbackImages[3] },
  { name: '学五清真大盘鸡', type: '吃食堂', level: '顶级', score: 5, busyLevel: 2, avgCost: 18, history: [10, 15], bgImg: fallbackImages[4] },
  { name: '春晖园风味餐', type: '吃食堂', level: '人上人', score: 4, busyLevel: 2, avgCost: 14, history: [8, 12], bgImg: fallbackImages[6] },
  { name: '南草坪高级餐厅', type: '出去吃', level: '顶级', score: 5, busyLevel: 1, avgCost: 45, history: [5, 10], bgImg: fallbackImages[8] },
  { name: '南门口潮汕牛肉火锅', type: '出去吃', level: '夯', score: 5, busyLevel: 3, avgCost: 85, history: [30, 45], bgImg: fallbackImages[4] },
  { name: '客村星光城烤肉', type: '出去吃', level: '顶级', score: 5, busyLevel: 1, avgCost: 150, history: [20, 30], bgImg: fallbackImages[8] },
  { name: '客村海底捞', type: '出去吃', level: '夯', score: 5, busyLevel: 3, avgCost: 120, history: [40, 60], bgImg: fallbackImages[2] },
  { name: '下渡路遇见小面', type: '出去吃', level: '人上人', score: 4, busyLevel: 2, avgCost: 25, history: [10, 20], bgImg: fallbackImages[6] },
  { name: '新港西路萨莉亚', type: '出去吃', level: '夯', score: 5, busyLevel: 2, avgCost: 35, history: [15, 25], bgImg: fallbackImages[7] },
  { name: '鹭江点都德茶楼', type: '出去吃', level: '顶级', score: 5, busyLevel: 3, avgCost: 90, history: [30, 50], bgImg: fallbackImages[8] },
  { name: '琶醍江景精酿', type: '出去吃', level: '顶级', score: 5, busyLevel: 1, avgCost: 160, history: [10, 20], bgImg: fallbackImages[9] },
  { name: '瑞幸咖啡(中大店)', type: '点外卖', level: '夯', score: 5, busyLevel: 2, avgCost: 16, history: [10, 15], bgImg: fallbackImages[0] },
  { name: '喜茶(丽影广场店)', type: '点外卖', level: '顶级', score: 5, busyLevel: 3, avgCost: 25, history: [20, 30], bgImg: fallbackImages[3] },
  { name: '麦当劳(新港西店)', type: '点外卖', level: '人上人', score: 4, busyLevel: 1, avgCost: 35, history: [20, 30], bgImg: fallbackImages[5] },
  { name: '肯德基(客村店)', type: '点外卖', level: '夯', score: 4, busyLevel: 2, avgCost: 38, history: [20, 30], bgImg: fallbackImages[4] },
  { name: '尊宝比萨(鹭江店)', type: '点外卖', level: 'NPC', score: 3, busyLevel: 2, avgCost: 40, history: [30, 40], bgImg: fallbackImages[7] },
  { name: '塔汀简餐', type: '点外卖', level: '人上人', score: 4, busyLevel: 1, avgCost: 45, history: [15, 25], bgImg: fallbackImages[6] },
  { name: '华莱士(喷射战士)', type: '点外卖', level: '拉完了', score: 1, busyLevel: 1, avgCost: 18, history: [10, 20], bgImg: fallbackImages[1] },
  { name: '小北门东北大板烧烤', type: '点外卖', level: '顶级', score: 5, busyLevel: 3, avgCost: 55, history: [30, 40], bgImg: fallbackImages[8] },
  { name: '白象老母鸡汤面', type: '吃泡面', level: '顶级', score: 5, busyLevel: 1, avgCost: 5, history: [3], bgImg: fallbackImages[0] },
  { name: '康师傅红烧牛肉面', type: '吃泡面', level: 'NPC', score: 3, busyLevel: 1, avgCost: 4, history: [3], bgImg: fallbackImages[5] },
  { name: '满汉大餐葱烧牛肉', type: '吃泡面', level: '人上人', score: 4, busyLevel: 1, avgCost: 15, history: [5], bgImg: fallbackImages[6] },
  { name: '汤达人日式豚骨', type: '吃泡面', level: '顶级', score: 5, busyLevel: 1, avgCost: 6, history: [3], bgImg: fallbackImages[0] },
  { name: '罗森便利店便当', type: '吃泡面', level: '夯', score: 4, busyLevel: 1, avgCost: 18, history: [2, 5], bgImg: fallbackImages[1] },
  { name: '7-11车仔面+鱼蛋', type: '吃泡面', level: '人上人', score: 4, busyLevel: 1, avgCost: 12, history: [2, 5], bgImg: fallbackImages[6] }
];

PersistentStorage.persistProp('MyShopsMagazine_V8_Images', JSON.stringify(defaultShops));

@Entry
@Component
struct Index {
  @State resultText: string = '饥饿感知系统';
  @State resultSubText: string = '正在连接美食矩阵...';
  @State resultCategory: string = '';
  @State isRolling: boolean = false;
  @State textScale: number = 1.0;

  @State currentPreference: number = 0;
  @State isRainy: boolean = false;
  @State weatherDescription: string = '获取天候中...';

  @State currentBudget: number = 100;
  @State isBudgetExpanded: boolean = false;
  @State predictedQueueTime: number = 0;
  @State predictedWalkTime: number = 0;
  @State predictedTotalTime: number = 0;
  @State showReroll: boolean = false;
  @State lastWaitTimeRecord: number = 999;

  // 🌟 修复：初始状态直接给一张随机壁纸，拒绝黑屏！
  @State displayImage: string = getRandomBg();

  @StorageLink('MyShopsMagazine_V8_Images') shopsJson: string = '';
  @State shops: Shop[] = [];

  @State currentBreakpoint: string = 'sm';

  @State isShowSheet: boolean = false;
  @State editingIndex: number = -1;

  @State batchInputText: string = '';
  @State inputName: string = '';
  @State inputType: string = '吃食堂';
  @State inputCost: string = '20';
  @State inputLat: string = '';
  @State inputLng: string = '';
  @State selectedLevelIndex: number = 4;
  @State inputBusyLevel: number = 2;

  private apiKey: string = 'YOUR_QWEATHER_API_KEY';

  aboutToAppear(): void {
    try {
      let parsed: Shop[] = JSON.parse(this.shopsJson) as Shop[];
      if (parsed && parsed.length > 0) {
        // 🌟 修复：自动扫描之前保存的数据，如果没图片，立刻补上一张随机图片
        this.shops = parsed.map((s: Shop) => {
          if (!s.bgImg) { s.bgImg = getRandomBg(); }
          return s;
        });
      } else {
        this.shops = defaultShops;
      }
    } catch {
      this.shops = defaultShops;
    }
    setTimeout(() => { this.fetchEnvironmentData(); }, 500);
  }

  calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R: number = 6371e3;
    const dLat: number = (lat2 - lat1) * Math.PI / 180;
    const dLon: number = (lon2 - lon1) * Math.PI / 180;
    const a: number = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c: number = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Math.floor(R * c);
  }

  formatDistance(meters: number): string {
    return meters < 1000 ? `${meters}米` : `${(meters / 1000).toFixed(1)}公里`;
  }

  async fetchEnvironmentData(): Promise<void> {
    let longitude: number = 113.294000;
    let latitude: number = 23.093500;
    try {
      let location = await geoLocationManager.getCurrentLocation();
      longitude = location.longitude;
      latitude = location.latitude;
    } catch {
      console.warn('GPS获取失败，使用基准位置');
    }

    let updatedShops = this.shops.map((shop: Shop) => {
      let shopLat = shop.lat || 0;
      let shopLng = shop.lng || 0;

      if (shopLat === 0 || shopLng === 0) {
        let latOffset = (Math.random() - 0.5) * 0.005;
        let lngOffset = (Math.random() - 0.5) * 0.005;
        if (shop.type === '吃泡面') { shopLat = 23.097500; shopLng = 113.299000; }
        else if (shop.type === '点外卖') { shopLat = 23.101800; shopLng = 113.296500; }
        else if (shop.type === '吃食堂') { shopLat = 23.094500 + latOffset; shopLng = 113.292500 + lngOffset; }
        else { shopLat = 23.090000 + (latOffset * 2); shopLng = 113.300000 + (lngOffset * 2); }
        shop.lat = shopLat;
        shop.lng = shopLng;
      }

      let dist = this.calculateDistance(latitude, longitude, shopLat, shopLng);
      shop.rawDistance = dist;
      shop.distanceStr = this.formatDistance(dist);
      return shop;
    });
    this.shops = [...updatedShops];

    let httpRequest = http.createHttp();
    let url = `https://devapi.qweather.com/v7/weather/now?location=${longitude},${latitude}&key=${this.apiKey}`;
    try {
      let data = await httpRequest.request(url, { method: http.RequestMethod.GET });
      if (data.responseCode === 200) {
        let result: WeatherResponse = JSON.parse(data.result as string) as WeatherResponse;
        this.isRainy = result.now.text.includes('雨');
        this.weatherDescription = result.now.text;
      }
    } catch {
      this.weatherDescription = '晴朗 (离线模式)';
    } finally {
      httpRequest.destroy();
    }
  }

  predictWaitTime(shop: Shop): number {
    if (shop.type === '吃泡面') return Math.floor(Math.random() * 3) + 3;
    if (shop.type === '点外卖') return this.isRainy ? 45 : 25;

    const history = shop.history || [10, 15];
    const avg = history.reduce((a: number, b: number) => a + b, 0) / history.length;
    const now = new Date();
    const hour = now.getHours();
    const minutes = now.getMinutes();
    const day = now.getDay();

    let timeFactor = 1.0;
    if (day === 3 && hour === 16) timeFactor = 0.3;
    else if (hour >= 11 && hour <= 13) timeFactor = 1.8;
    else if (hour === 18 && minutes >= 10) timeFactor = 2.5;

    const busyFactorMap = [0.8, 1.2, 2.2];
    return Math.ceil(avg * busyFactorMap[(shop.busyLevel || 2) - 1] * timeFactor);
  }

  rollFood(): void {
    if (this.isRolling) return;

    let validShops = this.shops.filter((s: Shop) => {
      return this.isBudgetExpanded ? Number(s.avgCost) <= Number(this.currentBudget) : true;
    });

    if (validShops.length === 0) {
      this.resultText = '预算不足';
      this.resultCategory = '🚫 严重超支';
      this.resultSubText = '当前预算下连泡面都吃不起，请提高预算！';
      this.displayImage = getRandomBg(); // 回归一张默认壁纸
      return;
    }

    this.lastWaitTimeRecord = this.showReroll ? this.predictedTotalTime : 999;
    this.isRolling = true;
    this.showReroll = false;
    this.resultCategory = '';

    let availableTypes = Array.from(new Set(validShops.map((s: Shop) => s.type)));
    let count = 0;

    let intervalId = setInterval(() => {
      let tempShop = validShops[Math.floor(Math.random() * validShops.length)];
      this.resultText = tempShop.name;
      this.displayImage = tempShop.bgImg || getRandomBg();
      count++;

      if (count > 15) {
        clearInterval(intervalId);

        let finalType = availableTypes[Math.floor(Math.random() * availableTypes.length)];
        let weatherFactor = 1.0;
        if (this.isRainy && finalType === '出去吃') weatherFactor = 0.2;
        if (this.isRainy && (finalType === '点外卖' || finalType === '吃泡面')) weatherFactor = 2.0;

        let finalAvailableShops = validShops.filter((s: Shop) => s.type === finalType);
        let lotteryPool: LotteryItem[] = [];
        let totalTickets = 0;

        finalAvailableShops.forEach((shop: Shop) => {
          let finalWeight = 1;
          let waitTime = this.predictWaitTime(shop);
          let walkTime = Math.ceil((shop.rawDistance || 0) / 80);
          let totalTime = shop.type === '点外卖' ? Math.max(waitTime, walkTime) : waitTime + walkTime;

          switch (this.currentPreference) {
            case 0: finalWeight = Math.max(1, (shop.score || 3) - ((shop.busyLevel || 2) - 1)); break;
            case 1: finalWeight = Math.max(1, 10 - Math.floor((shop.avgCost || 20) / 10)); break;
            case 2: finalWeight = totalTime < 15 ? 10 : Math.max(1, 8 - Math.floor(totalTime / 5)); break;
            case 3: finalWeight = (shop.score || 3) >= 4 ? (shop.score || 3) * 3 : 1; break;
            case 4: finalWeight = (shop.rawDistance || 0) < 200 ? 10 : Math.max(1, 10 - Math.floor((shop.rawDistance || 0) / 200)); break;
          }

          let tickets = Math.max(10, Math.floor(finalWeight * 10 * weatherFactor));
          lotteryPool.push(new LotteryItem(shop, tickets));
          totalTickets += tickets;
        });

        let winningTicket = Math.floor(Math.random() * totalTickets);
        let currentTicketCount = 0;
        let bestShop = finalAvailableShops[0];

        for (let i = 0; i < lotteryPool.length; i++) {
          currentTicketCount += lotteryPool[i].tickets;
          if (currentTicketCount > winningTicket) {
            bestShop = lotteryPool[i].shop;
            break;
          }
        }

        this.resultText = bestShop.name;
        this.resultCategory = `${finalType}`;
        let locLabel = bestShop.type === '吃泡面' ? ' (宿舍)' : (bestShop.type === '点外卖' ? ' (外卖柜)' : '');
        this.resultSubText = `预估人均：￥${bestShop.avgCost} | 评级：${bestShop.level} | 📍 距离: ${bestShop.distanceStr}${locLabel}`;
        this.displayImage = bestShop.bgImg || getRandomBg();

        let finalQueueTime = this.predictWaitTime(bestShop);
        let finalWalkTime = Math.ceil((bestShop.rawDistance || 0) / 80);
        let newTotalTime = bestShop.type === '点外卖' ? Math.max(finalQueueTime, finalWalkTime) : finalQueueTime + finalWalkTime;

        if (this.lastWaitTimeRecord < 999 && newTotalTime > this.lastWaitTimeRecord) {
          newTotalTime = this.lastWaitTimeRecord;
          if (bestShop.type === '点外卖') { finalQueueTime = newTotalTime; }
          else { finalQueueTime = Math.max(0, newTotalTime - finalWalkTime); }
          newTotalTime = bestShop.type === '点外卖' ? Math.max(finalQueueTime, finalWalkTime) : finalQueueTime + finalWalkTime;
        }

        this.predictedQueueTime = finalQueueTime;
        this.predictedWalkTime = finalWalkTime;
        this.predictedTotalTime = newTotalTime;

        if (this.predictedTotalTime > 30) { this.showReroll = true; }

        this.isRolling = false;
        this.getUIContext().animateTo({ curve: curves.springMotion() }, () => { this.textScale = 1.1; });
        setTimeout(() => { this.textScale = 1.0; }, 300);
      }
    }, 100);
  }

  // ==========================================
  // 📚 瀑布流卡片组件
  // ==========================================
  @Builder MagazineCardBuilder(item: Shop, index: number) {
    Stack({ alignContent: Alignment.Bottom }) {
      Image(item.bgImg || getRandomBg())
        .width('100%').height('100%').objectFit(ImageFit.Cover).borderRadius(16)

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
      const levelArr = ['拉完了', 'NPC', '人上人', '顶级', '夯'];
      this.selectedLevelIndex = levelArr.indexOf(item.level) !== -1 ? levelArr.indexOf(item.level) : 4;
      this.inputBusyLevel = item.busyLevel;
      this.isShowSheet = true;
    })
  }

  // ==========================================
  // 🎛️ 终极固定主控台（无滑动、完美弹性布局）
  // ==========================================
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
          Text(this.isRainy ? '🌧️ 降雨' : '🌤️ 晴朗').fontSize(12).fontColor(Color.White).fontWeight(FontWeight.Bold)
          Text('|').fontColor('rgba(255,255,255,0.3)')
          Text(`实时天候: ${this.weatherDescription}`).fontSize(12).fontColor(Color.White)
        }

        Blank() // 弹性留白

        Column({ space: 8 }) {
          if (this.resultCategory !== '') {
            Text(this.resultCategory).fontSize(14).fontColor('#FFD700').fontWeight(FontWeight.Medium)
          }
          Text(this.resultText)
            .fontSize(this.currentBreakpoint === 'sm' ? (this.resultText.length > 8 ? 24 : 32) : (this.resultText.length > 8 ? 28 : 38))
            .fontWeight(FontWeight.Bolder).fontColor(Color.White)
            .scale({ x: this.textScale, y: this.textScale }).textAlign(TextAlign.Center)

          Text(this.resultSubText).fontSize(13).fontColor('rgba(255,255,255,0.8)').textAlign(TextAlign.Center).padding({ left: 10, right: 10 })

          if (this.predictedTotalTime > 0) {
            Column({ space: 6 }) {
              Row({ space: 15 }) {
                Text(`🚶 步行: ${this.predictedWalkTime} 分钟`).fontSize(12).fontColor('rgba(255,255,255,0.8)')
                Text(`⏳ 等候: ${this.predictedQueueTime} 分钟`).fontSize(12).fontColor('rgba(255,255,255,0.8)')
              }
              Text(`预计总耗时: ${this.predictedTotalTime} 分钟`)
                .fontSize(15).fontColor(this.predictedTotalTime > 30 ? '#FF5252' : '#00E676').fontWeight(FontWeight.Bold)

              if (this.showReroll) {
                Button('耗时太久，重新选择').height(28).fontSize(12).backgroundColor('#D32F2F').fontColor(Color.White)
                  .margin({ top: 5 }).onClick(() => { this.rollFood(); })
              }
            }.margin({ top: 5 }).padding(10).backgroundColor('rgba(0,0,0,0.4)').borderRadius(12)
          }
        }

        Blank() // 弹性留白

        Column({ space: 10 }) {
          Text(this.isBudgetExpanded ? '收起预算设定 ▲' : '展开预算设定 ▼')
            .fontSize(12).fontColor('rgba(255,255,255,0.6)')
            .onClick(() => { this.getUIContext().animateTo({ curve: curves.springMotion() }, () => { this.isBudgetExpanded = !this.isBudgetExpanded; }); })

          if (this.isBudgetExpanded) {
            Row() {
              Text('预算上限').fontSize(12).fontColor('rgba(255,255,255,0.8)')
              Blank()
              Text(`￥${this.currentBudget}`).fontSize(20).fontColor(Color.White).fontWeight(FontWeight.Bold)
            }.width('85%')
            Slider({ value: this.currentBudget, min: 10, max: 200, step: 5, style: SliderStyle.OutSet }).onChange((v: number) => { this.currentBudget = Math.floor(v); }).width('90%').selectedColor(Color.White).trackColor('rgba(255,255,255,0.2)')
          }

          Row({ space: 6 }) {
            ForEach(['综合', '省钱', '效率', '美味', '距离'], (label: string, index: number) => {
              Text(label).layoutWeight(1).height(30).fontSize(12).textAlign(TextAlign.Center).fontWeight(FontWeight.Medium)
                .backgroundColor(this.currentPreference === index ? Color.White : 'rgba(255,255,255,0.1)')
                .fontColor(this.currentPreference === index ? Color.Black : Color.White).borderRadius(15)
                .onClick(() => { this.currentPreference = index; })
            }, (item: string) => item)
          }.width('95%')
        }.width('100%').alignItems(HorizontalAlign.Center)

        Blank() // 弹性留白

        Button(this.isRolling ? '算法运算中...' : '开始决定')
          .width('75%').height(42).fontSize(15).fontWeight(FontWeight.Bold)
          .backgroundColor(this.isRolling ? 'rgba(255,255,255,0.2)' : Color.White)
          .fontColor(this.isRolling ? Color.White : Color.Black).borderRadius(21)
          .onClick(() => { this.rollFood(); })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 10, right: 10, top: 15, bottom: 15 })
    }
    .width('100%').height('100%')
  }

  // ==========================================
  // 数据网格列表组件
  // ==========================================
  @Builder DataGridPanel() {
    Column() {
      Row() {
        Text(`美食图鉴 (${this.shops.length})`)
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333').layoutWeight(1)
        Button('+ 手工录入').height(30).fontSize(12).backgroundColor('#1A1A1A').onClick(() => { this.editingIndex = -1; this.isShowSheet = true; })
      }.width('100%').padding({ left: 20, right: 20, top: 15, bottom: 10 })

      WaterFlow() {
        ForEach(this.shops, (item: Shop, index: number) => {
          FlowItem() {
            this.MagazineCardBuilder(item, index)
          }
        }, (item: Shop, index: number) => item.name + index)
      }
      .columnsTemplate(this.currentBreakpoint === 'sm' || this.currentBreakpoint === 'xs' ? '1fr 1fr' : '1fr 1fr 1fr')
      .columnsGap(10).rowsGap(10).padding({ left: 15, right: 15, bottom: 15 }).layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor('#F5F5F7')
  }

  // ==========================================
  // 底部表单弹窗
  // ==========================================
  parseBatchInput(): void {
    if (this.batchInputText.trim() === '') return;
    let lines: string[] = this.batchInputText.split('\n');
    lines.forEach((line: string) => {
      let parts: string[] = line.split(/[ ,，-]+/);
      if (parts.length >= 2) {
        let cost = parts.length >= 3 ? Number(parts[2]) : 20;
        const newShop: Shop = {
          // 🌟 修复：导入时如果没有配图，立刻随机配一张！
          name: parts[0], type: parts[1], level: '人上人', score: 4, busyLevel: 2, avgCost: isNaN(cost) ? 20 : cost, history: [15], bgImg: getRandomBg()
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
    Tabs() {
      TabContent() {
        Column({ space: 15 }) {
          Text('智能时空矩阵批量导入').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
          TextArea({ placeholder: '格式：名称 分类 价格\n示例：\n松涛园一楼 吃食堂 15', text: this.batchInputText })
            .onChange((v: string) => this.batchInputText = v).height(140).backgroundColor('#F5F7FA').padding(10).borderRadius(8)
          Button('解析并存入中心数据库').width('100%').height(42).backgroundColor('#1A1A1A').fontColor(Color.White).fontWeight(FontWeight.Bold).borderRadius(20)
            .onClick(() => { this.parseBatchInput(); this.isShowSheet = false; })
        }.padding(20)
      }.tabBar('批量导入')

      TabContent() {
        Column({ space: 12 }) {
          Text(this.editingIndex === -1 ? '手动校准新目标' : '数据重新校准').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
          TextInput({ placeholder: '店铺名称', text: this.inputName }).onChange((v: string) => this.inputName = v).backgroundColor('#F5F7FA').borderRadius(8)

          Row({ space: 10 }) {
            TextInput({ placeholder: '人均消费 (￥)', text: this.inputCost }).type(InputType.Number).layoutWeight(1).onChange((v: string) => this.inputCost = v).backgroundColor('#F5F7FA').borderRadius(8)
            Select([{ value: '吃食堂' }, { value: '点外卖' }, { value: '出去吃' }, { value: '吃泡面' }]).value(this.inputType).onSelect((index: number, value: string) => this.inputType = value).layoutWeight(1).borderRadius(8)
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

              // 🌟 修复：录入或更新时确保有背景图！
              let finalImg = getRandomBg();
              if (this.editingIndex !== -1 && this.shops[this.editingIndex].bgImg) {
                finalImg = this.shops[this.editingIndex].bgImg;
              }

              const newShop: Shop = {
                name: this.inputName, type: this.inputType, level: ['拉完了', 'NPC', '人上人', '顶级', '夯'][this.selectedLevelIndex],
                score: this.selectedLevelIndex + 1, busyLevel: this.inputBusyLevel, avgCost: Number(this.inputCost), history: [15], bgImg: finalImg
              };
              if (this.inputLat !== '' && this.inputLng !== '') { newShop.lat = Number(this.inputLat); newShop.lng = Number(this.inputLng); }
              if (this.editingIndex === -1) { this.shops.push(newShop); } else { this.shops[this.editingIndex] = newShop; }
              this.syncDataToStorage(); this.fetchEnvironmentData(); this.isShowSheet = false;
            })
        }.padding(20)
      }.tabBar('精细录入')
    }
    .backgroundColor(Color.White).borderRadius({ topLeft: 20, topRight: 20 })
  }

  // ==========================================
  // 🌟 终极无重叠响应式布局
  // ==========================================
  build() {
    GridRow({
      breakpoints: { value: ['320vp', '600vp', '840vp'] }
    }) {
      GridCol({ span: 12 }) {
        if (this.currentBreakpoint === 'xs' || this.currentBreakpoint === 'sm') {
          // 📱 手机端：纯正上下分屏！利用 layoutWeight(1) 完美平分屏幕！
          Column() {
            Column() { this.MagazineDashboard() }.width('100%').layoutWeight(1).clip(true)
            Column() { this.DataGridPanel() }.width('100%').layoutWeight(1).clip(true)
          }.width('100%').height('100%')
        } else {
          // 💻 平板/折叠屏展开端：纯正左右布局！
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