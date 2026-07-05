#!/usr/bin/env bash
#
# Generates a bcrypt password hash compatible with Prometheus / Alertmanager's
# native web.yml basic_auth_users field.
#
# Usage:
#   ./generate-htpasswd.sh <username> <password>
#
# Then paste the printed "username: hash" line into:
#   - prometheus/web.yml   (basic_auth_users:)
#   - alertmanager/web.yml (basic_auth_users:)
#
# Requires Docker (uses the httpd:alpine image so you don't need htpasswd
# installed locally). Falls back to python's bcrypt if Docker isn't available.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <username> <password>"
  exit 1
fi

USERNAME="$1"
PASSWORD="$2"

if command -v docker >/dev/null 2>&1; then
  HASH=$(docker run --rm httpd:alpine htpasswd -nbB "$USERNAME" "$PASSWORD" | cut -d: -f2)
elif python3 -c "import bcrypt" >/dev/null 2>&1; then
  HASH=$(python3 -c "
import bcrypt, sys
print(bcrypt.hashpw(sys.argv[1].encode(), bcrypt.gensalt(rounds=12)).decode())
" "$PASSWORD")
else
  echo "ERROR: Need either Docker or python3 with the 'bcrypt' package installed." >&2
  echo "  pip install bcrypt --break-system-packages   # if using python3 fallback" >&2
  exit 1
fi

echo ""
echo "Add this to prometheus/web.yml and alertmanager/web.yml under basic_auth_users:"
echo ""
echo "  ${USERNAME}: ${HASH}"
echo ""
