# CollapseIcons

干净、可定制的 **macOS 菜单栏图标折叠** 工具。

把不常用的状态栏图标收起来，菜单栏立刻清爽；需要时一键展开。

## 功能

- **三段布局**：可折叠区 / 常显区 / 永久隐藏区
- **全局快捷键**（默认 `⌥⌘H`）折叠 / 展开
- **自动折叠**：空闲 N 秒后自动收起
- **悬停展开**：鼠标移到折叠按钮上展开
- **自定义点击**：左键 / 右键 / Option+点击 行为可配
- **图标样式**：Chevron / Arrows / Dots / Minus / Eye
- **登录启动**、启动即折叠
- **刘海安全模式**：自动折叠溢出；展开时在菜单栏**下方**展示，不被摄像头遮挡
- 纯菜单栏应用（Dock 无图标）

## 系统要求

- macOS 13.0+
- Apple Silicon 或 Intel（当前构建脚本默认 arm64，可改 `TARGET`）

## 构建与运行

```bash
./scripts/build.sh
open build/CollapseIcons.app
```

或一键：

```bash
./scripts/run.sh
```

依赖：Command Line Tools（`xcode-select --install`）或完整 Xcode。

## 使用方法

1. 启动应用后，菜单栏会出现 **分隔符 `|`** 和 **折叠按钮 ▶**
2. 按住 **`⌘`** 拖动图标，调整顺序（从左到右）：

   ```
   [可折叠图标…]  |  [始终可见图标…]  ▶
   ```

3. 点击 **▶** → 分隔符左侧图标被折叠
4. 再点一次 → 展开
5. **Option + 点击** → 显示/隐藏分隔符与永久隐藏区（可在设置里改）
6. 右键折叠按钮或分隔符 → 快捷菜单

### 永久隐藏区

设置 → 行为 → 启用「永久隐藏区」后会出现第二个分隔符。  
其左侧图标默认始终隐藏，只有 Option+点击（或你配置的动作）才会临时显示。

## 设置说明

| 分类 | 选项 |
|------|------|
| 通用 | 登录启动、启动显示设置、启动即折叠、全局快捷键 |
| 行为 | 自动折叠延迟、悬停展开、永久隐藏区、点击动作映射 |
| 外观 | 折叠按钮 SF Symbol 样式、分隔符粗细、折叠后隐藏按钮 |

## 项目结构

```
CollapseIcons/
├── Sources/CollapseIcons/
│   ├── main.swift
│   ├── AppDelegate.swift
│   ├── AppSettings.swift
│   ├── StatusBarController.swift   # 核心折叠引擎
│   ├── IconFactory.swift
│   └── Settings/                   # SwiftUI 设置界面
├── Resources/Info.plist
├── scripts/build.sh
└── README.md
```


## 刘海屏适配

在带刘海 / 摄像头岛的 MacBook 上：

1. **安全区检测**：`safeAreaInsets` + `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`
2. **右侧折叠**：隐藏图标收在刘海右侧状态区，不挤进摄像头后面
3. **跳到另一侧展开**：点击折叠按钮后，隐藏图标出现在**刘海左侧**同一条菜单栏上（不是下方弹层）
4. **溢出自动折叠**：图标顶到刘海时自动收起
5. 设置 → 行为 →「刘海 / 安全区」可开关；也可右键折叠按钮切换

外接无刘海屏会自动用经典右侧菜单栏展开。

## 原理

macOS 菜单栏图标按 `NSStatusItem` 从右往左排布。  
把某个 status item 的 `length` 拉得很大，右侧（视觉上分隔符左侧）的图标就会被挤出屏幕——这是 Hidden Bar 等同类型工具的成熟做法。本应用在此基础上增加了更丰富的自定义层。

## 许可

MIT
