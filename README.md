# ADB设备管理器 (ADBManager-For-Mac)

这是一个使用Swift和SwiftUI开发的macOS应用程序，用于通过ADB（Android Debug Bridge）管理安卓设备。该工具为开发者和测试人员提供了一个直观的图形界面，简化了Android设备管理过程。

![ADBManager-For-Mac](https://img.shields.io/badge/平台-macOS-blue)
![Swift](https://img.shields.io/badge/语言-Swift%205-orange)
![License](https://img.shields.io/badge/许可证-MIT-green)

## 🚀 功能特点

- **设备连接管理**
  - 自动检测并列出已连接的安卓设备（USB和网络设备）
  - 支持通过IP地址连接网络设备（无线调试）
  - 一键断开连接设备

- **应用管理**
  - 安装APK文件（支持拖放操作）
  - 卸载应用程序
  - 查看设备上已安装的应用程序列表
  - 应用信息查看

- **实用设备操作**
  - 截图并保存到本地
  - 重启设备（普通重启/进入Recovery/进入Bootloader）
  - 打开交互式shell
  - 实时查看设备日志
  - 文件传输

- **设备信息**
  - 设备ID
  - 型号和制造商
  - Android版本
  - 系统属性查看
  - 电池状态监控

- **开发工具**
  - 一键清除应用数据
  - Logcat过滤器
  - ADB命令执行界面

## 📋 使用说明

### 系统要求
- macOS 10.15 (Catalina) 或更高版本
- 已安装ADB工具

### 安装ADB
如果您尚未安装ADB，可以通过以下方式安装：

使用Homebrew：
```bash
brew install android-platform-tools
```

或者通过Android Studio安装Android SDK，ADB工具位于SDK的platform-tools目录下。

### 连接设备
1. **USB连接**：使用USB线将安卓设备连接到Mac电脑，确保设备已开启USB调试模式
2. **网络连接**：点击"连接网络设备"按钮，输入设备的IP地址和端口号（设备需开启无线调试）

## 🔧 编译与安装

### 下载与编译

1. 克隆仓库：
```bash
git clone https://github.com/zeroyearn/ADBManager-For-Mac.git
cd ADBManager-For-Mac
```

2. 使用Xcode打开项目并编译运行，或使用命令行：
```bash
swift build
```

3. 运行程序：
```bash
./.build/debug/ADBManager
```

### 直接下载

您也可以从[Releases页面](https://github.com/zeroyearn/ADBManager-For-Mac/releases)下载预编译的应用程序。

## 💡 使用提示

- 首次启动时，应用程序会自动检测ADB路径。如果检测失败，您可以手动设置路径
- 对于网络连接的设备，确保设备和计算机在同一网络下
- 应用截图功能支持多种格式导出（PNG/JPG/PDF）
- 右键点击设备列表中的设备可以显示更多操作选项

## 🛠️ 开发技术

- Swift 5.x
- SwiftUI
- ADB命令行工具

## 📝 参与贡献

欢迎提交问题报告和功能请求！如果您想贡献代码：

1. Fork 项目
2. 创建您的特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交您的更改 (`git commit -m '添加了一些很棒的特性'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建一个Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📞 联系方式

- GitHub: [@zeroyearn](https://github.com/zeroyearn)
- 电子邮件: i@34.ci

---

**注意**：ADBManager-For-Mac 是一个独立项目，不隶属于Google或Android。Android是Google LLC的商标。 
