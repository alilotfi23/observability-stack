# Modular Observability Stack (Prometheus + Loki + Grafana)

A production-grade, security-hardened monitoring/logging stack built on Docker
Compose, designed to be extended into Kubernetes, Kafka, and application-level
metrics without a rewrite.

## Folder structure

```
observability-stack/
├── docker-compose.yml          # single entrypoint, wires everything together
├── .env.example                 # copy to .env, fill in real secrets
├── prometheus/
│   ├── prometheus.yml           # scrape configs (modular via file_sd)
│   ├── web.yml                  # native basic auth + TLS for Prometheus UI/API
│   ├── rules/                   # alert rules, one file per domain
│   │   ├── node-alerts.yml
│   │   ├── container-alerts.yml
│   │   └── blackbox-alerts.yml
│   └── targets/                 # file_sd targets - add hosts/endpoints here
│       ├── node-exporter.json
│       ├── cadvisor.json
│       └── blackbox.json
├── alertmanager/
│   ├── alertmanager.yml.tmpl    # template (rendered via envsubst at boot)
│   ├── web.yml                  # native basic auth + TLS
│   └── entrypoint.sh
├── blackbox/blackbox.yml        # probe modules (http/tcp/icmp)
├── loki/loki-config.yml         # log storage + retention
├── promtail/promtail-config.yml # journald / syslog / docker log shipping
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/         # Prometheus + Loki auto-wired, incl. auth
│   │   └── dashboards/          # auto-load dashboards dropped in ../dashboards
│   └── dashboards/               # drop dashboard JSON here (see its README)
├── nginx/nginx.conf             # single TLS entrypoint, reverse-proxies Grafana
├── certs/                        # TLS certs (self-signed for dev, real CA for prod)
└── scripts/
    ├── generate-htpasswd.sh     # bcrypt hash for Prometheus/Alertmanager auth
    └── generate-dev-certs.sh    # self-signed certs for local testing
```

## Setup

```bash
cd observability-stack
cp .env.example .env
# edit .env: set real passwords, Slack webhook, SMTP creds

# 1. Generate TLS certs (self-signed for dev; swap for real CA certs in prod)
./scripts/generate-dev-certs.sh

# 2. Generate the bcrypt hash for Prometheus/Alertmanager basic auth
./scripts/generate-htpasswd.sh promadmin '<same password as PROM_BASIC_AUTH_PASSWORD in .env>'
# paste the output hash into prometheus/web.yml and alertmanager/web.yml

# 3. Bring the stack up
docker compose up -d

# 4. Log into Grafana at https://<host>/grafana/ with GF_SECURITY_ADMIN_USER/PASSWORD
```

## Security model (what's actually enforced here)

- **Prometheus & Alertmanager**: native `web.yml` basic auth (bcrypt) + TLS on
  the web listener itself — not just a reverse-proxy afterthought. Both ports
  are bound to `127.0.0.1` on the host, so they're reachable only via SSH
  tunnel/VPN, never directly from the internet.
- **Grafana**: anonymous access disabled, signup disabled, admin password
  forced via env var (no default admin/admin left active), not exposed on a
  host port at all — only reachable through the nginx TLS entrypoint.
- **Exporters** (node-exporter, cAdvisor, blackbox-exporter): no host ports
  published at all. They only exist on `monitoring-internal` and are scraped
  by Prometheus over the Docker network. This is the biggest deviation from
  the common tutorial pattern of exposing 9100/8080 directly — those ports
  leak host/container internals to anyone who can reach them.
- **Secrets**: SMTP creds, Slack webhook, and passwords live in `.env`
  (git-ignored) and are injected at runtime — nothing sensitive is hardcoded
  into committed YAML. For real production use, swap `.env` for Docker
  secrets or Vault-injected env vars.
- **Network segmentation**: two Docker networks — `monitoring-edge` (only
  what nginx needs to reach) and `monitoring-internal` (scrape/push traffic).
  Exporters never touch `monitoring-edge`.
- **TLS everywhere it terminates user traffic**: nginx forces HTTP→HTTPS,
  sets HSTS/X-Frame-Options/X-Content-Type-Options.

### Still recommended before real production use
- Replace self-signed certs with Let's Encrypt or your internal CA.
- Put Grafana behind SSO/OIDC (Grafana supports this natively — `GF_AUTH_*`
  env vars) instead of local admin/admin accounts for multi-user teams.
- Move secrets from `.env` to Docker secrets or Vault.
- If internet-facing at all, put Cloudflare/WAF or at minimum fail2ban in
  front of nginx.

## Retention & storage

- Prometheus: `${PROMETHEUS_RETENTION_TIME}` (default 30d) and a size cap
  (default 20GB) — whichever hits first triggers compaction.
- Loki: `retention_period: 744h` (31 days) via the compactor. For real scale,
  swap `filesystem` storage for S3/GCS-backed storage — the `schema_config`
  and `limits_config` blocks carry over unchanged.

## Alerting

Alertmanager routes by `severity` label:
- `critical` → Slack `#alerts-critical` + email, with inhibition suppressing
  duplicate `warning` alerts for the same instance.
- `warning` → Slack `#alerts-warning`.

Add PagerDuty/Opsgenie by adding a `pagerduty_configs`/`opsgenie_configs`
block to the `critical-pager` receiver in `alertmanager/alertmanager.yml.tmpl`.

## Extending the stack

This is the part that matters long-term — here's exactly where each future
addition plugs in without touching anything else:

| Add this...                     | Do this                                                                 |
|----------------------------------|--------------------------------------------------------------------------|
| New Linux host                  | Add an entry to `prometheus/targets/node-exporter.json`, deploy node-exporter there |
| New synthetic check              | Add a URL to `prometheus/targets/blackbox.json`                |
| Docker container monitoring      | Already included (cAdvisor) — just add alert thresholds per service      |
| Kubernetes cluster                | Uncomment the `kubernetes_sd_configs` block in `prometheus.yml` and the equivalent in `promtail-config.yml`; or migrate this whole stack to the `kube-prometheus-stack` + `loki-distributed` Helm charts, reusing these rule files and dashboards as-is |
| Kafka broker metrics             | Add `kafka-exporter` service to docker-compose, uncomment the `kafka-exporter` scrape job in `prometheus.yml`, add `kafka-alerts.yml` under `prometheus/rules/` |
| Application-level metrics (custom `/metrics`) | Add a new `file_sd` target file under `prometheus/targets/`, and a new scrape job pointing at it — same pattern as node-exporter |
| New alert routing (e.g. per-team)| Add a `route` + `receiver` block in `alertmanager.yml.tmpl` matching on a label like `team=` |

The design principle throughout: **new targets are data (JSON/YAML files),
not new code** — you extend by adding files, not editing the compose file or
restructuring folders.
