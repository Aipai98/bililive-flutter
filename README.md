# biliLive Tools — Mobile (iOS PWA → IPA)

把 biliLive-tools 的录制与任务队列控件搬到手机上，用 **Capacitor** 包成 iOS App，
再用 **GitHub Actions** 直接在 CI 里跑出 IPA，下载或发布到 Releases。

> 当前默认只内置「**录制界面**」与「**任务队列**」两个核心页，本地模式（localStorage）
> 可独立使用，点右上角「未连接」可填入你部署好的 biliLive-tools 服务端地址。

---

## 目录结构

```
biliLive-tools/
├── mobile/                       ← 这个目录的全部内容
│   ├── www/                      ← 网页端源码（HTML/CSS/JS）
│   ├── capacitor.config.ts       ← Capacitor 配置
│   ├── capacitor.config.json
│   ├── package.json
│   ├── tsconfig.json
│   └── .gitignore
└── .github/
    └── workflows/
        └── build-ipa.yml         ← 打包 IPA 的工作流
```

> 如果你只想把移动端整体作为子目录并入现有仓库 `renmu123/biliLive-tools`，把本目录直接
> 复制为 `mobile/` 即可。如果想独立成一个新的 `bililive-mobile` 仓库也可，
> GitHub Actions 会自动识别路径。

---

## 一次性部署步骤

### 1. 把 `mobile/` 与 workflow 上传到你的 GitHub 仓库

推荐方式：把本目录所有内容复制进 [renmu123/biliLive-tools](https://github.com/renmu123/biliLive-tools)
仓库的根目录或 `mobile/` 子目录，**并把 `.github/workflows/build-ipa.yml` 放到仓库根目录
的 `.github/workflows/`**（GitHub 只会识别根目录下的 workflow）。

常用做法（在你本机已完成 clone 的前提下）：

```bash
git clone https://github.com/renmu123/biliLive-tools.git
cd biliLive-tools

# 把解压后的 mobile/ 目录拷贝进来
cp -R /path/to/biliLive-mobile/. mobile/

# 把 workflow 提升到根目录
mkdir -p .github/workflows
cp mobile/.github/workflows/build-ipa.yml .github/workflows/build-ipa.yml
# 如果 mobile/ 下也有 .github/，可以选择删除它，避免重复触发

git add .
git commit -m "feat(mobile): add iOS PWA + IPA build workflow"
git push origin main
```

### 2. （可选）配置 Apple 签名密钥

默认 workflow 是 **ad-hoc 签名**（免证书，仅供个人设备或开发自测）。
若要发布到 App Store / TestFlight，先准备：

- Apple Developer Account + iOS Distribution 证书（.p12）
- App ID `io.bililive.mobile` 的 Provisioning Profile
- 团队 ID（10 位）

然后到 **GitHub → Settings → Secrets and variables → Actions** 注入以下密钥：

| Secret name | 来源 |
| --- | --- |
| `APPLE_CERT_BASE64` | `base64 -i Certificates.p12`（含换行） |
| `APPLE_CERT_PASSWORD` | p12 密码 |
| `APPLE_PROVISION_BASE64` | `base64 -i xxx.mobileprovision` |
| `APPLE_TEAM_ID` | 10 位团队 ID |
| `KEYCHAIN_PASSWORD` | 任意强密码，用于临时 keychain |

之后手动触发 workflow：选择 `signing = appstore`，`，`upload = true`，再打 `v*.*.*` tag
即可触发 Release 上传。

### 3. 触发 IPA 构建

- **自动**：push 到 `main` 分支（仅 `mobile/**` 等路径变更）会自动构建
- **手动**：Actions → Build iOS IPA → Run workflow → 选签名模式
- **发布**：本地执行 `git tag v0.1.0 && git push origin v0.1.0`，workflow 会自动创建带 IPA 的 Release

构建产物的 IPA 文件会在以下位置：

- **每个 workflow run 的 Artifacts 区域**（默认保留 14 天）
- **GitHub Releases**（仅当上传开关打开）

---

## 本地开发 / 自测

不需要 Mac 也可调试：

```bash
cd mobile
npm install
npx serve www       # 用任意静态服务器，浏览器访问 http://localhost:3000 即可
```

需要 Mac 来跑 iOS 模拟器：

```bash
cd mobile
npm install
npx cap add ios
npx cap sync ios
npx cap open ios     # 会用 Xcode 打开 ios/App/App.xcworkspace
```

Xcode 中选任意模拟器或真机，点 Run 即可（首次会要求选 development team）。

---

## 任务队列 / 录制界面如何与后端联动

当前 mobile 用 `www/app.js` 中的 `enqueue` / `simulateProgress` 做演示进度的本地模拟。
实际接入 biliLive-tools 服务时建议：

1. 替换 `simulateProgress` 为真实的 `fetch('/api/queue/add', { method: 'POST', body: ... })`
2. 列表渲染改为轮询 `/api/queue` 或建立 WebSocket（`@capacitor/network` 检测断线重连）
3. 服务端鉴权 cookie / token 用 `@capacitor/preferences` 持久化
4. 「长任务进度」走 SSE 更省电

参考的 REST 端点草案：

```http
POST /api/queue
{ "room": "live.bilibili.com/123", "quality": "蓝光 8M", "format": "flv", "savePath": "./recordings", "autoSplit": true, "splitSize": 2 }

GET  /api/queue                → Task[]
POST /api/queue/:id/priority   { "dir": "up" | "down" }
DELETE /api/queue/:id
POST /api/queue/:id/retry
```

任务状态机字段保持现状：`waiting / running / done / failed`，再加一个 `progress` (0–100)。

---

## 已知限制

- ad-hoc 签名版本有效期 90 天，需重新构建
- Apple 自 2024 起要求新 App 必须用 Xcode 15+ 构建，已使用 `macos-14` + `setup-node@v4`
- Capacitor 6 默认 Target iOS 13.0；若 App Store Connect 警告过旧，可改 App 中 iOS Deployment Target
