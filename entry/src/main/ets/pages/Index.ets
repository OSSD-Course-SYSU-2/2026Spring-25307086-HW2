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
}

interface WeatherNow {
  text: string;
}

interface WeatherResponse {
  code: string;
  now: WeatherNow;
}

// 📍 康乐园高精度坐标系
const defaultShops: Shop[] = [
  { name: '松涛园焗饭', type: '吃食堂', level: '夯', score: 5, busyLevel: 2, avgCost: 15, history: [10, 15], lat: 23.096521, lng: 113.298412 },
  { name: '学一食堂大锅菜', type: '吃食堂', level: 'NPC', score: 3, busyLevel: 3, avgCost: 12, history: [15, 20], lat: 23.093150, lng: 113.291780 },
  { name: '春晖园自选餐', type: '吃食堂', level: '人上人', score: 4, busyLevel: 2, avgCost: 14, history: [8, 12], lat: 23.092340, lng: 113.297650 },
  { name: '南草坪餐厅', type: '吃食堂', level: '顶级', score: 5, busyLevel: 1, avgCost: 30, history: [5, 10], lat: 23.095120, lng: 113.296890 },

  { name: '南门口潮汕牛肉', type: '出去吃', level: '夯', score: 5, busyLevel: 3, avgCost: 85, history: [30, 45], lat: 23.088210, lng: 113.296450 },
  { name: '江边高级日料', type: '出去吃', level: '顶级', score: 5, busyLevel: 1, avgCost: 180, history: [10, 15], lat: 23.103100, lng: 113.290500 },
  { name: '下渡路遇见小面', type: '出去吃', level: '人上人', score: 4, busyLevel: 2, avgCost: 25, history: [10, 20], lat: 23.096800, lng: 113.305200 },
  { name: '新港西路萨莉亚', type: '出去吃', level: '夯', score: 5, busyLevel: 2, avgCost: 35, history: [15, 25], lat: 23.098500, lng: 113.292100 },

  { name: '瑞幸咖啡(中大店)', type: '点外卖', level: '夯', score: 5, busyLevel: 2, avgCost: 16, history: [10, 15], lat: 23.094500, lng: 113.299100 },
  { name: '麦当劳(新港西店)', type: '点外卖', level: '人上人', score: 4, busyLevel: 1, avgCost: 35, history: [20, 30], lat: 23.099800, lng: 113.295600 },
  { name: '尊宝比萨(鹭江店)', type: '点外卖', level: 'NPC', score: 3, busyLevel: 2, avgCost: 40, history: [30, 40], lat: 23.095400, lng: 113.310200 },

  { name: '白象汤好喝老母鸡汤面', type: '吃泡面', level: '顶级', score: 5, busyLevel: 1, avgCost: 5, history: [3], lat: 23.097500, lng: 113.299000 },
  { name: '康师傅红烧牛肉面', type: '吃泡面', level: 'NPC', score: 3, busyLevel: 1, avgCost: 4, history: [3], lat: 23.097500, lng: 113.299000 },
  { name: '满汉大餐葱烧牛肉', type: '吃泡面', level: '人上人', score: 4, busyLevel: 1, avgCost: 15, history: [5], lat: 23.097500, lng: 113.299000 }
];

PersistentStorage.persistProp('MyShopsData', JSON.stringify(defaultShops));

@Entry
@Component
struct Index {
  @State resultText: string = '今天吃什么？';
  @State resultSubText: string = '时空与环境感知算法已启动';
  @State resultCategory: string = '';
  @State isRolling: boolean = false;

  @State currentPreference: number = 0;
  @State isRainy: boolean = false;
  @State weatherDescription: string = '正在感知环境...';
  @State isBudgetExpanded: boolean = false;
  @State currentBudget: number = 100;

  @State predictedQueueTime: number = 0;
  @State predictedWalkTime: number = 0;
  @State predictedTotalTime: number = 0;

  @State showReroll: boolean = false;
  @State lastWaitTimeRecord: number = 999;

  @State textScale: number = 1.0;
  @State isShowSheet: boolean = false;
  @State editingIndex: number = -1;

  @State batchInputText: string = '';
  @State inputName: string = '';
  @State inputType: string = '吃食堂';
  @State inputBusyLevel: number = 2;
  @State inputCost: string = '20';
  @State inputLat: string = '';
  @State inputLng: string = '';

  private levels: string[] = ['拉完了', 'NPC', '人上人', '顶级', '夯'];
  @State selectedLevelIndex: number = 4;

  private apiKey: string = 'YOUR_QWEATHER_API_KEY';

  @StorageLink('MyShopsData') shopsJson: string = '';
  @State shops: Shop[] = [];

  aboutToAppear(): void {
    try {
      let parsed: Shop[] = JSON.parse(this.shopsJson) as Shop[];
      if (parsed && parsed.length > 0) {
        let defaultMap = new Map<string, Shop>();
        defaultShops.forEach(s => defaultMap.set(s.name, s));

        this.shops = parsed.map((p: Shop) => {
          let matched = defaultMap.get(p.name);
          if (matched) {
            p.lat = matched.lat;
            p.lng = matched.lng;
          }
          return p;
        });
      } else {
        this.shops = defaultShops;
      }
    } catch {
      this.shops = defaultShops;
    }

    setTimeout(() => {
      this.fetchEnvironmentData();
    }, 500);
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
    if (meters < 1000) {
      return `${meters}m`;
    } else {
      return `${(meters / 1000).toFixed(1)}km`;
    }
  }

  async fetchEnvironmentData(): Promise<void> {
    let longitude: number = 113.294000;
    let latitude: number = 23.093500;

    try {
      let location = await geoLocationManager.getCurrentLocation();
      longitude = location.longitude;
      latitude = location.latitude;
    } catch {
      console.warn('真实定位获取失败，已切换至康乐园教学楼模拟坐标');
    }

    let updatedShops = this.shops.map((shop: Shop) => {
      let shopLat: number = shop.lat || 0;
      let shopLng: number = shop.lng || 0;

      if (shopLat === 0 || shopLng === 0) {
        // 📍 智能打散算法：为没有坐标的店铺加上随机偏移量
        let latOffset = (Math.random() - 0.5) * 0.005;
        let lngOffset = (Math.random() - 0.5) * 0.005;

        if (shop.type === '吃泡面') {
          shopLat = 23.097500; shopLng = 113.299000;
        } else if (shop.type === '点外卖') {
          shopLat = 23.101800; shopLng = 113.296500;
        } else if (shop.type === '吃食堂') {
          shopLat = 23.094500 + latOffset;
          shopLng = 113.292500 + lngOffset;
        } else {
          // 「出去吃」范围更大
          shopLat = 23.090000 + (latOffset * 2);
          shopLng = 113.300000 + (lngOffset * 2);
        }
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
    let url: string = `https://devapi.qweather.com/v7/weather/now?location=${longitude},${latitude}&key=${this.apiKey}`;

    try {
      let data: http.HttpResponse = await httpRequest.request(url, { method: http.RequestMethod.GET });
      if (data.responseCode === 200) {
        let result: WeatherResponse = JSON.parse(data.result as string) as WeatherResponse;
        let weatherText: string = result.now.text;

        this.isRainy = weatherText.includes('雨');
        this.weatherDescription = weatherText;
        this.resultSubText = `已联网同步天气：${weatherText}`;
      } else {
        this.weatherDescription = '天气获取失败';
      }
    } catch {
      this.weatherDescription = '天气网络异常';
    } finally {
      httpRequest.destroy();
    }
  }

  syncDataToStorage(): void {
    this.shopsJson = JSON.stringify(this.shops);
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

    let timeFactor: number = 1.0;
    if (hour >= 15 && hour < 17) {
      timeFactor = 0.3;
    } else if ((hour >= 11 && hour <= 13) || (hour >= 18 && hour <= 19)) {
      timeFactor = 1.8;
    }

    const busyFactorMap: number[] = [0.8, 1.2, 2.2];
    const shopBusyLevel: number = shop.busyLevel || 2;
    const busyFactor: number = busyFactorMap[shopBusyLevel - 1];

    return Math.ceil(avg * busyFactor * timeFactor);
  }

  rollFood(): void {
    if (this.isRolling) return;

    let validShops = this.shops.filter((s: Shop) => {
      return this.isBudgetExpanded ? Number(s.avgCost) <= Number(this.currentBudget) : true;
    });

    if (validShops.length === 0) {
      this.getUIContext().animateTo({ curve: curves.springMotion() }, () => {
        this.resultText = '喝西北风 🌬️';
        this.resultCategory = '🚫 严重超支';
        this.resultSubText = '当前预算下连泡面都吃不起，请提高预算！';
        this.textScale = 1.1;
      });
      setTimeout(() => { this.textScale = 1.0; }, 500);
      return;
    }

    this.lastWaitTimeRecord = this.showReroll ? this.predictedTotalTime : 999;
    this.isRolling = true;
    this.showReroll = false;
    this.resultCategory = '';

    let availableTypes = Array.from(new Set(validShops.map(s => s.type)));

    let count: number = 0;
    let intervalId: number = setInterval(() => {
      this.resultText = availableTypes[Math.floor(Math.random() * availableTypes.length)];
      count++;
      if (count > 15) {
        clearInterval(intervalId);
        this.finishRolling(validShops, availableTypes);
      }
    }, 80);
  }

  finishRolling(validShops: Shop[], availableTypes: string[]): void {
    let finalType: string = availableTypes[Math.floor(Math.random() * availableTypes.length)];

    let weatherFactor: number = 1.0;
    if (this.isRainy && finalType === '出去吃') weatherFactor = 0.2;
    if (this.isRainy && (finalType === '点外卖' || finalType === '吃泡面')) weatherFactor = 2.0;

    let finalAvailableShops: Shop[] = validShops.filter(s => s.type === finalType);

    if (finalAvailableShops.length > 0) {
      let weightPool: Shop[] = [];
      finalAvailableShops.forEach((shop: Shop) => {
        let finalWeight: number = 1;

        let waitTime: number = this.predictWaitTime(shop);
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

        let finalCount: number = Math.ceil(finalWeight * weatherFactor);
        for (let i = 0; i < finalCount; i++) { weightPool.push(shop); }
      });

      let pickedShop: Shop = weightPool.length > 0 ? weightPool[Math.floor(Math.random() * weightPool.length)] : finalAvailableShops[0];

      this.resultText = pickedShop.name;
      this.resultCategory = `🏷️ ${finalType}`;

      let locLabel = pickedShop.type === '吃泡面' ? ' (宿舍)' : (pickedShop.type === '点外卖' ? ' (小北门外卖柜)' : '');
      let distText = pickedShop.distanceStr ? ` | 📍 距离: ${pickedShop.distanceStr}${locLabel}` : '';
      this.resultSubText = `预估人均：￥${pickedShop.avgCost} | 评价：${pickedShop.level}${distText}`;

      let finalQueueTime: number = this.predictWaitTime(pickedShop);
      let finalWalkTime: number = Math.ceil((pickedShop.rawDistance || 0) / 80);

      let newTotalTime: number = pickedShop.type === '点外卖' ? Math.max(finalQueueTime, finalWalkTime) : finalQueueTime + finalWalkTime;

      if (this.lastWaitTimeRecord < 999 && newTotalTime > this.lastWaitTimeRecord) {
        newTotalTime = this.lastWaitTimeRecord;
        if (pickedShop.type === '点外卖') {
          finalQueueTime = newTotalTime;
        } else {
          finalQueueTime = Math.max(0, newTotalTime - finalWalkTime);
        }
        newTotalTime = pickedShop.type === '点外卖' ? Math.max(finalQueueTime, finalWalkTime) : finalQueueTime + finalWalkTime;
      }

      this.predictedQueueTime = finalQueueTime;
      this.predictedWalkTime = finalWalkTime;
      this.predictedTotalTime = newTotalTime;

      if (this.predictedTotalTime > 30) { this.showReroll = true; }
    }

    this.isRolling = false;
    this.getUIContext().animateTo({ curve: curves.springMotion() }, () => { this.textScale = 1.2; });
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: curves.springMotion() }, () => { this.textScale = 1.0; });
    }, 500);
  }

  parseBatchInput(): void {
    if (this.batchInputText.trim() === '') return;
    let lines: string[] = this.batchInputText.split('\n');
    let addedCount: number = 0;
    lines.forEach((line: string) => {
      let parts: string[] = line.split(/[ ,，-]+/);
      if (parts.length >= 2) {
        let name: string = parts[0];
        let type: string = parts[1];
        let cost: number = parts.length >= 3 ? Number(parts[2]) : 20;
        let lat: number | undefined = (parts.length >= 4 && !isNaN(Number(parts[3]))) ? Number(parts[3]) : undefined;
        let lng: number | undefined = (parts.length >= 5 && !isNaN(Number(parts[4]))) ? Number(parts[4]) : undefined;

        const newShop: Shop = {
          name: name, type: type, level: '人上人', score: 3,
          busyLevel: 2, avgCost: isNaN(cost) ? 20 : cost, history: [15]
        };

        if (lat !== undefined && lng !== undefined) {
          newShop.lat = lat;
          newShop.lng = lng;
        }

        this.shops.push(newShop);
        addedCount++;
      }
    });
    this.syncDataToStorage();
    this.batchInputText = '';

    this.fetchEnvironmentData();

    try {
      this.getUIContext().getPromptAction().showToast({ message: `成功导入 ${addedCount} 家店铺` });
    } catch { }
  }

  @Builder SheetBuilder() {
    Tabs() {
      TabContent() {
        Column({ space: 15 }) {
          Text('智能批量导入').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
          TextArea({ placeholder: '格式：名称 分类 价格 [纬度] [经度]\n示例：\n松涛园 吃食堂 15\n遇见小面 出去吃 25 23.096 113.305', text: this.batchInputText })
            .onChange((v: string) => this.batchInputText = v).height(150).backgroundColor('#F5F7FA')
          Button('解析并存入饭单').width('100%').height(45).backgroundColor('#1A1A1A')
            .onClick(() => { this.parseBatchInput(); })
          Text('支持多行粘贴，自动识别空格或逗号分隔符').fontSize(12).fontColor('#999').width('100%')
        }.padding(25)
      }.tabBar('批量导入')

      TabContent() {
        Column({ space: 15 }) {
          Text(this.editingIndex === -1 ? '手动录入' : '重新评价').fontSize(18).fontWeight(FontWeight.Bold)
          TextInput({ placeholder: '店铺名称', text: this.inputName }).onChange((v: string) => this.inputName = v)
          Row({ space: 10 }) {
            TextInput({ placeholder: '人均消费', text: this.inputCost }).type(InputType.Number).layoutWeight(1).onChange((v: string) => this.inputCost = v)
            Select([{ value: '吃食堂' }, { value: '点外卖' }, { value: '出去吃' }, { value: '吃泡面' }])
              .value(this.inputType).onSelect((i: number, v: string) => this.inputType = v).layoutWeight(1)
          }
          Row({ space: 10 }) {
            TextInput({ placeholder: '纬度(选填)', text: this.inputLat }).type(InputType.Number).layoutWeight(1).onChange((v: string) => this.inputLat = v)
            TextInput({ placeholder: '经度(选填)', text: this.inputLng }).type(InputType.Number).layoutWeight(1).onChange((v: string) => this.inputLng = v)
          }

          Button('保存修改').width('100%').height(45).backgroundColor('#1A1A1A')
            .onClick(() => {
              if (!this.inputName) return;
              const newShop: Shop = {
                name: this.inputName, type: this.inputType, level: this.levels[this.selectedLevelIndex],
                score: this.selectedLevelIndex + 1, busyLevel: this.inputBusyLevel,
                avgCost: Number(this.inputCost), history: [15]
              };

              if (this.inputLat !== '' && this.inputLng !== '') {
                newShop.lat = Number(this.inputLat);
                newShop.lng = Number(this.inputLng);
              }

              if (this.editingIndex === -1) {
                this.shops.push(newShop);
              } else {
                this.shops[this.editingIndex] = newShop;
              }

              this.syncDataToStorage();
              this.fetchEnvironmentData();

              this.inputLat = '';
              this.inputLng = '';
              this.isShowSheet = false;
            })
        }.padding(25)
      }.tabBar('手动录入')
    }.backgroundColor(Color.White).borderRadius({ topLeft: 20, topRight: 20 })
  }

  @Builder DeleteButton(index: number) {
    Button('删除').backgroundColor('#D32F2F').fontColor(Color.White).width(80).height('100%')
      .onClick(() => {
        this.shops.splice(index, 1);
        this.syncDataToStorage();
      })
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        Text(this.resultText).fontSize(34).fontWeight(FontWeight.Bolder).scale({ x: this.textScale, y: this.textScale })

        if (this.resultCategory !== '') {
          Text(this.resultCategory).fontSize(12).fontColor('#007DFF').backgroundColor('rgba(0, 125, 255, 0.1)')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 }).borderRadius(8)
        }

        Text(this.resultSubText).fontSize(14).fontColor('#666').textAlign(TextAlign.Center)

        Row({ space: 10 }) {
          Text('实时环境：').fontSize(14).fontColor('#333')
          Text(this.weatherDescription + (this.isRainy ? ' 🌧️' : ' 🌤️'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(this.isRainy ? '#007DFF' : '#FF9800')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(20)
        }.margin({ top: 5 })

        Row({ space: 5 }) {
          ForEach(['综合', '省钱', '效率', '美味', '距离'], (label: string, index: number) => {
            Button(label).layoutWeight(1).height(35).fontSize(12)
              .backgroundColor(this.currentPreference === index ? '#1A1A1A' : 'rgba(0,0,0,0.06)')
              .fontColor(this.currentPreference === index ? Color.White : '#333')
              .onClick(() => { this.currentPreference = index; })
          })
        }.width('100%').padding({ left: 10, right: 10 })

        Column({ space: 5 }) {
          Text(this.isBudgetExpanded ? '收起预算设置 ▲' : '展开预算设置 ▼')
            .fontSize(12).fontColor('#666').onClick(() => {
            this.getUIContext().animateTo({ curve: curves.springMotion() }, () => { this.isBudgetExpanded = !this.isBudgetExpanded; });
          })

          if (this.isBudgetExpanded) {
            Row() {
              Text('预算上限：').fontSize(14)
              Text(`￥${this.currentBudget}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#E64A19')
            }.margin({ top: 10 })
            Slider({ value: this.currentBudget, min: 10, max: 200, step: 5 }).onChange((v: number) => { this.currentBudget = Math.floor(v); }).width('85%').selectedColor('#E64A19')
          }
        }.padding(10).backgroundColor('rgba(255,255,255,0.4)').borderRadius(15)

        if (this.predictedTotalTime > 0) {
          Column({ space: 6 }) {
            Row({ space: 15 }) {
              Text(`🚶 步行：${this.predictedWalkTime} 分钟`).fontSize(13).fontColor('#555')
              Text(`⏳ 等候：${this.predictedQueueTime} 分钟`).fontSize(13).fontColor('#555')
            }
            Text(`总耗时：${this.predictedTotalTime} 分钟`)
              .fontSize(16)
              .fontColor(this.predictedTotalTime > 30 ? '#D32F2F' : '#388E3C')
              .fontWeight(FontWeight.Bold)
          }.margin({ top: 5 })

          if (this.showReroll) {
            Button('重新选择').height(30).backgroundColor('#D32F2F').onClick(() => { this.rollFood(); })
          }
        }

        Button(this.isRolling ? '算法计算中...' : '开始决定').width('75%').height(50).backgroundColor('#1A1A1A').onClick(() => { this.rollFood(); })
      }
      .padding({ top: 50, bottom: 25, left: 15, right: 15 }).width('100%')
      .backgroundColor('rgba(255, 255, 255, 0.4)').backgroundBlurStyle(BlurStyle.Thin).borderRadius({ bottomLeft: 40, bottomRight: 40 })

      Row() {
        Text(`江湖饭单 (${this.shops.length})`).fontWeight(FontWeight.Bold).layoutWeight(1)
        Button('添加/导入').height(30).fontSize(12).backgroundColor('#007DFF').onClick(() => { this.editingIndex = -1; this.isShowSheet = true; })
      }.width('100%').padding(20)

      List({ space: 10 }) {
        ForEach(this.shops, (item: Shop, index: number) => {
          ListItem() {
            Row() {
              Column() {
                Text(item.name).fontWeight(FontWeight.Bold)

                Text(`人均 ￥${item.avgCost}`).fontSize(12).fontColor('#666').margin({ top: 4 })

                if (item.distanceStr && item.distanceStr !== '距离未知') {
                  Row() {
                    Text('📍 距离: ' + item.distanceStr + (item.type === '吃泡面' ? ' (宿舍)' : (item.type === '点外卖' ? ' (小北门外卖柜)' : '')))
                      .fontSize(12)
                      .fontColor('#007DFF')
                  }.margin({ top: 4 })
                }
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(item.level).fontSize(11).fontColor(Color.White).backgroundColor('#1A1A1A').padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(5)
            }
            .width('100%').padding(15).backgroundColor(Color.White).borderRadius(12)
            .onClick(() => { this.editingIndex = index; this.isShowSheet = true; })
          }.swipeAction({ end: this.DeleteButton(index) })
        })
      }.padding({ left: 20, right: 20, bottom: 10 }).layoutWeight(1)
    }
    .width('100%').height('100%')
    .linearGradient({ direction: GradientDirection.RightBottom, colors: [['#E0EAFC', 0], ['#CFDEF3', 1]] })
    .bindSheet($$this.isShowSheet, this.SheetBuilder(), { height: SheetSize.MEDIUM })
  }
}