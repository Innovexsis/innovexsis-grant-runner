#!/usr/bin/env bash
# One-shot installer for an always-on autofill runner on an Indian VM
# (Oracle Cloud Mumbai/Hyderabad, AWS ap-south-1, Azure Central India, etc.).
# Indian government portals accept Indian IPs, unlike GitHub's US runners.
#
# Usage (as root / via sudo), on Ubuntu 22.04/24.04 (x86_64 or ARM64):
#   curl -fsSL https://raw.githubusercontent.com/Innovexsis/innovexsis-grant-runner/main/automation/install-india-runner.sh -o install.sh
#   sudo APP_BASE_URL=https://grantmonsy.innovexsis.com RUNNER_SHARED_SECRET=xxxx WORKERS=2 bash install.sh
set -euo pipefail

: "${APP_BASE_URL:?set APP_BASE_URL}"
: "${RUNNER_SHARED_SECRET:?set RUNNER_SHARED_SECRET}"
WORKERS="${WORKERS:-2}"
REPO="${REPO:-https://github.com/Innovexsis/innovexsis-grant-runner.git}"
DIR=/opt/govschemeos

apt-get update -y
apt-get install -y git curl unzip ca-certificates

# 2 GB swap so Chromium never OOMs on 1 GB machines
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

id govrunner >/dev/null 2>&1 || useradd -m -s /bin/bash govrunner

if [ -d "$DIR/.git" ]; then git -C "$DIR" pull --ff-only; else git clone --depth 1 "$REPO" "$DIR"; fi
chown -R govrunner:govrunner "$DIR"

sudo -u govrunner bash -lc 'curl -fsSL https://bun.sh/install | bash'
BUN=/home/govrunner/.bun/bin/bun
sudo -u govrunner bash -lc "cd $DIR/automation && $BUN install"
# Chromium + system libs
cd "$DIR/automation" && sudo -u govrunner $BUN x playwright install chromium
$BUN x playwright install-deps chromium

cat > "$DIR/automation/.env" <<EOF
APP_BASE_URL=$APP_BASE_URL
RUNNER_SHARED_SECRET=$RUNNER_SHARED_SECRET
RUNNER_HEADLESS=1
RUNNER_RUN_BUDGET_MS=3000000
EOF
chmod 600 "$DIR/automation/.env"; chown govrunner:govrunner "$DIR/automation/.env"

cat > /etc/systemd/system/govrunner@.service <<EOF
[Unit]
Description=Grant autofill runner (India) worker %i
After=network-online.target
Wants=network-online.target

[Service]
User=govrunner
WorkingDirectory=$DIR/automation
EnvironmentFile=$DIR/automation/.env
Environment=RUNNER_ID=india-%H-%i
ExecStartPre=-/usr/bin/git -C $DIR pull --ff-only
ExecStart=$BUN run autofill-runner.ts
# Runner exits after its budget; always restart -> runs forever, self-updates on each restart
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
for i in $(seq 1 "$WORKERS"); do systemctl enable --now "govrunner@$i"; done
echo "Done. Check: systemctl status 'govrunner@*'  |  logs: journalctl -u govrunner@1 -f"
