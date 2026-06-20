# 🍜 康乐园美食决策系统 (SYSU-ECE-FoodGuide)

---

### 📖 项目简介
本项目是为 Sun Yat-sen University (南校区) 开发的智能美食决策助手。旨在解决学生群体面对繁多餐饮选择时的“选择困难症”，通过智能算法与多端自适应架构，提供高效的用餐决策支持。

---
本分支更新效果指南：
### 🚀 核心架构突破：一次开发，多端部署 (One Codebase, Multi-platform)

本项目严格遵循 OpenHarmony **“一次开发，多端部署”** 的设计哲学，通过一套核心逻辑适配多种设备形态：

1. **架构解耦 (Logic-UI Decoupling)**：
   * 核心逻辑与界面渲染完全解耦。底层的“饥饿感知算法”和“美食数据引擎”在所有设备上保持统一，确保了数据的一致性与高可用性。

2. **响应式布局策略 (Responsive Strategy)**：
   * **动态断点适配**：利用鸿蒙 Breakpoint 机制，精准识别屏幕宽度的变化。
   * **多形态 UI 转换**：
     * **手机端 (xs/sm)**：采用流式上下分屏布局，通过 `layoutWeight(1)` 自动平分屏幕，确保移动端操作的便捷与视觉的平衡。
     * **大屏端 (平板/2in1/折叠屏)**：系统检测到宽屏模式后，自动触发组件重构，将界面切换为并行的左右分栏结构，最大化利用大屏空间，实现生产力级的交互体验。

3. **无感部署与设备互通**：
   * 通过 `@StorageLink` 与 `@State` 的联动，实现了应用状态在不同屏幕间的无缝同步。无论是在何种设备上录入的美食数据，均可实现跨设备共享，体现了鸿蒙生态的架构优势。
<img width="502" height="1077" alt="image" src="https://github.com/user-attachments/assets/d006bc24-8b1d-4495-8443-03c3098bac57" />
<img width="1165" height="840" alt="image" src="https://github.com/user-attachments/assets/053a5bb5-13fe-43cf-9ddf-764e54f03c79" />
<img width="556" height="937" alt="image" src="https://github.com/user-attachments/assets/0195b8df-ef0d-47eb-9131-c0e77fe33eaf" />

---

### ✨ 功能亮点
* **🧠 智能决策算法**：综合预算、距离、天气及餐厅拥挤度，实现个性化用餐推荐。
* **🖼️ 智能图库引擎**：自动补全缺失的美食预览图，保证在所有设备上视觉美感的一致性。
* **📊 数据管理中心**：支持文本批量导入，构建个人专属美食图鉴
