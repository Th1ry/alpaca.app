# Alpaca Options App

美股期权交易 MVP — Flutter 客户端直连 [Alpaca](https://alpaca.markets/) API，支持 Android / Windows 桌面。API Key **仅保存在用户设备**，仓库内不包含任何密钥。

> **需要大家帮忙找 Bug！** 请在 [Issues](../../issues) 提交问题，模板见下方「如何报 Bug」。

## 功能概览

- 自选、实时行情、K 线（长按十字线 / 双指缩放）
- 正股 / 期权下单、买一卖一、购买力显示
- 持仓、资金、盈亏曲线
- Paper / Live 环境切换，设置页一键测连
- 中文 / 英文界面

## 架构说明

| 平台 | 运行方式 |
|------|----------|
| **Android APK** | App **直连 Alpaca**，无需本地后端 |
| **Windows 桌面** | 同上（`flutter build windows`）；`start_app.bat` 可选启动 Python 后端，**手机版不需要** |

## 快速开始（Android）

### 用户安装

1. 安装 Release APK（见 [Releases](../../releases) 或本地编译）
2. 打开 App → **设置** → 选择 **Paper / Live**
3. 填写 Alpaca **API Key** 与 **Secret** → **保存** 或 **测试连接**
4. 返回首页 / 交易 / 资金即可使用

### 开发者编译

```bash
cd mobile
flutter pub get
flutter build apk --release
# 输出: build/app/outputs/flutter-apk/app-release.apk
```

Windows 下一键打包：`mobile\build_android.bat`

### 环境要求

- Flutter 3.2+（SDK `>=3.2.0 <4.0.0`）
- Android SDK（打 APK）
- Visual Studio 2022（仅 Windows 桌面版）

## Windows 桌面（可选）

```bash
cd mobile
flutter build windows --release
```

根目录 `start_app.bat` 会编译 exe 并可选启动 `backend/`（本地 FastAPI，**Android 不依赖**）。

## 后端（可选，桌面开发）

```bash
cd backend
copy .env.example .env   # 填入 Key，勿提交 .env
py -3 -m pip install -r requirements.txt
py -3 run.py
```

## 如何报 Bug

请 [新建 Issue](../../issues/new)，尽量包含：

1. **平台**：Android 版本 / 手机型号，或 Windows 版本
2. **Alpaca 环境**：Paper 还是 Live（**不要贴 API Key**）
3. **复现步骤**：从打开 App 到出错的完整操作
4. **期望 vs 实际**
5. **截图或报错原文**（可打码账户信息）

常见排查：

- 设置页是否为绿色「已连接」？
- Paper Key 是否配 Paper 环境？
- 首次安装需自行在设置里填写 Key（APK 内**没有**预置密钥）

## 项目结构

```
mobile/          # Flutter 主应用（直连 Alpaca）
backend/         # 可选 Python 后端（桌面开发）
scripts/         # 本地环境安装脚本
```

## 安全说明

- 默认 `apiKey` / `apiSecret` 为空字符串，打包不会带上你的 Key
- 凭证保存在设备 `SharedPreferences`，仅本机可见
- `.env` 已在 `.gitignore`，请勿提交密钥

## License

未指定许可证；如需开源协作请先与仓库所有者确认。
