#!/usr/bin/env bash
#
# Generates self-signed certs for LOCAL/DEV use only.
# In production: use certs from your internal CA or Let's Encrypt
# (e.g. via a Traefik/Caddy sidecar, or cert-manager if this later
# moves to Kubernetes).

set -euo pipefail

CERT_DIR="$(dirname "$0")/../certs"
mkdir -p "$CERT_DIR"

DAYS=365
SUBJ="/C=US/ST=NA/L=NA/O=Monitoring/CN=monitoring.local"

for name in prometheus alertmanager nginx; do
  echo ">> Generating self-signed cert for $name"
  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "$CERT_DIR/${name}.key" \
    -out "$CERT_DIR/${name}.crt" \
    -days "$DAYS" \
    -subj "$SUBJ"
done

echo ""
echo "Certs written to: $CERT_DIR"
echo "Remember: these are self-signed - browsers/clients will warn until you"
echo "swap in certs from a real CA (internal PKI or Let's Encrypt)."
