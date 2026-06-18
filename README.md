# Prometheus & Grafana Monitoring — Project Todo

Automated monitoring stack using Docker, Ansible, and a custom Node.js metrics server. The project builds Prometheus, Alertmanager, Node Exporter, Grafana, Nginx, deploys them with Docker Compose, and uses Ansible to provision and update the target server.

**Target Environment:** Ubuntu VM Arm64 on Oracle Cloud (Always Free Tier)  
**Primary Access:** Grafana through Nginx on port 3000 
**Project Inspiration:** https://roadmap.sh/projects/monitoring

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Project Structure](#project-structure)
3. [What Each Part Does](#what-each-part-does)
4. [Containers](#containers)
5. [Deployment](#deployment)
6. [Configuration](#configuration)
7. [Terraform Tutorial](#terraform-tutorial)
8. [Operations](#operations)

---

## Quick Start

```bash
# Install Ansible on the control machine
sudo apt install ansible

# Build all images and deploy to the remote server
make build
```

---

## Project Structure

```text
Prometheus_and_Grafana_Monitoring/
├── Makefile
├── Containers/
│   ├── Prometheus/
│   ├── Alertmanager/
│   ├── Node-exporter/
│   ├── Grafana/
│   ├── Nginx/
│   ├── Node-serv/
│   └── docker-compose.yml
├── Ansible/
│   ├── inventory.ini
│   ├── setup.yml
│   └── collections/
│       └── requirement/
│           └── requirement.yml
│   └── group_vars/
│       └── sandbox/
│           ├── vars.yml
│           └── vault.yml
```

---

## What Each Part Does

- `Containers/Prometheus` — scrapes all targets on a 15s interval and evaluates alert rules.
- `Containers/Alertmanager` — receives firing alerts from Prometheus and routes them to Slack or email.
- `Containers/Node-exporter` — exports host CPU, memory, and disk metrics from the underlying VM.
- `Containers/Grafana` — visualizes all metrics through dashboards; proxied through Nginx.
- `Containers/Nginx` — reverse-proxies Grafana on port 80; Grafana's port is not exposed directly.
- `Containers/Node-serv` — a minimal Express app that exposes a `/metrics` endpoint with a Counter and Histogram.
- `Ansible` — installs Docker, copies the Compose stack, and runs deployment on the remote server.

---

## Containers

### Prometheus

- Write `prometheus.yml` with `scrape_interval: 15s` and jobs for: Prometheus itself (`localhost:9090`), Node Exporter (`node-exporter:9100`), and the demo app (`node-serv:3000/metrics`) — use Docker service names, not `localhost`, for cross-container DNS resolution
- Mount `prometheus.yml` and `rules.yml` into the container via volume binds in `docker-compose.yml`
- Confirm all targets show **UP** at `localhost:9090/targets` — a `DOWN` target means a wrong hostname, wrong port, or the target container is not running yet

### Alertmanager

- Write `alertmanager.yml` with a route that sends all alerts to a receiver — start with a `null` receiver for testing, then swap it for a real Slack webhook or SMTP config
- Wire Alertmanager to Prometheus by adding `alerting.alertmanagers` in `prometheus.yml` pointing to `alertmanager:9093`
- Write `rules.yml` with a `TargetDown` alert (`expr: up == 0`, `for: 1m`) — kill Node Exporter and watch the alert move through Inactive → Pending → Firing in the Prometheus Alerts tab

### Node Exporter

- Mount host `/proc`, `/sys`, and `/` as read-only volumes so Node Exporter reads real kernel stats instead of container stats
- Query `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100` in Prometheus after it is scraped — this is your first hand-written PromQL expression

### Grafana

- Add Prometheus as a data source: Connections → Data Sources → Prometheus, set URL to `http://prometheus:9090`, click Save & Test
- Import the Node Exporter Full dashboard using ID `1860` — open three panels in edit mode and read the PromQL queries before building your own
- Build a CPU usage panel from scratch: `100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` — unit: Percent, thresholds at 80 and 90
- Build a p95 latency panel: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` — compare it against p50 on the same graph
- Add a dashboard variable from `label_values(up, instance)` and rewire panels to use `$instance` — a dropdown will appear that filters every panel at once

### Nginx

- Write `nginx.conf` that proxies `proxy_pass http://grafana:3000` on `location /` — add `proxy_set_header Host` and `proxy_set_header X-Real-IP` so Grafana sees the real client IP
- Remove the direct Grafana port binding from `docker-compose.yml` — Grafana should only be reachable through Nginx, not on port 3000 from outside Docker

### Node Server (Demo App)

- Create a minimal Express app with `prom-client` — expose a Counter that increments on every `GET /` and a Histogram that tracks request duration, both available at `GET /metrics`
- Hit the endpoint 200 times in a loop and query `rate(http_requests_total[1m])` in Prometheus to watch the counter climb in real time

```bash
for i in $(seq 1 200); do curl -s localhost:3000 > /dev/null; done
```

---

## Deployment

The usual flow is:

```bash
make build
```

Or run the pieces manually:

```bash
# Build and push all six images for amd64 + arm64
docker buildx build --platform linux/amd64,linux/arm64 -t yass555/prometheus:1.0   --push Containers/Prometheus
docker buildx build --platform linux/amd64,linux/arm64 -t yass555/alertmanager:1.0 --push Containers/Alertmanager
docker buildx build --platform linux/amd64,linux/arm64 -t yass555/node-exporter:1.0 --push Containers/Node-exporter
docker buildx build --platform linux/amd64,linux/arm64 -t yass555/grafana:1.0      --push Containers/Grafana
docker buildx build --platform linux/amd64,linux/arm64 -t yass555/nginx:1.0        --push Containers/Nginx
docker buildx build --platform linux/amd64,linux/arm64 -t yass555/node-serv:1.0    --push Containers/Node-serv

# Deploy to the remote server
ansible-playbook -i Ansible/inventory.ini Ansible/setup.yml \
  --vault-password-file ./Ansible/group_vars/sandbox/my_passwd.txt --ask-become-pass
```

---

## Configuration

### Secrets and Vault

- Secrets (Slack webhook URLs) are encrypted with `ansible-vault` and written to the server by Ansible — never commit plaintext secrets to the repo
- Create `Ansible/group_vars/sandbox/vault.yml` with `ansible-vault create` and store the vault password in `my_passwd.txt` — add `my_passwd.txt` to `.gitignore`

```bash
ansible-vault create Ansible/group_vars/sandbox/vault.yml
```

### Prometheus Scrape Config

Use Docker service names as hostnames — not `localhost` — for all cross-container targets:

```yaml
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']
  - job_name: node-exporter
    static_configs:
      - targets: ['node-exporter:9100']
  - job_name: node-serv
    static_configs:
      - targets: ['node-serv:3000']
```

### Notes

- Bump `TAG` in the Makefile after every breaking change — this forces a fresh image pull on the remote server and prevents stale cached layers from hiding bugs.
- Port `9090` must not be opened publicly — Prometheus has no built-in authentication.
- Compose expects secrets in `./secrets/` next to the compose file.

## Operations

### Makefile Targets

- `make build` — Build, push, and deploy all images.
- `make build-images` — Build and push images only (skip Ansible deploy).
- `make up` — Start containers locally (development).
- `make down` — Stop and remove containers and volumes locally.
- `make start` — Start containers locally without rebuilding.
- `make stop` — Stop containers locally without removing.
- `make logs` — View the last 100 lines of logs from all containers.
- `make deploy` — Deploy to the remote server via Ansible.
- `make remote-stop` — Stop containers on the remote server via Ansible.
- `make remote-up` — Run `docker compose up` on the remote server via Ansible.
- `make remote-down` — Run `docker compose down` on the remote server via Ansible.

### Managing the Remote Stack

Once deployed, use `make remote-stop` to cleanly shut down all containers on the target server from your control machine. This runs the Ansible playbook with the `--tags stop` flag, which stops the Docker Compose stack remotely without SSHing in manually.

---

## Troubleshooting

- If a target shows DOWN in Prometheus, check that its container is running with `make logs` and verify the hostname in `prometheus.yml` matches the Docker service name in `docker-compose.yml`.
- If Grafana shows a blank panel, confirm the data source URL is `http://prometheus:9090` — not `localhost:9090`, And check in `http://<SERVER_IP>:9090` if Target health shows all endpoints as UP, if not you will receive a message in slack from the rule we added with alertmanager.
- If Ansible fails on vault prompts, verify the vault password file path and that the encrypted variables match the keys referenced in `setup.yml`.
- If multi-arch builds fail, confirm `docker buildx ls` shows a builder with `linux/amd64` and `linux/arm64` listed — run `docker buildx create --use` if not.

---

## Notes

- This repository is meant for learning the full observability stack: metrics collection, alerting, and visualization.