# biliLive Flutter App

[biliLive-tools](https://github.com/renmu123/biliLive-tools) 的**真·原生**跨平台手机 App —— 用 Flutter / Dart 写，自绘 UI、自己调后端 API，**不是 WebView 套网页**。一套代码同时出 **Android APK** 和 **iOS IPA**。

App 直连你自己部署的 biliLive-tools 后台，地址与 Passkey 只保存在手机本机、绝不写死进包体、绝不上传。

---

## 功能

底部导航 4 个页面：**主播 / 文件 / 任务队列 / 设置**。

### 主播页
- 卡片列表：封面 + 圆形头像 + 昵称 + 平台徽章（抖音/B站/斗鱼/虎牙/快手）+ 状态胶囊（录制中/直播中/未开播）。
- 操作：**开录 / 停录**、**刷新**（重新拉取该主播状态）、**详情**、齿轮菜单（启用-禁用自动检查 / 删除）。
- **添加主播**：只需粘贴直播间地址（如 `https://live.douyin.com/216792992689`），App 调后端官方解析器 `GET /recorder/manager/resolve` 自动识别平台 + 房间号，无需手填。添加成功有浮动提示。

### 任务队列页
- 拉取后端 `GET /task`，进行中任务优先、其余按开始时间倒序。
- 每条显示：状态徽标、任务全名、进度条 + 百分比、**持续时间**、**预计还需**（按 `duration×(100-进度)/进度` 估算，与后台同逻辑）、比特率/速率（后端 `custsomProgressMsg` 原文）、开始时间（`2026/7/19 13:25:26` 格式）、错误原因。
- 下拉刷新。

### 文件页
- 浏览录制目录（根 = 后端 savePath），emoji 图标区分文件/目录。
- 三点菜单：删除 / 复制路径 / 播放视频（用系统播放器打开 `{baseUrl}/files/download?path=`）。
- 若后端未开启删除权限（`deleteEnabled=false`），自动隐藏删除入口并在顶部提示。

### 设置页
- 连接设置：后台地址 + Passkey（Authorization）。
- 测试连接（自动探测是否需要 `/api` 前缀）+ 保存。
- **登录信息持久化**：首次填好保存后，用 `SharedPreferences` 存本机；**之后每次打开 App 自动恢复并连接，无需再手动进设置点保存**。

---

## 拿安装包

CI 走 **GitHub Actions**（免费的 macOS runner），推代码即自动云端编译，产物在 Actions 的 Artifacts 里下载。你不需要有 Mac。

### iOS IPA（GitHub Actions 自动出包）
1. 把工程推到 GitHub：
   ```bash
   git remote add origin https://github.com/你的名/bililive-flutter.git
   git branch -M main
   git push -u origin main
   ```
   > 注意：classic token 需勾选 `workflow` 权限，否则推 `.github/workflows/` 会被拒（403）。
2. 每次 `git push` 到 `main` 会自动触发 `.github/workflows/build-ios.yml`。
3. 去 **GitHub → Actions → 最新一次 run → Artifacts** 下载 `Runner.ipa`（未签名）。
4. **自签装到 iPhone**（任选）：
   - **AltStore / SideStore**：导入 `Runner.ipa`，用免费 Apple ID 自签（7 天续期）。
   - **爱思助手 / TrollStore（巨魔）**：一键自签安装。

### Android APK
在有 Flutter 环境的机器上：
```bash
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

---

## CI 构建方案说明（build-ios.yml）

在 Windows / 无 Apple 账号环境下产出**未签名** iOS IPA 的稳定配方，踩过很多坑后的最终版：

1. `git clone -b stable https://github.com/flutter/flutter.git` 装 Flutter（`subosito/flutter-action` 在新 runner 已失效）。
2. `flutter precache --ios` + `flutter pub get`。
3. **迁移 Swift Package Manager，移除 CocoaPods**（Flutter 已确认 "All plugins found for ios are Swift Packages"）：删 `ios/{Pods,Podfile,Podfile.lock}`，`sed` 清掉 `Flutter/*.xcconfig` 与 `Runner.xcworkspace` 里的 Pods 引用。
4. `flutter build ios --release --no-codesign --config-only`（无 Podfile → Flutter 自动走 SPM 重新生成工程）。
5. `xcodebuild ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""` 直接编译，**彻底关签名，绕开 Development Team 检查**。
6. 手动打包：把 `Runner.app` 塞进 `Payload/` 后 `zip` 成 `Runner.ipa`（IPA 本质就是 zip），upload-artifact。

> **为什么不用 `flutter build ipa`？** 新版 Flutter stable 给 `flutter build ios --no-codesign` 也加了强制 Development Team 检查；且裸 `xcodebuild` 下 CocoaPods 的 `[CP] Check Pods Manifest.lock` 校验会因缺 Flutter 注入的 env 而误判。迁移 SPM + 裸 `xcodebuild` 关签名一次性规避了这四类坑（team 检查 / pod 同步 / Manifest.lock 校验 / env 缺失）。

---

## 后端接口（biliLive-tools）

- 鉴权头：`Authorization: <passkey>`（设置页填，存本机，不写死进包）。
- 连通性自动探测 `/api` 前缀。
- 用到的路由：`GET /common/version`、`GET /recorder/list`、`GET /recorder/:id`（详情/刷新）、`POST /recorder/add`、`PUT /recorder/:id`、`DELETE /recorder/:id`、`POST /recorder/:id/start_record`|`stop_record`、`GET /recorder/manager/resolve?url=`（地址解析）、`GET /task`（任务队列）、`GET /files/list?path=`、`POST /files/delete`。

> iOS 已在 `Info.plist` 配好 `NSAppTransportSecurity`，允许直连 `http://` 后台。

---

## 目录
```
lib/
  main.dart                       入口：启动即恢复登录 + 底部 4 导航
  models/streamer.dart            主播模型
  models/file_item.dart           文件模型
  services/api_service.dart       后端 API 封装
  pages/streamer_list_page.dart   主播列表（含按地址添加）
  pages/streamer_detail_page.dart 主播详情
  pages/files_page.dart           文件浏览
  pages/task_queue_page.dart      任务队列
  pages/settings_page.dart        连接设置 + 登录持久化
.github/workflows/build-ios.yml   iOS IPA 云端编译（SPM + xcodebuild 关签名）
```
