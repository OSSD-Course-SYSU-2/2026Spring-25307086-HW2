# 🍱 饥饿感知系统 (Hunger Sensing System)

> 基于 HarmonyOS ArkTS 构建的全场景、分布式智能餐饮决断中枢。
> **核心理念**：用算法终结选择困难，用分布式技术延展生活边界。

## 💡 开发思路与迭代记录 (Development Evolution)

本项目的诞生与迭代，并非简单的功能堆砌，而是源于对真实校园生活痛点的持续观察与解决。每一次大版本的升级，都是为了让系统更接近一个“懂你”的数字助理。

### 阶段一：破局——从“随便”到“精准加权” (V1 基础决断引擎)
* **痛点场景**：每天面临“吃什么”的终极拷问，传统的随机转盘过于盲目，无法兼顾距离、预算与口味。
* **开发思路**：抛弃纯随机，构建**多维加权算法 (Lottery Engine)**。引入“综合、省钱、效率、美味、距离”五大偏好维度。
* **视觉重构**：为了避免审美疲劳，采用 `WaterFlow` 瀑布流布局打造美食图鉴，并首创“食欲唤醒渐变色引擎”结合毛玻璃效果，实现高度定制化的赛博朋克 UI 视觉。
<img width="490" height="1056" alt="image" src="https://github.com/user-attachments/assets/5b1247bd-7a4a-4efe-9ac5-2b09b033fcf0" />


### 阶段二：感知——让系统拥有“触觉” (V2 环境传感器接入)
* **痛点场景**：大雨天算法却推荐距离 2 公里外的热门餐厅，静态数据无法适应动态现实。
* **开发思路**：赋予系统空间与环境的感知能力。
    * **空间锚点**：接入 HarmonyOS `LocationKit`，获取真实 GPS 定位，精确计算步行距离与预计到达时间（并针对室内无信号场景提供基准点降级方案）。
    * **天候同步**：调用 `NetworkKit` 抓取和风天气 (QWeather) 实时数据。当检测到“降雨”时，动态削减“出去吃”的权重，大幅提升“点外卖/吃泡面”的中签率。
<img width="467" height="47" alt="image" src="https://github.com/user-attachments/assets/d726b029-102e-4d81-aa92-6e88173f118e" />
<img width="447" height="167" alt="image" src="https://github.com/user-attachments/assets/be061456-b971-4f23-87ad-8fbecdb88d4f" />

### 阶段三：沉淀——形成个人餐饮大数据 (V3 记忆与数据闭环)
* **痛点场景**：吃完就忘，月底不知钱花哪了，排队等得怀疑人生却无法量化。
* **开发思路**：引入历史就餐记录功能，实现数据的闭环。
    * **持久化记忆**：利用 `PersistentStorage` 与 `@StorageLink`，建立本地沙盒数据库，记录每一次的决断结果。
    * **干饭打卡系统**：通过 `@CustomDialog` 实现打卡交互，沉淀“实际消费”与“排队用时”两项核心指标。
    * **月度生存报告**：系统自动梳理当月数据，输出总消费（恩格尔系数参考）与平均候餐时间，反向指导下个月的预算拉条配置。
<img width="483" height="1035" alt="image" src="https://github.com/user-attachments/assets/71f599e7-4a6d-47e4-8655-4c97652efb35" />

### 阶段四：无界——跨越设备孤岛 (V4 分布式自由流转)
* **痛点场景**：在宿舍用手机做完决策，出门路上还需频频掏出手机查看餐厅位置与信息，交互体验存在断层。
* **开发思路**：全面拥抱 HarmonyOS 的“万物互联”特性，将工程扩展为 `entry` (手机端) + `Wearable` (手表端) 双模块架构，实现自由流转。
    * **状态接力 (Cross-device Continuity)**：利用 `EntryAbility` 的 `onContinue` 打包数据，在手表端解析重构。一键将手机摇出的天命餐厅与历史打卡档案，通过超级终端推送到手腕。
    * **穿戴专属适配**：摒弃手表端冗杂的 UI，重构极致精简的表盘展示。抬腕即见目标餐厅、预估等待时间与人均消费，彻底解放双手。添加小组件卡片，智能提醒吃饭选择
<img width="1170" height="837" alt="image" src="https://github.com/user-attachments/assets/9fd9dd5f-50a3-412a-abbd-b19a18c0edf1" />
<img width="511" height="468" alt="image" src="https://github.com/user-attachments/assets/661d44e2-6820-426c-a064-a8994bb22eb2" />
<img width="491" height="485" alt="image" src="https://github.com/user-attachments/assets/48326663-c879-4119-91ed-defe55e400ab" />

---

## 🛠️ 技术栈与系统架构 (Tech Stack)

* **开发语言**：ArkTS (声明式 UI，严格类型控制)
* **页面布局**：`GridRow/GridCol` (响应式), `WaterFlow` (瀑布流), `List` (打卡记录)
* **核心 API 调用**：
    * `@kit.ArkUI`：组件化与自定义弹窗渲染。
    * `@kit.LocationKit`：终端真实地理位置获取。
    * `@kit.NetworkKit`：实时天气数据 HTTP Fetch 请求。
    * `@kit.AbilityKit`：底层流转权限申请、超级终端分布式调度。
* **状态管理**：`@State`, `@StorageLink`, `PersistentStorage`

---

## 🚀 部署与流转测试指南 (How to Run)

1. **环境依赖**：DevEco Studio NEXT 或支持 API 9+ 的环境。
2. **多端联调**：
    * **真机测试**：准备同一华为账号下的华为手机与华为手表，连接同一局域网并开启蓝牙。
    * **模拟器测试**：在 DevEco 中启动 `Multi-device Emulator` (Phone + Wearable)。
3. **功能体验路径**：
    * 启动手机端 App，调整预算阀门与偏好，点击摇号。
    * 摇出结果后，若需出门，呼出多任务后台，点击顶部的**流转胶囊/超级终端图标**。
    * 选中手表设备，观察手表端是否瞬间拉起，并精准同步当前决定的餐厅与打卡数据库。
    * 在手机或手表端点击“在此打卡”，体验持久化存储的秒级刷新。

> “让技术融入生活，用鸿蒙串联场景。每一次在 ArkTS 编译器里的死磕，都是为了让下一次干饭不留遗憾。”
