# Dashboards

Drop dashboard JSON files here — they're auto-loaded by Grafana's provisioning
(see `provisioning/dashboards/dashboards.yml`). Subfolders become Grafana folders.

Recommended starting points (import via Grafana UI → Dashboards → Import → by ID,
then export the JSON here to version-control it):

| Dashboard              | Grafana.com ID | Covers                          |
|-------------------------|:--------------:|----------------------------------|
| Node Exporter Full      | 1860            | Host CPU/mem/disk/net            |
| Docker / cAdvisor       | 893             | Per-container resource usage     |
| Blackbox Exporter       | 7587            | Uptime / probe latency           |
| Alertmanager            | 9578            | Alert volume & routing           |
| Loki / Logs             | 13639           | Log volume & query panel         |

Naming convention: `<domain>-<purpose>.json`, e.g. `host-overview.json`,
`docker-containers.json`, `synthetic-uptime.json`.
