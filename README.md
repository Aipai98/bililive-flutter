# biliLive Flutter App

biliLive-tools 的**真·原声**跨平台 App（Flutter / Dart 写，**不是 Web 套皮**）。
一套代码同时出 **Android APK** 和 **iOS IPA**。

> ⚠️ 本工程由 Windows 环境的 AI 助手生成，已用 `flutter analyze` 验证 Dart 代码零错误、Android 侧 `flutter build apk` 可编过。
> **iOS 的 `.ipa` 二进制必须在 macOS + Xcode 上产出**（Apple 强制，Windows 无解）。两条路：
> - **方式一（推荐，不用买/借 Mac）**：用 [Codemagic](https://codemagic.io) 免费 macOS 云编译，推代码即出 IPA —— 见下方「方式一」。
> - **方式二**：你自己的 Mac 上 `flutter build ipa --no-codesign` 然后自签 —— 见「方式二」。

---

## 功能（对齐已交付的安卓版）
- **主播页**：横排卡片（小封面 + 封面状态圆点 + 圆形头像 + 昵称 + 平台徽章 + 状态胶囊），操作：开录/停录、检查、**详情（文字链）**、齿轮菜单（编辑/删除）。
- **主播详情**：调 `GET /recorder/:id` 展示配置（平台/房间号/画质/分段/录制引擎/视频格式/自动检查），并扫该主播录制目录 `/app/video/平台/备注` 展示最近录制文件 + 文件数/总大小/最近时间。
- **文件页**：emoji 图标列表，长按或三点菜单 → 删除 / 复制路径 / 播放视频（视频用系统播放器打开 `{baseUrl}/files/download?path=`）。
- **设置页**：连接设置（后台地址 + Passkey）+ 看板（运行时间 + 录制目录已用空间，递归扫 `/app/video` 最深 2 层累加）。
- 已**删除**后处理 tab（与安卓版一致）。

## 后端接口（biliLive-tools，直连 `http://你的地址:端口`）
- 鉴权头：`Authorization: <passkey>`（设置页填，存本机，绝不写死进代码）。
- 连通性自动探测 `/api` 前缀。

---

## 方式一（推荐，无需 Mac）：Codemagic 云端出 IPA

免费额度 500 macOS 分钟/月，不需要信用卡，不需要本地 Mac。

1. **把本工程推到 GitHub**（私库也行）。本目录已 `git init` 并提交，你只需：
   ```bash
   git remote add origin https://github.com/你的名/bililive-flutter.git
   git branch -M main
   git push -u origin main
   ```
2. 打开 https://codemagic.io → 用 GitHub 登录 → **Add application** → 选这个仓库。
3. Codemagic 会自动读到根目录的 `codemagic.yaml`，工作流名 `ios-ipa-unsigned`。直接点 **Start new build**。
4. 云端会自动：`flutter pub get` → `cd ios && pod install` → `flutter build ipa --no-codesign`。约 5–10 分钟。
5. 构建完成在 **Artifacts** 里下载 `Runner.ipa`（未签名）。
6. **自签装到 iPhone**（任选）：
   - **AltStore / SideStore**：把 `Runner.ipa` 导入，用免费 Apple ID 自签（7 天续期）。
   - **爱思助手 / TrollStore（巨魔）**：一键自签安装。

> 整个工程已配好：iOS 的 `Info.plist` 加了 `NSAppTransportSecurity` 允许 http 后台；`ios/Podfile` 已补齐；`codemagic.yaml` 已就绪。你基本是“推上去 → 点一下 → 下载”。

---

## 方式二：在你 Mac 上构建 iOS IPA

### 1. 安装 Flutter
```bash
# 用 fvm 或直接装官方 SDK（需 macOS + Xcode + CocoaPods）
brew install --cask flutter
# 或 git clone flutter 稳定版
flutter doctor   # 按提示装 Xcode 命令行工具 / CocoaPods
```

### 2. 取得本工程并拉依赖
```bash
cd bililive_flutter
flutter pub get
# iOS 还需要安装原生依赖（CocoaPods）
cd ios && pod install && cd ..
```

### 3. iOS 必须改一处：允许 HTTP
后台是 `http://`（非 https），iOS 默认拦截。打开 `ios/Runner/Info.plist` 加：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```
（Android 侧无此限制，无需改。）

### 4. 修改 Bundle ID（重要）
默认 `PRODUCT_BUNDLE_IDENTIFIER` 是 `com.example.bililiveApp`，自签/上架都建议改成你自己的（如 `com.你的名.bililive`）：
- 改 `ios/Runner/Info.plist` 的 `CFBundleIdentifier` 不起作用，要去
  `ios/Runner.xcodeproj/project.pbxproj` 把两处 `PRODUCT_BUNDLE_IDENTIFIER` 改掉；
- 或用 Xcode 打开 `ios/Runner.xcworkspace` 在 Signing 里直接填。

### 5. 构建 IPA（无证书先出包，再自签）
```bash
flutter build ipa --no-codesign
# 产物：build/ios/ipa/Runner.ipa
```

### 6. 自签安装（任选其一）
- **AltStore / Sidestore**：直接把 `.ipa` 导入自签（免费 Apple ID，7 天续期）。
- **爱思助手 / TrollStore**（越狱/巨魔）：一键自签安装。
- 有付费开发者证书则直接在 Xcode 里 `flutter build ios` 后 Archive 签名。

---

## 构建 Android APK（顺手验证 / 给安卓用）
```bash
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```
（Android 也支持：底部导航 3 项主播/文件/设置。）

## 目录
```
lib/
  main.dart                    入口 + 底部导航
  models/streamer.dart        主播模型
  models/file_item.dart       文件模型
  services/api_service.dart   后端 API 封装（对齐安卓 ApiClient）
  pages/streamer_list_page.dart
  pages/streamer_detail_page.dart
  pages/files_page.dart
  pages/settings_page.dart
```
