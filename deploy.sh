#!/bin/bash
# Finnegens, Inc. 官网部署脚本（增量、可回滚；不触碰既有站点文件）
TS=$(date +%Y%m%d-%H%M%S)
BASE=https://raw.githubusercontent.com/danomei2023/finnegans-relay/main
ROOT=/usr/share/caddy/finnegens
say() { echo "== $* =="; }

say "1 download site package"
curl -sL --max-time 120 -o /tmp/finnegens_site.tar.gz "$BASE/finnegens_site.tar.gz?t=$(date +%s)"
ls -la /tmp/finnegens_site.tar.gz

say "2 extract into NEW dir $ROOT (existing site files untouched)"
mkdir -p "$ROOT"
tar xzf /tmp/finnegens_site.tar.gz -C "$ROOT"
ls -1 "$ROOT" | head -30

say "3 backup Caddyfile"
cp /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.bak-$TS"
echo "backup -> /etc/caddy/Caddyfile.bak-$TS"

say "4 install site block (idempotent)"
curl -sL --max-time 60 -o /tmp/finnegens.caddy "$BASE/finnegens.caddy"
if grep -q "finnegens.com" /etc/caddy/Caddyfile; then
  echo "finnegens.com block already present - skip append"
else
  cat /tmp/finnegens.caddy >> /etc/caddy/Caddyfile
  echo "appended finnegens.caddy"
fi

say "5 validate + reload"
CADDY=$(command -v caddy || echo /usr/bin/caddy)
if "$CADDY" validate --config /etc/caddy/Caddyfile --adapter caddyfile > /tmp/caddy_val.log 2>&1; then
  echo "VALID"; tail -2 /tmp/caddy_val.log
  systemctl reload caddy && echo "RELOADED"
else
  echo "INVALID - RESTORING BACKUP"
  cat /tmp/caddy_val.log | tail -10
  cp "/etc/caddy/Caddyfile.bak-$TS" /etc/caddy/Caddyfile
  systemctl reload caddy && echo "RESTORED+RELOADED"
fi

say "6 Caddyfile tail"
tail -12 /etc/caddy/Caddyfile

say "7 local serve check (Host: finnegens.com)"
curl -s -o /dev/null -w "status=%{http_code}\n" -H "Host: finnegens.com" http://127.0.0.1/index.html
curl -s -H "Host: finnegens.com" http://127.0.0.1/index.html | head -c 120; echo
echo DEPLOY_SCRIPT_DONE
