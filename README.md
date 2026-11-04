# 一加 Ace 5 Pro (PKR110) TWRP 编译套件

## 先纠正一个前提

你给的参考仓库 `WASDDestroy/android_device_TB710FU_recovery` 是**联想 TB710FU 平板**的设备树，虽然同为高通 SM8750 平台，但两者的分区布局、触摸 IC、解密链路、A/B 结构完全不同，照它改等于重写一遍，而且没有现成的内核 cmdline、fstab、KeyMint 配置可抄。

**PKR110 已经有验证过的设备树**：

| 项 | 值 |
|---|---|
| 机型 | OnePlus Ace 5 Pro（国行） |
| 型号 | PKR110 |
| 平台 | Snapdragon 8 Elite（SM8750） |
| 内部代号 | hummer / OP60EBL1 |
| 系统分支 | ColorOS 16 / Android 16 |
| 设备树 | [`kmiit/android_device_oneplus_hummer-TWRP`](https://github.com/kmiit/android_device_oneplus_hummer-TWRP) |
| 源码清单 | [`TWRP-Test/platform_manifest_twrp_aosp`](https://github.com/TWRP-Test/platform_manifest_twrp_aosp) `twrp-16.0` |

本套件就是按这套组合做的一键编译，没有从零造轮子——重写设备树的收益为零，风险全是你的手机承担。

## 我这边为什么没直接给你 recovery.img

TWRP 编译需要同步约 **60~90GB** 源码，产出需要 **180~200GB** 磁盘，单次编译 1~4 小时。我运行环境到 GitHub 的带宽只有每秒几 KB（拉单个 5KB 文件要等一分钟），同步这套源码不可能完成。

所以交付的是**可直接执行的编译套件**，两条路选一条，都能拿到 `recovery.img`。

## 目录

```
PKR110_TWRP/
├── build.sh                        # 本地 Ubuntu 一键编译
├── .github/workflows/build.yml     # GitHub Actions 云端编译（无需本地环境）
└── README.md
```

## 方式一：GitHub Actions（推荐，零环境成本）

1. 在 GitHub 新建一个空仓库，把本目录整个 push 上去
2. 进 **Actions** → 左侧 `Build TWRP for OnePlus Ace 5 Pro (PKR110)` → **Run workflow**
3. 等 2~5 小时（跑完会邮件通知）
4. 在运行记录的 **Artifacts** 里下载 `recovery-PKR110.zip`，解压得到 `recovery.img`

免费额度够用：公开仓库的 Actions 不计分钟数。`ubuntu-24.04` runner 默认磁盘吃紧，workflow 里已加「释放磁盘空间」步骤（删掉 dotnet / 预装 Android SDK 等约 25GB）。

注意：`repo sync` 阶段如果超时，重跑一次即可，`repo` 会断点续传。

## 方式二：本地 Ubuntu

```bash
chmod +x build.sh
bash build.sh            # 装依赖 → 同步源码 → 编译，全自动
```

分步执行：

```bash
bash build.sh deps       # 装依赖（需要 sudo）
bash build.sh sync       # repo init + sync + 拉设备树
bash build.sh build      # 编译
bash build.sh clean      # 清 out/
```

| 要求 | 说明 |
|---|---|
| 系统 | Ubuntu 22.04 / 24.04（Windows 需 WSL2，且必须放在 ext4 分区，不能放 `/mnt/c`） |
| 内存 | ≥16GB，8GB 需要加 32GB swap |
| 磁盘 | ≥200GB 空闲 |
| 网络 | 能稳定访问 GitHub / Google 源，建议挂代理 |
| 时间 | 首次 2~4 小时，之后增量 20~40 分钟 |

产物：`~/twrp/recovery-PKR110-<时间戳>.img`

## 刷入之前：先备份原厂 recovery

这一步别省。刷坏了没有备份就只能靠 9008 线刷包救。

```bash
adb shell su -c "dd if=/dev/block/by-name/recovery of=/sdcard/recovery_orig.img"
adb pull /sdcard/recovery_orig.img
```

A/B 机型要确认当前槽位：

```bash
adb shell getprop ro.boot.slot_suffix    # 输出 _a 或 _b
```

## 刷入

```bash
adb reboot bootloader

# 单分区机型
fastboot flash recovery recovery.img

# A/B 机型（两个槽都刷，避免切换槽位后失效）
fastboot flash recovery_a recovery.img
fastboot flash recovery_b recovery.img

fastboot reboot recovery
```

进不去就按住 **音量下 + 电源** 手动进 recovery。

## 出问题怎么救

| 现象 | 处理 |
|---|---|
| 卡在开机 logo | `fastboot flash recovery recovery_orig.img` 后重启 |
| 刷入报 `FAILED (remote: 'Partition not found')` | 说明该机没有独立 recovery 分区，改用 `fastboot flash boot`（先备份 boot） |
| 进 TWRP 后触摸无反应 | 音量键 + 电源键操作，这是该设备树的已知问题 |
| 读不到 /data | 首次进入需在 TWRP 里格式化 data（会清空数据），或改用 sideload |
| 系统启动后 OTA 失败 | OTA 会校验 recovery，属于预期，OTA 前刷回原厂 recovery |

## 这个设备树的已知状态

| 功能 | 状态 |
|---|---|
| ADB / MTP / Sideload | ✅ |
| 显示（120Hz AMOLED） | ✅ |
| 触摸 | ✅（fastbootd 模式下触摸不可用，用音量键） |
| 解密 /data | ✅（KeyMint + Gatekeeper，依赖 prepdecrypt.sh） |
| 刷机 / 备份 / 挂载 | ✅ |
| A/B 槽位切换 | ✅ |
| USB OTG / 振动 | ✅ |

`TW_DEVICE_VERSION` 目前是 `OnePlus_ACE5_PRO-A15`，想改成自己的标识直接改设备树里的 `BoardConfig.mk`。

## 和你之前改的 DTBO 的关系

互不影响。TWRP 装在 `recovery` 分区，144Hz 的时序在 `dtbo` 分区，刷 TWRP 不会动 dtbo，也不会影响你现在的显示状态。反过来，将来刷回原厂 dtbo 也不会影响 TWRP。

唯一交集：如果在 TWRP 里做「全盘备份/恢复」，注意别把 `dtbo` 一起恢复成旧版本，否则 144Hz 的时序会被覆盖。

## 想改设备树怎么办

编译前把设备树换成你自己的 fork：

```bash
cd ~/twrp/device/OnePlus/PKR110
# 改完提交到自己的仓库，再修改 build.sh 里的 DEVICE_TREE 变量
```

常用的几个可改项：

| 变量 | 位置 | 作用 |
|---|---|---|
| `TW_THEME` | BoardConfig.mk | 主题分辨率，`portrait_hdpi` 适配 1264×2780 |
| `TW_DEFAULT_LANGUAGE` | BoardConfig.mk | 默认语言，已设 `zh_CN` |
| `TW_MAX_BRIGHTNESS` | BoardConfig.mk | 亮度上限，当前 2047 |
| `TARGET_OTA_ASSERT_DEVICE` | twrp_PKR110.mk | 卡刷包机型校验，当前 `PKR110,OP60EBL1` |
