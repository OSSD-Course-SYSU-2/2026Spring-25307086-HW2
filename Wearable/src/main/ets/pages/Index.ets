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
}

// 🌟 专门为鸿蒙严格模式增加的类，解决对象字面量红线报错
class LotteryItem {
  shop: Shop;
  tickets: number;

  constructor(shop: Shop, tickets: number) {
    this.shop = shop;
    this.tickets = tickets;
  }
}

const defaultShops: Shop[] = [
  { name: '松涛园一楼自选', type: '吃食堂', level: '夯', score: 5, busyLevel: 2, avgCost: 15, history: [10, 15], lat: 23.096521, lng: 113.298412 },
  { name: '松涛园三楼三杯鸡', type: '吃食堂', level: '夯', score: 5, busyLevel: 3, avgCost: 18, history: [15, 20], lat: 23.096521, lng: 113.298412 },
  { name: '学一食堂大锅菜', type: '吃食堂', level: 'NPC', score: 3, busyLevel: 3, avgCost: 12, history: [15, 20], lat: 23.093150, lng: 113.291780 },
  { name: '学一负一楼拉面', type: '吃食堂', level: '人上人', score: 4, busyLevel: 2, avgCost: 13, history: [8, 12], lat: 23.093150, lng: 113.291780 },
  { name: '学五烧腊拼盘', type: '吃食堂', level: '人上人', score: 4, busyLevel: 3, avgCost: 16, history: [15, 25], lat: 23.094000, lng: 113.295000 },
  { name: '西北风味大盘鸡', type: '吃食堂', level: '顶级', score: 5, busyLevel: 2, avgCost: 16, history: [10, 15], lat: 23.094100, lng: 113.295600 },
  { name: '五月餐厅', type: '吃食堂', level: '人上人', score: 4, busyLevel: 2, avgCost: 20, history: [12, 18], lat: 23.094300, lng: 113.295700 },
  { name: '南门口潮汕牛肉火锅', type: '出去吃', level: '夯', score: 5, busyLevel: 3, avgCost: 85, history: [30, 45], lat: 23.088210, lng: 113.296450 },
  { name: '客村星光城烤肉', type: '出去吃', level: '顶级', score: 5, busyLevel: 1, avgCost: 150, history: [20, 30], lat: 23.099100, lng: 113.315000 },
  { name: '下渡路遇见小面', type: '出去吃', level: '人上人', score: 4, busyLevel: 2, avgCost: 25, history: [10, 20], lat: 23.096800, lng: 113.305200 },
  { name: '新港西路萨莉亚', type: '出去吃', level: '夯', score: 5, busyLevel: 2, avgCost: 35, history: [15, 25], lat: 23.098500, lng: 113.292100 },
  { name: '瑞幸咖啡', type: '点外卖', level: '夯', score: 5, busyLevel: 2, avgCost: 16, history: [10, 15], lat: 23.094500, lng: 113.299100 },
  { name: '小北门东北大板烧烤', type: '点外卖', level: '顶级', score: 5, busyLevel: 3, avgCost: 55, history: [30, 40], lat: 23.095400, lng: 113.310200 },
  { name: '尊宝比萨', type: '点外卖', level: '夯', score: 4, busyLevel: 2, avgCost: 40, history: [30, 40], lat: 23.095400, lng: 113.310200 },
  { name: '汤达人豚骨拉面', type: '吃泡面', level: '顶级', score: 5, busyLevel: 1, avgCost: 6, history: [3], lat: 23.097500, lng: 113.299000 },
  { name: '三养火鸡面', type: '吃泡面', level: '人上人', score: 4, busyLevel: 1, avgCost: 10, history: [5], lat: 23.097500, lng: 113.299000 }
];

@Entry
@Component
struct WearableIndex {
  @State resultText: string = '吃点啥？';
  @State resultSubText: string = '感知系统已就绪';
  @State isRolling: boolean = false;

  @State currentBudget: number = 80;
  @State currentPreference: number = 0;
  private prefLabels: string[] = ['综合最优', '极度省钱', '效率至上', '美味优先', '距离最近'];
  private prefIcons: string[] = ['🌟', '💰', '⚡', '😋', '📍'];

  @State showPreference: boolean = false;

  @State predictedTotalTime: number = 0;
  @State timeColor: string = '#69F0AE';

  @State isRainy: boolean = false;
  private baseLat: number = 23.093500;
  private baseLng: number = 113.294000;

  private shops: Shop[] = [];

  aboutToAppear(): void {
    this.isRainy = Math.random() > 0.7;
    this.shops = defaultShops.map((shop: Shop) => {
      let lat = shop.lat || this.baseLat;
      let lng = shop.lng || this.baseLng;
      let dist = this.calculateDistance(this.baseLat, this.baseLng, lat, lng);
      shop.rawDistance = dist;
      return shop;
    });
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

  predictWaitTime(shop: Shop): number {
    if (shop.type === '吃泡面') return Math.floor(Math.random() * 3) + 3;
    if (shop.type === '点外卖') {
      let baseTime: number = Math.floor(Math.random() * 25) + 25;
      return this.isRainy ? baseTime + 20 : baseTime;
    }

    const history: number[] = shop.history || [10, 15];
    let sum: number = 0;
    history.forEach((val: number) => { sum += val; });
    const avg: number = sum / history.length;

    const now = new Date();
    const hour: number = now.getHours();
    const minutes: number = now.getMinutes();

    let timeFactor: number = 1.0;
    if (hour >= 15 && hour < 17) {
      timeFactor = 0.3;
    } else if (hour >= 11 && hour <= 13) {
      timeFactor = 1.8;
    } else if ((hour === 18 && minutes >= 10) || (hour === 19 && minutes <= 30)) {
      timeFactor = 2.5;
    } else if (hour === 18 && minutes < 10) {
      timeFactor = 1.5;
    }

    const busyFactorMap: number[] = [0.8, 1.2, 2.2];
    const shopBusyLevel: number = shop.busyLevel || 2;
    const busyFactor: number = busyFactorMap[shopBusyLevel - 1];

    return Math.ceil(avg * busyFactor * timeFactor);
  }

  rollFood(): void {
    if (this.isRolling) return;

    let validShops = this.shops.filter((s: Shop) => Number(s.avgCost) <= this.currentBudget);
    if (validShops.length === 0) {
      this.resultText = '喝西北风 🌬️';
      this.resultSubText = '预算太低啦！';
      this.predictedTotalTime = 0;
      return;
    }

    this.isRolling = true;
    let availableTypes = Array.from(new Set(validShops.map(s => s.type)));
    let count: number = 0;

    let intervalId: number = setInterval(() => {
      this.resultText = validShops[Math.floor(Math.random() * validShops.length)].name;
      count++;

      if (count > 12) {
        clearInterval(intervalId);

        let finalType: string = availableTypes[Math.floor(Math.random() * availableTypes.length)];
        let weatherFactor: number = 1.0;
        if (this.isRainy && finalType === '出去吃') weatherFactor = 0.2;
        if (this.isRainy && (finalType === '点外卖' || finalType === '吃泡面')) weatherFactor = 2.0;

        let finalAvailableShops: Shop[] = validShops.filter(s => s.type === finalType);

        let lotteryPool: LotteryItem[] = [];
        let totalTickets: number = 0;

        finalAvailableShops.forEach((shop: Shop) => {
          let finalWeight: number = 1;
          let waitTime: number = this.predictWaitTime(shop);

          // 🌟 修复关键语法错误点！
          let walkTime: number = Math.ceil((shop.rawDistance || 0) / 80);
          let totalTime: number = shop.type === '点外卖' ? Math.max(waitTime, walkTime) : waitTime + walkTime;

          switch (this.currentPreference) {
            case 0:
              finalWeight = Math.max(1, (shop.score || 3) - ((shop.busyLevel || 2) - 1));
              break;
            case 1:
              finalWeight = Math.max(1, 10 - Math.floor(shop.avgCost / 10));
              break;
            case 2:
              finalWeight = totalTime < 15 ? 10 : Math.max(1, 8 - Math.floor(totalTime / 5));
              break;
            case 3:
              finalWeight = (shop.score || 3) >= 4 ? shop.score * 3 : 1;
              break;
            case 4:
              let dist = shop.rawDistance || 0;
              finalWeight = dist < 200 ? 10 : Math.max(1, 10 - Math.floor(dist / 200));
              break;
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
        this.resultSubText = `💰￥${bestShop.avgCost} | ${bestShop.level}`;

        let finalWait = this.predictWaitTime(bestShop);

        // 🌟 修复关键语法错误点！
        let finalWalk: number = Math.ceil((bestShop.rawDistance || 0) / 80);
        this.predictedTotalTime = bestShop.type === '点外卖' ? Math.max(finalWait, finalWalk) : finalWait + finalWalk;
        this.timeColor = this.predictedTotalTime > 30 ? '#FF5252' : '#69F0AE';

        this.isRolling = false;
      }
    }, 100);
  }

  build() {
    Stack() {
      if (!this.showPreference) {
        Column({ space: 4 }) {
          Row() {
            Text(this.isRainy ? '🌧️ 雨天模式' : '🌤️ 晴天模式')
              .fontSize(10)
              .fontColor(Color.White)
              .backgroundColor(this.isRainy ? '#007DFF' : '#FF9800')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(10)
          }.margin({ top: 10, bottom: 5 })

          Text(this.resultText)
            .fontSize(16)
            .fontWeight(FontWeight.Bolder)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .height(40)

          Text(this.resultSubText)
            .fontSize(11)
            .fontColor('#AAAAAA')

          if (this.predictedTotalTime > 0) {
            Text(`预估总耗时: ${this.predictedTotalTime} 分钟`)
              .fontSize(11)
              .fontColor(this.timeColor)
              .margin({ top: 2 })
          } else {
            Text(' ').fontSize(11).margin({ top: 2 })
          }

          Row() {
            Text(`￥${this.currentBudget}`)
              .fontSize(11)
              .fontColor('#AAAAAA')
              .width('20%')
              .textAlign(TextAlign.End)

            Slider({
              value: this.currentBudget,
              min: 10, max: 150, step: 5,
              style: SliderStyle.OutSet
            })
              .width('75%')
              .blockColor('#007DFF')
              .trackColor('#333333')
              .selectedColor('#007DFF')
              .onChange((value: number) => { this.currentBudget = Math.floor(value); })
          }
          .width('95%')
          .margin({ top: 2 })
          .justifyContent(FlexAlign.Center)

          Button(this.isRolling ? '盲盒开奖中...' : '🥢 开始决定')
            .width('75%')
            .height(34)
            .backgroundColor('#007DFF')
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
            .onClick(() => { this.rollFood(); })

          Row({ space: 4 }) {
            Text(this.prefIcons[this.currentPreference]).fontSize(12)
            Text(this.prefLabels[this.currentPreference] + ' ⚙️')
              .fontSize(11)
              .fontColor('#4FC3F7')
          }
          .margin({ top: 4 })
          .onClick(() => { this.showPreference = true; })
        }
        .width('100%')
        .height('100%')
        .padding(8)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.Black)
      }

      if (this.showPreference) {
        Column({ space: 4 }) {
          Text('选择决策偏好')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 15, bottom: 5 })

          List({ space: 4 }) {
            ForEach(this.prefLabels, (label: string, index: number) => {
              ListItem() {
                Row() {
                  Text(this.prefIcons[index]).fontSize(14)
                  Text(label)
                    .fontSize(13)
                    .fontColor(this.currentPreference === index ? Color.White : '#AAAAAA')
                    .fontWeight(this.currentPreference === index ? FontWeight.Bold : FontWeight.Normal)
                }
                .width('100%')
                .padding(8)
                .backgroundColor(this.currentPreference === index ? '#007DFF' : '#222222')
                .borderRadius(12)
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                  this.currentPreference = index;
                  this.showPreference = false;
                })
              }
            }, (item: string) => item)
          }
          .width('75%')
          .height('60%')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.Black)
      }
    }
    .width('100%')
    .height('100%')
  }
}