#!/bin/sh
# Alertmanager's config file has no native env-var interpolation.
# This wrapper renders the template with envsubst before starting AM,
# so secrets (Slack webhook, SMTP creds) can stay in .env / docker secrets
# instead of being hardcoded into alertmanager.yml.
set -eu

envsubst < /etc/alertmanager/alertmanager.yml.tmpl > /etc/alertmanager/alertmanager.yml

exec /bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --web.config.file=/etc/alertmanager/web.yml \
  --storage.path=/alertmanager \
  --web.listen-address=:9093
