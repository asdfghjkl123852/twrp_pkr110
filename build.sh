#!/usr/bin/env bash
# PKR110（OnePlus Ace 5 Pro）TWRP 编译
#   bash build.sh          装依赖 + 同步 + 编译
#   bash build.sh deps     只装依赖
#   bash build.sh sync     只同步源码
#   bash build.sh build    只编译
#   bash build.sh clean    清 out/
set -euo pipefail

WORKDIR="${WORKDIR:-$HOME/twrp}"
MANIFEST="https://github.com/kmiit/platform_manifest_twrp_aosp"
BRANCH="twrp-14"
DEVICE_TREE="https://github.com/kmiit/android_device_oneplus_hummer-TWRP"
DEVICE_BRANCH="twrp-14"
DEVICE_PATH="device/OnePlus/PKR110"
LUNCH_TARGET="twrp_PKR110-ap2a-eng"
JOBS="$(nproc)"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\n[错误] %s\n' "$*" >&2; exit 1; }

install_deps() {
  log "装依赖"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends \
    bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
    git git-lfs gnupg gperf imagemagick lib32readline-dev lib32z1-dev \
    libelf-dev liblz4-tool libsdl1.2-dev libssl-dev libxml2 libxml2-utils \
    lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev \
    python3 python-is-python3 openjdk-21-jdk-headless
  mkdir -p "$HOME/bin"
  curl -s https://storage.googleapis.com/git-repo-downloads/repo > "$HOME/bin/repo"
  chmod a+x "$HOME/bin/repo"
  case ":$PATH:" in *":$HOME/bin:"*) ;; *) export PATH="$HOME/bin:$PATH" ;; esac
}

check_env() {
  local avail mem
  avail=$(df -BG --output=avail "$(dirname "$WORKDIR")" 2>/dev/null | tail -1 | tr -dc '0-9')
  mem=$(awk '/MemTotal/{printf "%d", $2/1024/1024}' /proc/meminfo)
  log "磁盘 ${avail}GB，内存 ${mem}GB"
  [ "${avail:-0}" -ge 180 ] || die "磁盘不够，源码加输出要 180GB 以上"
  [ "${mem:-0}" -ge 15 ] || log "内存低于 16GB，soong 可能被 OOM 杀，建议先加 swap"
  [ -d /usr/lib/jvm/java-21-openjdk-amd64 ] || die "缺 JDK 21，Ubuntu 22.04 的仓库里没有，换 24.04"
}

sync_source() {
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"
  if [ ! -d .repo ]; then
    log "repo init $BRANCH"
    repo init --depth=1 -u "$MANIFEST" -b "$BRANCH" --no-clone-bundle
  fi
  log "repo sync"
  repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags

  if [ ! -d "$DEVICE_PATH" ]; then
    log "拉设备树"
    git clone --depth=1 -b "$DEVICE_BRANCH" "$DEVICE_TREE" "$DEVICE_PATH"
  fi
}

build() {
  cd "$WORKDIR"
  [ -f build/envsetup.sh ] || die "源码不全，先 bash build.sh sync"
  [ -d "$DEVICE_PATH" ] || die "缺设备树 $DEVICE_PATH"

  log "编译 $LUNCH_TARGET"
  export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
  export PATH="$JAVA_HOME/bin:$PATH"
  export ALLOW_MISSING_DEPENDENCIES=true
  export LC_ALL=C
  export USE_CCACHE=1
  export CCACHE_EXEC="$(command -v ccache || echo /usr/bin/ccache)"
  ccache -M 50G >/dev/null 2>&1 || true

  # shellcheck disable=SC1091
  source build/envsetup.sh
  lunch "$LUNCH_TARGET"
  m recoveryimage -j"$JOBS"

  local img="out/target/product/PKR110/recovery.img"
  [ -f "$img" ] || die "没生成 $img"
  cp "$img" "$WORKDIR/recovery-PKR110-$(date +%Y%m%d-%H%M).img"
  ls -lh "$WORKDIR"/recovery-PKR110-*.img | tail -1
}

case "${1:-all}" in
  deps)  install_deps ;;
  sync)  check_env; sync_source ;;
  build) build ;;
  clean) cd "$WORKDIR" 2>/dev/null && rm -rf out && log "清了 out/" ;;
  all)   install_deps; check_env; sync_source; build ;;
  *)     die "参数不认识：$1（可用 deps / sync / build / clean / all）" ;;
esac
