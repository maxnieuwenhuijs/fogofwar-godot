#!/usr/bin/env bash
# F4.4a — eenmalige inrichting van een VERSE Ubuntu 24.04-droplet (als root).
#
#   DOMEIN=fog.example.nl EMAIL=jij@example.nl bash droplet-setup.sh
#
# Zet neer: nginx (+ Let's Encrypt), MySQL 8 met een eigen database en
# gebruiker (gegenereerd wachtwoord in /opt/fogofwar/server/.env), Node 22,
# de Godot 4.7-binary voor Linux, de service-gebruiker, de systemd-unit en
# de firewall (alleen 22, 80, 443). Idempotent: een tweede keer draaien
# vervangt niets dat al goed staat en roteert het wachtwoord niet.
# Daarna vanaf Windows: tools/deploy/deploy-server.ps1 -Droplet <domein>.
set -euo pipefail

: "${DOMEIN:?zet DOMEIN (bv. fog.example.nl; het A-record moet al naar deze droplet wijzen)}"
: "${EMAIL:?zet EMAIL (e-mailadres voor Lets Encrypt)}"
GODOT_VERSIE=${GODOT_VERSIE:-4.7-stable}
BASIS=/opt/fogofwar
GEBRUIKER=fogofwar
HIER=$(cd "$(dirname "$0")" && pwd)
GODOT_BIN="$BASIS/godot/Godot_v${GODOT_VERSIE}_linux.x86_64"
export DEBIAN_FRONTEND=noninteractive

echo "== pakketten"
apt-get update -q
apt-get install -y -q nginx certbot python3-certbot-nginx mysql-server unzip curl ufw ca-certificates openssl
# Bibliotheken die de Godot-binary dynamisch zoekt. Headless heeft geen
# scherm of GPU nodig; deze zijn er zodat het laden nergens over struikelt.
apt-get install -y -q libfontconfig1 libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1 libasound2t64 libpulse0 libudev1 libdbus-1-3 || true

echo "== Node 22"
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v)" != v22* ]]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y -q nodejs
fi
node -v

echo "== gebruiker en mappen"
if ! id -u "$GEBRUIKER" >/dev/null 2>&1; then
  useradd --system --home-dir "$BASIS/home" --shell /usr/sbin/nologin "$GEBRUIKER"
fi
mkdir -p "$BASIS/godot" "$BASIS/server" "$BASIS/home"
chown -R "$GEBRUIKER:$GEBRUIKER" "$BASIS/home" "$BASIS/server"

echo "== Godot $GODOT_VERSIE (dezelfde versie als de client)"
if [ ! -x "$GODOT_BIN" ]; then
  curl -fL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSIE}/Godot_v${GODOT_VERSIE}_linux.x86_64.zip"
  unzip -o -q /tmp/godot.zip -d "$BASIS/godot"
  chmod +x "$GODOT_BIN"
  rm -f /tmp/godot.zip
fi
"$GODOT_BIN" --version

echo "== MySQL: database + gebruiker"
systemctl enable --now mysql
if [ -f "$BASIS/server/.env" ] && grep -q '^DB_URL=' "$BASIS/server/.env"; then
  echo "   .env bestaat al; wachtwoord blijft"
else
  WW=$(openssl rand -hex 24)
  mysql -e "CREATE DATABASE IF NOT EXISTS fogofwar CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
  mysql -e "CREATE USER IF NOT EXISTS 'fogofwar'@'127.0.0.1' IDENTIFIED BY '${WW}';"
  mysql -e "ALTER USER 'fogofwar'@'127.0.0.1' IDENTIFIED BY '${WW}';"
  mysql -e "GRANT ALL PRIVILEGES ON fogofwar.* TO 'fogofwar'@'127.0.0.1'; FLUSH PRIVILEGES;"
  cat > "$BASIS/server/.env" <<EOF
# Geschreven door droplet-setup.sh; zie server/.env.voorbeeld voor uitleg.
DB_URL=mysql://fogofwar:${WW}@127.0.0.1:3306/fogofwar
POORT=8787
HOST=127.0.0.1
GODOT_PAD=${GODOT_BIN}
FOW_PROJECT_PAD=${BASIS}/engine
EOF
  chown "$GEBRUIKER:$GEBRUIKER" "$BASIS/server/.env"
  chmod 600 "$BASIS/server/.env"
  echo "   .env geschreven (wachtwoord gegenereerd)"
fi

echo "== systemd"
install -m 644 "$HIER/fogofwar.service" /etc/systemd/system/fogofwar.service
systemctl daemon-reload
systemctl enable fogofwar
# Starten gebeurt pas bij de eerste uitrol (er is nog geen engine en geen dist/).

echo "== nginx"
install -m 644 "$HIER/nginx-fogofwar-http.conf" /etc/nginx/conf.d/fogofwar-http.conf
sed "s/__DOMEIN__/${DOMEIN}/g" "$HIER/nginx-fogofwar.conf" > /etc/nginx/sites-available/fogofwar
ln -sf /etc/nginx/sites-available/fogofwar /etc/nginx/sites-enabled/fogofwar
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx

echo "== firewall"
ufw allow OpenSSH >/dev/null
ufw allow 'Nginx Full' >/dev/null
ufw --force enable >/dev/null
ufw status

echo "== Let's Encrypt voor $DOMEIN"
if certbot --nginx -d "$DOMEIN" -m "$EMAIL" --agree-tos --non-interactive --redirect; then
  echo "   https staat"
else
  echo "   LET OP: certbot mislukte (wijst het A-record van $DOMEIN al naar deze droplet?)."
  echo "   Later opnieuw: certbot --nginx -d $DOMEIN -m $EMAIL --agree-tos --redirect"
fi

echo
echo "Klaar. Nu vanaf Windows, in de projectmap:"
echo "  .\\tools\\deploy\\deploy-server.ps1 -Droplet $DOMEIN -Nettest"
