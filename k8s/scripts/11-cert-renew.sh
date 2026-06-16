#!/bin/sh

install_cert_renew() {
  cat > /usr/local/sbin/k8s-cert-renew <<'EOF'
#!/bin/sh
set -eu
LOG=/var/log/k8s-cert-renew.log
THRESHOLD_DAYS=${CERT_RENEW_THRESHOLD_DAYS:-90}
now() { date +"%Y-%m-%dT%H:%M:%S%z"; }
log() { printf '%s %s\n' "$(now)" "$*" >> "$LOG"; }

check_only=0
force=0
case "${1:-}" in
  --check) check_only=1 ;;
  --renew) force=1 ;;
esac

if [ "$force" -ne 1 ]; then
  if kubeadm certs check-expiration 2>/dev/null | awk -v t="$THRESHOLD_DAYS" '
    /days/ {
      for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+d$/) {gsub("d","",$i); if ($i < t) bad=1}
    }
    END {exit bad ? 0 : 1}
  '; then
    :
  else
    log "certificates are not within renewal threshold"
    exit 0
  fi
fi

[ "$check_only" -eq 1 ] && { kubeadm certs check-expiration; exit 0; }

backup="/var/lib/k8s-installer-data/backups/pki-$(date +%Y%m%d%H%M%S)"
mkdir -p "$backup"
cp -a /etc/kubernetes/pki "$backup/" 2>/dev/null || true
cp -a /etc/kubernetes/*.conf "$backup/" 2>/dev/null || true
log "renewing certificates"
kubeadm certs renew all >> "$LOG" 2>&1
cp -f /etc/kubernetes/admin.conf /root/.kube/config 2>/dev/null || true
for f in kube-apiserver kube-controller-manager kube-scheduler etcd; do
  if [ -f "/etc/kubernetes/manifests/$f.yaml" ]; then
    touch "/etc/kubernetes/manifests/$f.yaml"
  fi
done
log "certificate renewal completed"
EOF
  chmod 755 /usr/local/sbin/k8s-cert-renew

  cat > /etc/systemd/system/k8s-cert-renew.service <<EOF
[Unit]
Description=Renew kubeadm certificates

[Service]
Type=oneshot
Environment=CERT_RENEW_THRESHOLD_DAYS=$CERT_RENEW_THRESHOLD_DAYS
ExecStart=/usr/local/sbin/k8s-cert-renew
EOF

  cat > /etc/systemd/system/k8s-cert-renew.timer <<EOF
[Unit]
Description=Monthly kubeadm certificate renewal check

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOF

  run_cmd "11-cert-renew" systemctl daemon-reload
  run_cmd "11-cert-renew" systemctl enable --now k8s-cert-renew.timer
}
