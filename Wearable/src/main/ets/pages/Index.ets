import { promptAction } from '@kit.ArkUI';

interface Shop {
  name: string;
  type: string;
  level: string;
  score: number;
  busyLevel: number;
  avgCost: number;
}

// ==================== 1. 定义手表全屏卡片 (保留防裁切安全区) ====================
@CustomDialog
struct ProactiveCardDialog {
  controller: CustomDialogController;
  @Prop title: string = '';
  @Prop message: string = '';
  @Prop recommendation: string = '';

  build() {
    Column({ space: 8 }) {
      Text(this.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .margin({ top: 10 })
      Text(this.message).fontSize(11).fontColor('#aaaaaa').textAlign(TextAlign.Center)
        .padding({ left: 16, right: 16 })

      Text(this.recommendation).fontSize(18).fontColor('#007DFF').fontWeight(FontWeight.Bolder)
        .margin({ top: 4, bottom: 4 })

      Button('一键导航')
        .onClick(() => {
          this.controller.close();
          // 这个跨端通信的 Toast 咱们保留，让用户知道指令成功发送给手机了
          promptAction.showToast({ message: '导航指令已同步至手机端', duration: 2000 });
        })
        .width('75%').backgroundColor('#007DFF').height(35).fontSize(13)

      Button('忽略')
        .onClick(() => { this.controller.close(); })
        .width('75%').backgroundColor('#262626').fontColor(Color.White).height(35).fontSize(13)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .justifyContent(FlexAlign.Center)
    .padding({ top: 25, bottom: 25, left: 15, right: 15 })
  }
}

// ==================== 2. 主页面 ====================
@Entry
@Component
struct WearableIndex {
  @State cardTitle: string = '';
  @State cardMessage: string = '';
  @State cardRecommendation: string = '';

  @State currentBudget: number = 30;
  @State resultText: string = '今天吃什么？';
  @State isRolling: boolean = false;

  @State allShops: Shop[] = [
    // ===== 食堂 =====
    { name: '松涛园一楼自选', type: '吃食堂', level: '穷', score: 5, busyLevel: 2, avgCost: 15 },
    { name: '松涛园二楼烧腊', type: '吃食堂', level: '人上人', score: 4, busyLevel: 2, avgCost: 16 },
    { name: '松涛园三楼三杯鸡', type: '吃食堂', level: '顶级', score: 5, busyLevel: 3, avgCost: 18 },
    { name: '松涛园三楼麻辣烫', type: '吃食堂', level: '穷', score: 4, busyLevel: 3, avgCost: 17 },
    { name: '学一食堂大锅菜', type: '吃食堂', level: 'NPC', score: 3, busyLevel: 3, avgCost: 12 },
    { name: '学一食堂肠粉', type: '吃食堂', level: '穷', score: 4, busyLevel: 2, avgCost: 8 },
    { name: '学五铁板烧', type: '吃食堂', level: '穷', score: 5, busyLevel: 3, avgCost: 16 },
    { name: '学五滑蛋饭', type: '吃食堂', level: '顶级', score: 5, busyLevel: 2, avgCost: 15 },
    { name: '学五糖水铺', type: '吃食堂', level: '人上人', score: 4, busyLevel: 1, avgCost: 6 },
    { name: '绿茵西餐厅', type: '吃食堂', level: '人上人', score: 4, busyLevel: 1, avgCost: 40 },
    { name: '紫荆园简餐', type: '吃食堂', level: 'NPC', score: 3, busyLevel: 1, avgCost: 25 },
    { name: '春晖园快餐', type: '吃食堂', level: '拉完了', score: 2, busyLevel: 2, avgCost: 13 },

    // ===== 校外 =====
    { name: '下渡路遇见小面', type: '出去吃', level: '人上人', score: 4, busyLevel: 2, avgCost: 25 },
    { name: '新港西路萨莉亚', type: '出去吃', level: '穷', score: 5, busyLevel: 2, avgCost: 35 },
    { name: '尊宝比萨(下渡路店)', type: '出去吃', level: '穷', score: 4, busyLevel: 1, avgCost: 30 },
    { name: '麦当劳(新港西路店)', type: '出去吃', level: 'NPC', score: 3, busyLevel: 3, avgCost: 25 },
    { name: '肯德基(下渡路店)', type: '出去吃', level: 'NPC', score: 3, busyLevel: 2, avgCost: 28 },
    { name: '华辉拉肠(下渡路)', type: '出去吃', level: '穷', score: 4, busyLevel: 2, avgCost: 18 },
    { name: '袁记云饺(下渡路)', type: '出去吃', level: '人上人', score: 4, busyLevel: 1, avgCost: 20 },
    { name: '八合里牛肉火锅(南门)', type: '出去吃', level: '顶级', score: 5, busyLevel: 3, avgCost: 80 },
    { name: '瑞幸咖啡(中大南门)', type: '出去吃', level: 'NPC', score: 4, busyLevel: 2, avgCost: 15 },
    { name: '塔斯汀(中大店)', type: '出去吃', level: '人上人', score: 4, busyLevel: 1, avgCost: 35 },
    { name: '蜜红糖芝士茶', type: '出去吃', level: '顶级', score: 5, busyLevel: 3, avgCost: 20 },
    { name: '蜜红地铁口烧烤摊', type: '出去吃', level: '穷', score: 5, busyLevel: 2, avgCost: 45 },

    // ===== 外卖 =====
    { name: '塔斯汀中国汉堡', type: '点外卖', level: '穷', score: 5, busyLevel: 2, avgCost: 20 },
    { name: '蜜雪冰城(外卖)', type: '点外卖', level: '人上人', score: 4, busyLevel: 1, avgCost: 8 },

    // ===== 泡面 =====
    { name: '白象老母鸡汤面', type: '吃泡面', level: '顶级', score: 5, busyLevel: 1, avgCost: 5 }
  ];

  dialogController: CustomDialogController = new CustomDialogController({
    builder: ProactiveCardDialog({
      title: this.cardTitle,
      message: this.cardMessage,
      recommendation: this.cardRecommendation
    }),
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  timerId: number = -1;
  scroller: Scroller = new Scroller();

  aboutToAppear() {
    this.startBiologicalClockEngine();
  }

  aboutToDisappear() {
    clearInterval(this.timerId);
  }

  startBiologicalClockEngine() {
    this.timerId = setInterval(() => {
      let now = new Date();
      let hours = now.getHours();
      let minutes = now.getMinutes();

      if (hours === 18 && minutes === 10) {
        this.triggerCard('实验下课啦！', '大物实验辛苦了，当前松涛园人流较少，为你推荐：', '松涛园三楼三杯鸡');
      }
      if (hours === 3 && minutes === 0) {
        this.triggerCard('比赛即将开赛！', '看拜仁怎么能饿着肚子？周边夜宵已为你选好：', '外卖螺蛳粉/烧烤摊');
      }
    }, 60000);
  }

  triggerCard(title: string, msg: string, rec: string) {
    this.cardTitle = title;
    this.cardMessage = msg;
    this.cardRecommendation = rec;
    this.dialogController.open();
  }

  rollFood() {
    if (this.isRolling) return;

    let filtered = this.allShops.filter(shop => shop.avgCost <= this.currentBudget);
    if (filtered.length === 0) {
      this.resultText = '预算过低，建议回宿舍泡面';
      return;
    }

    this.isRolling = true;
    let counter = 0;

    let intervalId = setInterval(() => {
      let randomIndex = Math.floor(Math.random() * filtered.length);
      this.resultText = filtered[randomIndex].name;
      counter++;

      if (counter > 10) {
        clearInterval(intervalId);
        this.isRolling = false;
        // 💡 修复：已删除了这里原本导致弹窗遮挡的 promptAction.showToast
      }
    }, 80);
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        Text('干饭雷达 ⌚').fontSize(11).fontColor('#666666').margin({ top: 25, bottom: 5 })

        Column() {
          Text(this.resultText)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .margin({ bottom: 4 })

          if(!this.isRolling && this.resultText !== '今天吃什么？' && this.resultText !== '预算过低，建议回宿舍泡面') {
            Text(`均价: ￥${this.allShops.find((s: Shop) => s.name === this.resultText)?.avgCost ?? '--'} | 评分: ${this.allShops.find((s: Shop) => s.name === this.resultText)?.score ?? '--'}★`)
              .fontSize(11).fontColor('#007DFF')
          }
        }
        .height(55)
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 5 })

        Button(this.isRolling ? '正在挑选...' : '立刻摇号')
          .onClick(() => { this.rollFood(); })
          .width('75%')
          .height(38)
          .backgroundColor(this.isRolling ? '#444444' : '#ff5500')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 20 })

        // 💡 核心升级：废弃按钮，引入 Slider 丝滑滑轨组件！
        Column({ space: 4 }) {
          Text(`预算上限: ￥${this.currentBudget}`)
            .fontSize(12)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)

          Slider({
            value: this.currentBudget,
            min: 10,
            max: 150,
            step: 5,               // 每次滑动跨度为 5 元
            style: SliderStyle.OutSet // 凸起样式更适合手指触摸
          })
            .width('85%')
            .blockColor('#ff5500')    // 滑块颜色
            .selectedColor('#ff5500') // 滑过的轨迹颜色
            .trackColor('#333333')    // 未滑过的底色
            .showSteps(false)
            .onChange((value: number) => {
              // 实时捕获滑轨的值，并保证为整数
              this.currentBudget = Math.floor(value);
            })
        }
        .margin({ bottom: 8 })

        // 饭单数量随滑块实时跳动
        Text(`预算内可选饭单: ${this.allShops.filter((s: Shop) => s.avgCost <= this.currentBudget).length} 家`)
          .fontSize(10).fontColor('#aaaaaa')
          .margin({ bottom: 20 })

        Text('点击测试时间感知卡片')
          .fontSize(9)
          .fontColor('#222222')
          .onClick(() => {
            this.triggerCard('实验下课啦！', '大物实验辛苦了，当前松涛园人流较少，为你推荐：', '松涛园三楼三杯鸡');
          })
          .margin({ bottom: 25 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto) // 💡 优化：手指划动时才出现滚动条，兼顾美观与提示
  }
}