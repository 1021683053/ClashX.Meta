# ClashX.Meta 开发者手册

本文档提供 ClashX.Meta 项目的技术说明，包括项目结构、关键文件和核心方法说明。

---

## 目录

1. [项目概述](#项目概述)
2. [项目结构](#项目结构)
3. [构建与运行](#构建与运行)
4. [核心架构](#核心架构)
5. [关键文件说明](#关键文件说明)
6. [核心方法说明](#核心方法说明)
7. [XPC 协议接口](#xpc-协议接口)

---

## 项目概述

ClashX.Meta 是一个基于 [Clash Meta (mihomo)](https://github.com/MetaCubeX/Clash.Meta) 的 macOS 菜单栏代理客户端。

**主要特性：**
- Clash Meta 内核支持
- Tun 模式支持
- 系统代理自动配置
- 远程配置订阅
- iCloud 配置同步
- AppleScript 自动化支持

---

## 项目结构

```
ClashX.Meta/
├── ClashX/                          # 主应用源码
│   ├── AppDelegate.swift            # 应用入口和生命周期管理
│   ├── General/
│   │   ├── ApiRequest.swift         # Clash API 请求封装
│   │   ├── ClashProcess.swift       # Clash 内核进程管理
│   │   └── Managers/                # 各功能管理器
│   │       ├── ConfigManager.swift           # 配置状态管理
│   │       ├── SystemProxyManager.swift      # 系统代理管理
│   │       ├── PrivilegedHelperManager.swift # 特权助手通信
│   │       ├── RemoteConfigManager.swift     # 远程配置管理
│   │       ├── ConfigFileManager.swift       # 配置文件管理
│   │       ├── ICloudManager.swift           # iCloud 同步
│   │       ├── MenuItemFactory.swift         # 菜单项生成
│   │       └── ...
│   ├── Dashboard/                   # SwiftUI 仪表盘界面
│   ├── ViewControllers/             # AppKit 视图控制器
│   ├── Models/                      # 数据模型
│   ├── Views/                       # 自定义视图
│   └── Resources/                   # 资源文件（内核、geo数据、dashboard）
│
├── ProxyConfigHelper/               # 特权助手守护进程
│   ├── main.swift                   # 助手入口
│   ├── ProxyConfigHelper.swift      # XPC 服务实现
│   ├── ProxyConfigRemoteProcessProtocol.swift  # XPC 协议定义
│   ├── MetaTask.swift               # 内核进程生命周期管理
│   ├── MetaServer.swift             # 内核配置数据结构
│   └── MetaDNS.swift                # DNS 相关功能
│
├── ClashX.xcodeproj/                # Xcode 项目文件
├── install_dependency.sh            # 依赖安装脚本
├── SMJobBlessUtil.py                # 助手安装工具
└── .swiftlint.yml                   # SwiftLint 配置
```

---

## 构建与运行

### 环境要求
- Xcode
- Go（用于编译内核，脚本默认下载预编译版本）
- Python 3（用于辅助脚本）

### 安装依赖
```bash
bash install_dependency.sh
```

此脚本会：
1. 下载最新的 mihomo (Clash Meta) arm64 二进制文件
2. 更新 `ClashX/AppDelegate.swift` 中的 MD5 校验值（第19行）
3. 下载 geo 数据文件（country.mmdb, geosite.dat, geoip.dat）
4. 下载 zashboard Web 仪表盘

### 构建
在 Xcode 中打开 `ClashX.xcodeproj` 进行构建。应用名称为 "ClashX Meta"。

### 代码检查
```bash
swiftlint
```

---

## 核心架构

### 双进程模型

ClashX.Meta 采用特权助手架构：

```
┌─────────────────────────────────────────────────────────────┐
│                    ClashX Meta (主应用)                       │
│  - 菜单栏界面                                                  │
│  - 配置管理                                                    │
│  - API 请求                                                   │
└───────────────────────┬─────────────────────────────────────┘
                        │ NSXPCConnection
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              ProxyConfigHelper (特权助手守护进程)               │
│  - 系统代理设置（需要 root 权限）                               │
│  - Tun 接口管理                                               │
│  - 运行 mihomo 进程                                           │
└─────────────────────────────────────────────────────────────┘
```

### 依赖库（通过 SPM 管理）
| 库名 | 用途 |
|------|------|
| RxSwift/RxCocoa | UI 响应式绑定 |
| Alamofire | HTTP 网络请求 |
| SwiftyJSON | JSON 解析 |
| Yams | YAML 配置解析 |
| Starscream | WebSocket（用于 Clash API 流式数据） |
| PromiseKit | 异步流程控制 |
| KeyboardShortcuts | 全局快捷键 |

---

## 关键文件说明

### 1. AppDelegate.swift
**位置：** `ClashX/AppDelegate.swift`

应用程序入口和核心控制器，负责：
- 菜单栏状态图标管理
- 应用生命周期处理
- 代理模式切换
- 配置更新触发
- URL Scheme 处理

**主要属性：**
| 属性 | 类型 | 说明 |
|------|------|------|
| `statusItem` | NSStatusItem | 菜单栏状态项 |
| `clashProcess` | ClashProcess | Clash 内核进程管理器 |
| `disposeBag` | DisposeBag | RxSwift 订阅管理 |

---

### 2. ClashProcess.swift
**位置：** `ClashX/General/ClashProcess.swift`

管理 Clash Meta 内核的启动、验证和生命周期。

**核心状态机 (`CoreState`)：**
```
stopped → checkingHelper → helperReady → starting → running
                ↓
           startFailed
```

---

### 3. ConfigManager.swift
**位置：** `ClashX/General/Managers/ConfigManager.swift`

全局配置状态管理（单例模式）。

**主要属性：**
| 属性 | 说明 |
|------|------|
| `apiPort` | Clash API 端口 |
| `apiSecret` | Clash API 密钥 |
| `isRunning` | 内核运行状态 |
| `currentConfig` | 当前 Clash 配置 |
| `proxyPortAutoSet` | 是否自动设置系统代理 |
| `isTunModeVariable` | Tun 模式状态 |

**静态属性：**
| 属性 | 说明 |
|------|------|
| `selectConfigName` | 当前选中的配置文件名 |
| `selectOutBoundMode` | 出站模式（rule/global/direct） |
| `allowConnectFromLan` | 是否允许局域网连接 |
| `selectLoggingApiLevel` | 日志级别 |

---

### 4. PrivilegedHelperManager.swift
**位置：** `ClashX/General/Managers/PrivilegedHelperManager.swift`

管理与特权助手守护进程的 XPC 通信（单例模式）。

**助手状态 (`HelperStatus`)：**
- `installed` - 已安装且版本匹配
- `noFound` - 未找到助手
- `needUpdate` - 需要更新

---

### 5. SystemProxyManager.swift
**位置：** `ClashX/General/Managers/SystemProxyManager.swift`

管理 macOS 系统代理设置（单例模式）。

---

### 6. ApiRequest.swift
**位置：** `ClashX/General/ApiRequest.swift`

封装与 Clash RESTful API 的所有通信。

---

### 7. RemoteConfigManager.swift
**位置：** `ClashX/General/Managers/RemoteConfigManager.swift`

管理远程配置订阅的下载和自动更新（单例模式）。

---

### 8. ProxyConfigRemoteProcessProtocol.swift
**位置：** `ProxyConfigHelper/ProxyConfigRemoteProcessProtocol.swift`

定义主应用与特权助手之间的 XPC 通信协议。

---

### 9. MetaTask.swift
**位置：** `ProxyConfigHelper/MetaTask.swift`

在特权助手中管理 mihomo 进程的启动、监控和停止。

---

## 核心方法说明

### AppDelegate 核心方法

| 方法 | 说明 |
|------|------|
| `applicationDidFinishLaunching(_:)` | 应用启动入口，初始化菜单栏和核心组件 |
| `postFinishLaunching()` | 延迟初始化，安装助手、加载配置 |
| `startProxyCore()` | 启动 Clash Meta 内核 |
| `updateConfig(configName:showNotification:)` | 更新/重载配置文件 |
| `syncConfig()` | 从 Clash API 同步当前配置状态 |
| `syncConfigWithTun(_:_:)` | 同步配置并更新 Tun 状态 |
| `resetStreamApi()` | 重置 WebSocket 流式 API 连接 |
| `switchProxyMode(mode:)` | 切换代理模式（rule/global/direct） |
| `actionSetSystemProxy(_:)` | 切换系统代理开关 |
| `actionSetTunMode(_:)` | 切换 Tun 模式开关 |
| `actionDashboard(_:)` | 打开仪表盘 |
| `actionSpeedTest(_:)` | 执行节点延迟测试 |
| `updateGEO(_:)` | 更新 GEO 数据库 |
| `flushDNSCache(_:)` | 清空 DNS 缓存 |
| `handleURL(event:reply:)` | 处理 URL Scheme 请求 |

### ClashProcess 核心方法

| 方法 | 说明 |
|------|------|
| `start()` | 启动内核主流程 |
| `checkHelperVersion()` | 验证助手版本是否匹配 |
| `prepareConfigFile()` | 准备配置文件（下载远程配置或复制默认配置） |
| `generateInitConfig()` | 生成初始化配置 |
| `startMeta(_:)` | 通过 XPC 启动 mihomo 进程 |
| `pushInitConfig()` | 推送配置到内核 |
| `verify(_:confFilePath:)` | 验证配置文件格式 |
| `verifyCoreFile(_:)` | 验证内核二进制文件 |

### ConfigManager 核心方法

| 方法 | 说明 |
|------|------|
| `watchCurrentConfigFile()` | 监听当前配置文件变化 |
| `getConfigPath(configName:complete:)` | 获取配置文件路径（支持 iCloud） |
| `getConfigFilesList()` | 获取所有配置文件列表 |

### PrivilegedHelperManager 核心方法

| 方法 | 说明 |
|------|------|
| `checkInstall()` | 检查助手安装状态 |
| `helper(failture:)` | 获取助手 XPC 代理对象 |
| `resetConnection()` | 重置 XPC 连接 |
| `installHelperDaemon()` | 安装助手守护进程 |
| `removeInstallHelper()` | 移除已安装的助手 |

### SystemProxyManager 核心方法

| 方法 | 说明 |
|------|------|
| `enableProxy()` | 启用系统代理 |
| `enableProxy(port:socksPort:)` | 使用指定端口启用系统代理 |
| `disableProxy(forceDisable:complete:)` | 禁用系统代理 |
| `saveProxy()` | 保存当前系统代理设置（用于恢复） |

### ApiRequest 核心方法

| 方法 | 说明 |
|------|------|
| `requestConfig(completeHandler:)` | 获取当前 Clash 配置 |
| `requestConfigUpdate(configName:callback:)` | 请求更新配置文件 |
| `requestVersion(completeHandler:)` | 获取 Clash 版本信息 |
| `updateOutBoundMode(mode:callback:)` | 更新出站模式 |
| `updateAllowLan(allow:callback:)` | 更新局域网访问设置 |
| `updateTun(enable:callback:)` | 更新 Tun 模式状态 |
| `updateGEO(callback:)` | 触发 GEO 数据库更新 |
| `flushDNSCache()` | 清空 DNS 缓存 |
| `getProxyDelay(proxyName:callback:)` | 获取节点延迟 |
| `healthCheck(proxy:callback:)` | 执行健康检查 |
| `updateProxyGroup(group:selectProxy:callback:)` | 更新代理组选择 |
| `getMergedProxyData(callback:)` | 获取合并的代理数据 |
| `getRules(callback:)` | 获取规则列表 |

### RemoteConfigManager 核心方法

| 方法 | 说明 |
|------|------|
| `autoUpdateCheck()` | 自动更新检查 |
| `updateCheck(ignoreTimeLimit:showNotification:)` | 手动更新检查 |
| `updateConfig(config:complete:)` | 更新指定远程配置 |
| `getRemoteConfigData(config:complete:)` | 下载远程配置数据 |
| `verifyConfig(string:)` | 验证配置格式 |
| `saveConfigs()` | 保存远程配置列表 |

### MetaTask 核心方法（特权助手）

| 方法 | 说明 |
|------|------|
| `start(_:confPath:confFilePath:confJSON:result:)` | 启动 mihomo 进程 |
| `stop()` | 停止 mihomo 进程 |
| `killOldProc()` | 终止旧的 mihomo 进程 |
| `getUsedPorts(_:)` | 获取系统已占用端口 |
| `testExternalController(_:)` | 测试 API 控制器是否可用 |

---

## XPC 协议接口

`ProxyConfigRemoteProcessProtocol` 定义了主应用与特权助手之间的通信接口：

| 方法 | 说明 |
|------|------|
| `getVersion(reply:)` | 获取助手版本 |
| `startMeta(path:confPath:confFilePath:confJSON:reply:)` | 启动 Meta 内核 |
| `stopMeta()` | 停止 Meta 内核 |
| `updateTun(state:dns:)` | 更新 Tun 接口状态 |
| `getUsedPorts(reply:)` | 获取已使用的端口 |
| `flushDnsCache()` | 清空 DNS 缓存 |
| `enableProxy(port:socksPort:pac:filterInterface:ignoreList:reply:)` | 启用系统代理 |
| `disableProxy(filterInterface:reply:)` | 禁用系统代理 |
| `restoreProxy(currentPort:socksPort:info:filterInterface:reply:)` | 恢复原有代理设置 |
| `getCurrentProxySetting(reply:)` | 获取当前代理设置 |

---

## 配置存储位置

- **默认配置目录：** `~/.config/clash`
- **配置文件格式：** `{configName}.yaml`
- **iCloud 配置：** 通过 `ICloudManager` 同步

---

## AppleScript 支持

应用支持以下 AppleScript 命令：

```applescript
-- 切换系统代理开关
tell application "ClashX Meta" to toggleProxy

-- 设置代理模式
tell application "ClashX Meta" to proxyMode "global"  -- 或 "direct", "rule"

-- 切换 Tun 模式
tell application "ClashX Meta" to TunMode
```
