import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 页面初始化逻辑
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 设置加载的页面为 pages/Index
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        console.error('加载页面失败: ' + JSON.stringify(err));
        return;
      }
    });
  }

  onWindowStageDestroy(): void {}
  onForeground(): void {}
  onBackground(): void {}
}