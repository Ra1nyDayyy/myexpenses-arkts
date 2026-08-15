import { SettingsMain } from './SettingsMain';
import { SettingsData } from './SettingsData';
import { SettingsUI } from './SettingsUI';
import { SettingsIO } from './SettingsIO';

/**
 * 设置入口页面：包含Navigation导航栈
 * 对应 Android PreferenceActivity
 */
@Entry
@Component
struct Settings {
  private navStack: NavPathStack = new NavPathStack();

  build() {
    Navigation(this.navStack) {
      SettingsMain({ navStack: this.navStack })
    }
    .mode(NavigationMode.Stack)
    .hideToolBar(true)
    .navDestination(this.settingsPageMap)
  }

  @Builder
  settingsPageMap(name: string) {
    if (name === 'SettingsData') {
      SettingsData()
    } else if (name === 'SettingsUI') {
      SettingsUI()
    } else if (name === 'SettingsIO') {
      SettingsIO()
    } else if (name === 'SettingsBackup') {
      SettingsBackup()
    } else if (name === 'SettingsOCR') {
      SettingsOCR()
    } else if (name === 'SettingsSync') {
      SettingsSync()
    } else if (name === 'SettingsWebUI') {
      SettingsWebUI()
    } else if (name === 'SettingsAttachPicture') {
      SettingsAttachPicture()
    } else if (name === 'SettingsPrint') {
      SettingsPrint()
    } else if (name === 'SettingsContrib') {
      SettingsContrib()
    } else if (name === 'SettingsSecurity') {
      SettingsSecurity()
    } else if (name === 'SettingsFeedback') {
      SettingsFeedback()
    } else if (name === 'SettingsAdvanced') {
      SettingsAdvanced()
    }
  }
}

// 临时占位组件，后续逐个实现
@Component

struct SettingsBackup {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('备份恢复设置 - 开发中')
        .fontSize(16)
    }
    .title('备份与恢复')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsOCR {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('OCR设置 - 开发中')
        .fontSize(16)
    }
    .title('扫描收据')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsSync {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('同步设置 - 开发中')
        .fontSize(16)
    }
    .title('同步')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsWebUI {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('Web界面设置 - 开发中')
        .fontSize(16)
    }
    .title('Web界面')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsAttachPicture {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('附加图片设置 - 开发中')
        .fontSize(16)
    }
    .title('附加图片')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsPrint {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('打印设置 - 开发中')
        .fontSize(16)
    }
    .title('打印')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsContrib {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('专业版设置 - 开发中')
        .fontSize(16)
    }
    .title('专业版')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsSecurity {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('安全设置 - 开发中')
        .fontSize(16)
    }
    .title('安全')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsFeedback {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('帮助与反馈 - 开发中')
        .fontSize(16)
    }
    .title('帮助与反馈')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsAdvanced {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('高级设置 - 开发中')
        .fontSize(16)
    }
    .title('高级')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}