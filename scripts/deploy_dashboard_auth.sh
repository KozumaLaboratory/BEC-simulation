#!/usr/bin/env bash
# One-shot dashboard auth deploy.
#
# Idempotent: re-running is safe. Each step checks current state before
# acting.
#
# Run as anko (a sudo member). Requires:
#   - Caddy already installed and running with /etc/caddy/Caddyfile
#   - Google OAuth client (Client ID + Secret) — see
#     docs/guides/dashboard_auth.md §1
#   - Internet access to download oauth2-proxy binary
#
# Posture: (a) anko-only via authenticated_emails_file. Open to lab
# later by appending emails to /etc/oauth2-proxy/emails.txt and
# reloading oauth2-proxy.
#
# Usage:
#   GOOGLE_CLIENT_ID=...  \
#   GOOGLE_CLIENT_SECRET=... \
#   ALLOWED_EMAIL=anko@isct.ac.jp \
#   bash scripts/deploy_dashboard_auth.sh

set -euo pipefail

: "${GOOGLE_CLIENT_ID:?GOOGLE_CLIENT_ID env required}"
: "${GOOGLE_CLIENT_SECRET:?GOOGLE_CLIENT_SECRET env required}"
: "${ALLOWED_EMAIL:?ALLOWED_EMAIL env required (e.g. anko@isct.ac.jp)}"

HOSTNAME_FQDN="${HOSTNAME_FQDN:-bec.local}"
DASHBOARD_UPSTREAM="${DASHBOARD_UPSTREAM:-127.0.0.1:8090}"
OAUTH_PORT="${OAUTH_PORT:-4180}"

echo "==> step 1: install oauth2-proxy (if absent)"
if ! command -v oauth2-proxy >/dev/null; then
    OAUTH_VER="${OAUTH_VER:-v7.6.0}"
    cd /tmp
    curl -L -o oauth2-proxy.tar.gz \
      "https://github.com/oauth2-proxy/oauth2-proxy/releases/download/${OAUTH_VER}/oauth2-proxy-${OAUTH_VER}.linux-amd64.tar.gz"
    tar -xzf oauth2-proxy.tar.gz
    sudo install -m 0755 "oauth2-proxy-${OAUTH_VER}.linux-amd64/oauth2-proxy" /usr/local/bin/oauth2-proxy
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin oauth2-proxy 2>/dev/null || true
    rm -rf "oauth2-proxy-${OAUTH_VER}.linux-amd64" oauth2-proxy.tar.gz
fi

echo "==> step 2: oauth2-proxy config + emails allow-list"
sudo install -d -o oauth2-proxy -g oauth2-proxy -m 0750 /etc/oauth2-proxy

# Generate a cookie secret once and reuse on re-runs.
if [ ! -f /etc/oauth2-proxy/cookie.secret ]; then
    sudo tee /etc/oauth2-proxy/cookie.secret >/dev/null < <(openssl rand -base64 32)
    sudo chown oauth2-proxy:oauth2-proxy /etc/oauth2-proxy/cookie.secret
    sudo chmod 0600 /etc/oauth2-proxy/cookie.secret
fi
COOKIE_SECRET=$(sudo cat /etc/oauth2-proxy/cookie.secret)

sudo tee /etc/oauth2-proxy/emails.txt >/dev/null <<EOF
$ALLOWED_EMAIL
EOF
sudo chmod 0640 /etc/oauth2-proxy/emails.txt
sudo chown root:oauth2-proxy /etc/oauth2-proxy/emails.txt

sudo tee /etc/oauth2-proxy/oauth2-proxy.cfg >/dev/null <<EOF
provider                  = "google"
client_id                 = "$GOOGLE_CLIENT_ID"
client_secret             = "$GOOGLE_CLIENT_SECRET"

# Posture (a): explicit allow-list inside the isct.ac.jp tenant.
authenticated_emails_file = "/etc/oauth2-proxy/emails.txt"
email_domains             = ["isct.ac.jp"]

cookie_secret             = "$COOKIE_SECRET"
cookie_domains            = ["$HOSTNAME_FQDN"]
cookie_secure             = true
cookie_httponly           = true

http_address              = "127.0.0.1:$OAUTH_PORT"
reverse_proxy             = true

set_xauthrequest          = true
pass_user_headers         = true
pass_access_token         = false

upstreams                 = ["http://$DASHBOARD_UPSTREAM"]
EOF
sudo chmod 0640 /etc/oauth2-proxy/oauth2-proxy.cfg
sudo chown root:oauth2-proxy /etc/oauth2-proxy/oauth2-proxy.cfg

echo "==> step 3: oauth2-proxy systemd unit"
sudo tee /etc/systemd/system/oauth2-proxy.service >/dev/null <<EOF
[Unit]
Description=oauth2-proxy in front of dashboard
After=network.target

[Service]
ExecStart=/usr/local/bin/oauth2-proxy --config=/etc/oauth2-proxy/oauth2-proxy.cfg
Restart=on-failure
User=oauth2-proxy

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now oauth2-proxy

echo "==> step 4: Caddy block for $HOSTNAME_FQDN (append if absent)"
if ! grep -q "^$HOSTNAME_FQDN[[:space:]]*{" /etc/caddy/Caddyfile; then
    sudo tee -a /etc/caddy/Caddyfile >/dev/null <<EOF

# BEC dashboard — oauth2-proxy in front, dashboard bound to 127.0.0.1:8090.
$HOSTNAME_FQDN {
    handle /oauth2/* {
        reverse_proxy 127.0.0.1:$OAUTH_PORT
    }
    handle {
        forward_auth 127.0.0.1:$OAUTH_PORT {
            uri /oauth2/auth
            copy_headers X-Auth-Request-Email X-Auth-Request-User
        }
        reverse_proxy $DASHBOARD_UPSTREAM
    }
    tls internal
}
EOF
    sudo caddy validate --config /etc/caddy/Caddyfile
    sudo systemctl reload caddy
else
    echo "    (Caddyfile already has $HOSTNAME_FQDN block — skipping)"
fi

echo "==> step 5: switch Julia dashboard to bind=127.0.0.1"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"
cat > "$SYSTEMD_USER_DIR/spinorbec-dashboard.service" <<EOF
[Unit]
Description=SpinorBEC dashboard (Julia, loopback-only)
After=network.target

[Service]
Environment=SPINORBEC_DASHBOARD_BIND=127.0.0.1
WorkingDirectory=/home/suzume/workspace/BEC-simulation
ExecStart=/usr/bin/env julia --project=. -e "using SpinorBEC; serve_dashboard(8090)"
Restart=on-failure

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
# Stop any existing serve_dashboard run started outside systemd
pkill -f 'julia.*serve_dashboard' 2>/dev/null || true
sleep 1
systemctl --user enable --now spinorbec-dashboard.service

echo
echo "===================================================================="
echo "deploy complete."
echo "  dashboard available at:  https://$HOSTNAME_FQDN/"
echo "  authorized email:        $ALLOWED_EMAIL"
echo "  to add more users:       sudo sh -c 'echo NEW@isct.ac.jp >> /etc/oauth2-proxy/emails.txt && systemctl reload oauth2-proxy'"
echo "  to disable dry-run:      julia --project=. scripts/autopilot.jl dry-run off"
echo "===================================================================="
