# PKR110 TWRP 编译

OnePlus Ace 5 Pro（PKR110，代号 hummer，SM8750）的 TWRP 编译配置。设备树用现成的，这里只放编译脚本和 CI。

## 用到的组合

- 设备树：`kmiit/android_device_oneplus_hummer-TWRP`，分支 `twrp-14`
- manifest：`kmiit/platform_manifest_twrp_aosp`，分支 `twrp-14`
- lunch：`twrp_PKR110-ap2a-eng`
- JDK 21

## GitHub Actions

push 到 main 会触发，也可以在 Actions 页面手动 Run workflow。实测 53 分钟出包，产物在 Artifacts 里，名字 `recovery-PKR110`。公开仓库不扣分钟数。

构建失败时会额外传一份 `build-logs`。

## 本地编译

Ubuntu 24.04，内存 16 GB 起，磁盘 200 GB。8 GB 内存会 OOM，soong 解析模块图要 10 GB 以上。

```bash
bash build.sh
```

分步：

```bash
bash build.sh deps     # 装依赖
bash build.sh sync     # 同步源码 + 设备树
bash build.sh build    # 编译
bash build.sh clean    # 清 out/
```

产物在 `~/twrp/recovery-PKR110-<时间戳>.img`。

## 产物的结构

100 MB，Android boot image v4，`kernel_size = 0`，只有 ramdisk（42 MB，lz4）。

设备树里 `TARGET_PREBUILT_KERNEL` 指向 `kernel/prebuilts/6.6/arm64/kernel-6.6`，这个文件实际没打进镜像。所以只能刷到只放 ramdisk 的分区，靠 boot 分区里的内核启动。

## 刷入

先确认机器上有没有独立 recovery 分区：

```bash
adb shell su -c "ls /dev/block/by-name | grep -iE 'init_boot|boot|recovery'"
```

有 `recovery_a` / `recovery_b`：

```bash
fastboot flash recovery_a recovery.img
```

只有 `init_boot`：

```bash
fastboot flash init_boot recovery.img
```

刷之前把原来的备份出来：

```bash
adb shell su -c "dd if=/dev/block/by-name/boot of=/sdcard/boot.img"
adb pull /sdcard/boot.img
```

## 已知问题

- fastbootd 模式下触摸不可用，用音量键操作
- 进 recovery 读不到 /data，先格式化 data（会清数据）
- OTA 会校验 recovery，升级前刷回原厂

## 改设备树

`build.sh` 里 `DEVICE_TREE` 换成自己的 fork，或者直接把 `~/twrp/device/OnePlus/PKR110` 改成自己的。

常改的几个：`TW_THEME`、`TW_DEFAULT_LANGUAGE`、`TW_MAX_BRIGHTNESS` 在 `BoardConfig.mk`，`TARGET_OTA_ASSERT_DEVICE` 在 `twrp_PKR110.mk`。

## 和 dtbo 的关系

没关系。TWRP 在 recovery，144Hz 的时序在 dtbo，互不影响。唯一要注意的是别在 TWRP 里把 dtbo 一起恢复成旧版本。
