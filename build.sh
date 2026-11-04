#!/usr/bin/env bash
# =====================================================================
# 一加 Ace 5 Pro (PKR110) — TWRP recovery 一键编译脚本
#
# 平台     : Qualcomm SM8750 (Snapdragon 8 Elite)
# 系统分支 : twrp-16.0（对应 Android 16，与 PKR110_16.x 匹配）
# 设备树   : kmiit/android_device_oneplus_hummer-TWRP
#
# 用法：
#   bash build.sh              # 全流程：装依赖 → 同步源码 → 编译
#   bash build.sh sync         # 只同步源码
#   bash build.sh build        # 只编译（源码已就绪时）
#   bash build.sh clean        # 清理输出
#
# 环境要求：Ubuntu 20.04/22.04，≥16GB 内存（推荐 32GB），≥200GB 空闲磁盘
# =====================================================================
set -euo pipefail

WORKDIR="${WORKDIR:-$HOME/twrp}"
MANIFEST="https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git"
BRANCH="twrp-16.0"
DEVICE_TREE="https://github.com/kmiit/android_device_oneplus_hummer-TWRP"
DEVICE_PATH="device/OnePlus/PKR110"
LUNCH_TARGET="twrp_PKR110-bp2a-eng"
JOBS="$(nproc)"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m[错误] %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 依赖
install_deps() {
  log "安装编译依赖"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends \
    bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
    git git-lfs gnupg gperf imagemagick lib32readline-dev lib32z1-dev \
    libelf-dev liblz4-tool libsdl1.2-dev libssl-dev libxml2 libxml2-utils \
    lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev \
    python3 python-is-python3 openjdk-17-jdk-headless repo
}

# ---------------------------------------------------------------- 空间检查
check_space() {
  local avail
  avail=$(df -BG --output=avail "$(dirname "$WORKDIR")" 2>/dev/null | tail -1 | tr -dc '0-9')
  log "可用磁盘：${avail}GB"
  [ "${avail:-0}" -ge 180 ] || die "磁盘不足 180GB，TWRP-16 源码 + 输出大约需要 180~200GB"
  local mem
  mem=$(awk '/MemTotal/{printf "%d", $2/1024/1024}' /proc/meminfo)
  log "内存：${mem}GB（建议 ≥16GB，8GB 需自行加 swap）"
}

# ---------------------------------------------------------------- 同步源码
sync_source() {
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"
  if [ ! -d .repo ]; then
    log "repo init → $BRANCH"
    repo init --depth=1 -u "$MANIFEST" -b "$BRANCH" --no-clone-bundle
  fi
  log "repo sync（首次约 60~90GB，视网络 1~4 小时）"
  repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags

  if [ ! -d "$DEVICE_PATH" ]; then
    log "拉取 PKR110 设备树"
    git clone --depth=1 "$DEVICE_TREE" "$DEVICE_PATH"
  else
    log "设备树已存在，跳过"
  fi
}

# ---------------------------------------------------------------- 编译
build() {
  cd "$WORKDIR"
  [ -d build/envsetup.sh ] || die "源码不完整，先执行 bash build.sh sync"
  [ -d "$DEVICE_PATH" ] || die "设备树缺失：$DEVICE_PATH"

  log "编译 $LUNCH_TARGET"
  export ALLOW_MISSING_DEPENDENCIES=true
  export LC_ALL=C
  export USE_CCACHE=1
  export CCACHE_EXEC="$(command -v ccache || echo /usr/bin/ccache)"
  ccache -M 50G >/dev/null 2>&1 || true

  # shellcheck disable=SC1091
  source build/envsetup.sh
  lunch "$LUNCH_TARGET"
  mka recoveryimage -j"$JOBS"

  local img="out/target/product/PKR110/recovery.img"
  [ -f "$img" ] || die "编译结束但没有找到 $img，请把上面的报错发出来"
  cp "$img" "$WORKDIR/recovery-PKR110-$(date +%Y%m%d-%H%M).img"
  log "完成：$WORKDIR/recovery-PKR110-*.img"
  ls -lh "$WORKDIR"/recovery-PKR110-*.img | tail -1
}

case "${1:-all}" in
  deps)  install_deps ;;
  sync)  check_space; sync_source ;;
  build) build ;;
  clean) cd "$WORKDIR" 2>/dev/null && rm -rf out && log "已清理 out/" ;;
  all)   install_deps; check_space; sync_source; build ;;
  *)     die "未知参数：$1（可用：deps | sync | build | clean | all）" ;;
esac
