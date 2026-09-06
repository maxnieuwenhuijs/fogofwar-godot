#!/usr/bin/env bash
# F4.4a — draait OP de droplet (als root, via deploy-server.ps1):
#   1. engine-pakket uitpakken in een verse map en importeren (seconden)
#   2. server-bron uitpakken, npm ci + build (.env en node_modules blijven)
#   3. engine wisselen, service herstarten
#   4. wachten tot /gezond antwoordt, /versie tonen
# Gebruik: sudo bash op-droplet-uitrollen.sh [/tmp/serverpakket.tgz] [/tmp/serverbron.tgz]
set -euo pipefail

BASIS=/opt/fogofwar
PAKKET=${1:-/tmp/serverpakket.tgz}
BRON=${2:-/tmp/serverbron.tgz}
GEBRUIKER=fogofwar
THUIS=$BASIS/home
ENV_BESTAND=$BASIS/server/.env

[ -f "$PAKKET" ] || { echo "pakket ontbreekt: $PAKKET"; exit 1; }
[ -f "$BRON" ] || { echo "server-bron ontbreekt: $BRON"; exit 1; }
[ -f "$ENV_BESTAND" ] || { echo "geen $ENV_BESTAND: eerst droplet-setup.sh draaien"; exit 1; }
# shellcheck disable=SC1090
GODOT=$(grep -E '^GODOT_PAD=' "$ENV_BESTAND" | cut -d= -f2-)
POORT=$(grep -E '^POORT=' "$ENV_BESTAND" | cut -d= -f2-)
POORT=${POORT:-8787}
[ -x "$GODOT" ] || { echo "Godot-binary niet uitvoerbaar: $GODOT (GODOT_PAD in .env)"; exit 1; }

echo "== 1. engine-pakket"
rm -rf "$BASIS/engine.nieuw"
mkdir -p "$BASIS/engine.nieuw"
tar -xzf "$PAKKET" -C "$BASIS/engine.nieuw" --strip-components=1
chown -R "$GEBRUIKER:$GEBRUIKER" "$BASIS/engine.nieuw"
# De import als de service-gebruiker (dezelfde die straks de worker draait),
# met een schrijfbare HOME voor user:// van Godot.
if ! sudo -u "$GEBRUIKER" env HOME="$THUIS" FOW_WORKER=1 "$GODOT" --headless --path "$BASIS/engine.nieuw" --import >/tmp/fow-import.log 2>&1; then
  echo "import mislukt:"; tail -n 30 /tmp/fow-import.log; exit 1
fi
if grep -Eq "SCRIPT ERROR|Failed to load|Parse Error" /tmp/fow-import.log; then
  echo "import gaf scriptfouten:"; grep -E "SCRIPT ERROR|Failed to load|Parse Error" /tmp/fow-import.log | head -n 20; exit 1
fi
echo "   import schoon"

echo "== 2. server-code"
mkdir -p "$BASIS/server"
rm -rf "$BASIS/server/src" "$BASIS/server/db" "$BASIS/server/dist"
tar -xzf "$BRON" -C "$BASIS/server"
chown -R "$GEBRUIKER:$GEBRUIKER" "$BASIS/server"
chmod 600 "$ENV_BESTAND"
cd "$BASIS/server"
sudo -u "$GEBRUIKER" env HOME="$THUIS" npm ci --no-audit --no-fund --loglevel=error
sudo -u "$GEBRUIKER" env HOME="$THUIS" npm run build --silent
echo "   gebouwd: dist/index.js"

echo "== 3. wisselen + herstart"
systemctl stop fogofwar || true
rm -rf "$BASIS/engine.oud"
if [ -d "$BASIS/engine" ]; then
  mv "$BASIS/engine" "$BASIS/engine.oud"
fi
mv "$BASIS/engine.nieuw" "$BASIS/engine"
systemctl start fogofwar

echo "== 4. gezond?"
for _ in $(seq 1 40); do
  sleep 1
  if curl -fs "http://127.0.0.1:$POORT/gezond" >/dev/null 2>&1; then break; fi
done
if ! curl -fs "http://127.0.0.1:$POORT/gezond" >/dev/null 2>&1; then
  echo "de service antwoordt niet; laatste logregels:"
  journalctl -u fogofwar -n 40 --no-pager
  exit 1
fi
echo "   gezond; versie: $(curl -fs "http://127.0.0.1:$POORT/versie")"
rm -f "$PAKKET" "$BRON"
echo "== klaar"
