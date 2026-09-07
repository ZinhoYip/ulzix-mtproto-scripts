#!/bin/sh
set -eu

REPO_URL="https://raw.githubusercontent.com/ZinhoYip/ulzix-mtproto-scripts/main/install.sh"
WORKDIR=${WORKDIR:-/home/mtproxy}
LISTEN_PORT=${LISTEN_PORT:-8443}
PUBLIC_PORT=${PUBLIC_PORT:-}
PUBLIC_IP=${PUBLIC_IP:-}
TLS_DOMAIN=${TLS_DOMAIN:-cloudflare.com}
MTG_VERSION=${MTG_VERSION:-v0.04}
REGENERATE_SECRET=${REGENERATE_SECRET:-0}

info() { printf '\033[1;36m%s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage:
  wget -qO- https://raw.githubusercontent.com/ZinhoYip/ulzix-mtproto-scripts/main/install.sh | sh
  wget -qO- https://raw.githubusercontent.com/ZinhoYip/ulzix-mtproto-scripts/main/install.sh | sh -s -- 54319

The first form asks for the provider's public port. The second form is non-interactive.
The provider must map PUBLIC_PORT -> 8443 before running this installer.
Environment variables: PUBLIC_PORT, PUBLIC_IP, LISTEN_PORT, TLS_DOMAIN, REGENERATE_SECRET.
EOF
}

valid_port() {
    case "$1" in ''|*[!0-9]*) return 1 ;; esac
    [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then usage; exit 0; fi
if [ -n "${1:-}" ]; then PUBLIC_PORT=$1; fi
[ "$(id -u)" -eq 0 ] || fail '请使用 root 用户运行。'

if [ -z "$PUBLIC_PORT" ]; then
    if [ -t 0 ]; then
        printf '请输入服务商分配的公网端口（该端口必须映射到内网 %s）：' "$LISTEN_PORT"
        read -r PUBLIC_PORT
    else
        fail '非交互模式必须提供公网端口，例如：sh -s -- 54319'
    fi
fi
valid_port "$PUBLIC_PORT" || fail "无效的公网端口：$PUBLIC_PORT"
valid_port "$LISTEN_PORT" || fail "无效的内网端口：$LISTEN_PORT"

if [ ! -f /etc/alpine-release ]; then
    fail '此脚本针对 Alpine Linux；当前系统不是 Alpine。'
fi

info '安装运行依赖...'
apk update >/dev/null
apk add --no-cache ca-certificates curl libc6-compat >/dev/null
update-ca-certificates >/dev/null 2>&1 || true

case "$(uname -m)" in
    x86_64) MTG_ASSET=x86_64-mtg ;;
    aarch64) MTG_ASSET=aarch64-mtg ;;
    *) fail "不支持的 CPU 架构：$(uname -m)" ;;
esac

mkdir -p "$WORKDIR/bin"
cd "$WORKDIR"

if [ ! -x bin/mtg ]; then
    info '下载 mtg...'
    curl -fL --retry 3 -o bin/mtg \
        "https://github.com/ellermister/mtproxy/releases/download/${MTG_VERSION}/${MTG_ASSET}"
    chmod 755 bin/mtg
fi

if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(curl -4fsS --max-time 10 https://api.ipify.org) || fail '无法自动获取公网 IPv4，请设置 PUBLIC_IP。'
fi
case "$PUBLIC_IP" in *[!0-9.]*|'') fail "无效的公网 IPv4：$PUBLIC_IP" ;; esac

if [ "$REGENERATE_SECRET" = 1 ] || [ ! -s mtg.secret ]; then
    info '生成 TLS Secret...'
    bin/mtg generate-secret tls -c "$TLS_DOMAIN" > mtg.secret
    chmod 600 mtg.secret
fi
SECRET=$(tr -d '\r\n' < mtg.secret)

info '启动 MTProto...'
killall mtg 2>/dev/null || true
rm -f mtg.log
nohup bin/mtg run -4 "$PUBLIC_IP:$LISTEN_PORT" \
    -b "0.0.0.0:$LISTEN_PORT" "$SECRET" > mtg.log 2>&1 &
MTG_PID=$!
sleep 2
kill -0 "$MTG_PID" 2>/dev/null || { cat mtg.log >&2 || true; fail 'mtg 启动失败。'; }

if [ -d /etc/local.d ]; then
    cat > /etc/local.d/mtproxy.start <<EOF
#!/bin/sh
cd $WORKDIR
killall mtg 2>/dev/null || true
nohup ./bin/mtg run -4 "$PUBLIC_IP:$LISTEN_PORT" -b "0.0.0.0:$LISTEN_PORT" "$SECRET" > mtg.log 2>&1 &
EOF
    chmod 755 /etc/local.d/mtproxy.start
    rc-update add local default >/dev/null 2>&1 || true
fi

TG_LINK="tg://proxy?server=${PUBLIC_IP}&port=${PUBLIC_PORT}&secret=${SECRET}"
HTTPS_LINK="https://t.me/proxy?server=${PUBLIC_IP}&port=${PUBLIC_PORT}&secret=${SECRET}"
printf '\n========================================\n'
printf 'MTProto 部署完成\n'
printf '========================================\n'
printf '公网映射：%s -> %s\n' "$PUBLIC_PORT" "$LISTEN_PORT"
printf 'Secret：%s\n' "$SECRET"
printf 'TG 一键链接：\n%s\n' "$TG_LINK"
printf 'HTTPS 一键链接：\n%s\n' "$HTTPS_LINK"
printf '日志：%s/mtg.log\n' "$WORKDIR"
printf '========================================\n'
