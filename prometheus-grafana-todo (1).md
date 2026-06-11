# Prometheus & Grafana — Project Todo

## Phase 2 — Make Data Flow

> Everything here runs on your own machine with Docker — no credit card, no cloud account required.

- Write `prometheus.yml` with `scrape_interval: 15s` and jobs for Node Exporter (`host.docker.internal:9100`) and Prometheus itself (`localhost:9090`) — mount it into the container with a volume bind in `docker-compose.yml`, restart the stack, and confirm both targets show **UP** at `localhost:9090/targets`
- Type `node_cpu_seconds_total` in the Prometheus Graph tab and hit Execute — it only goes up forever; now try `rate(node_cpu_seconds_total[5m])` and switch to Graph view; that's how you learn what `rate()` does without reading a definition
- Try `increase()` and `irate()` on the same metric, then break it intentionally by using a range shorter than your scrape interval and read the error Prometheus returns
- Write a minimal HTTP server in Node.js or Python, add `prom-client` or `prometheus_client`, and expose a `/metrics` endpoint with one Counter that increments on every request
- Add your app as a scrape job, hit the endpoint 100 times in a loop, and query the counter in Prometheus — watch the number climb in real time

---

## Phase 3 — Prometheus Config

- In Grafana go to Connections > Data Sources > Prometheus and set the URL to `http://prometheus:9090` — use the Docker service name, not `localhost`; click Save & Test and confirm it passes
- Create your first panel: query `up` — it returns 1 for every target that is UP and 0 for any that is DOWN; save it and you have a working dashboard
- Import the Node Exporter Full dashboard using ID `1860` — click Edit on three different panels and read the PromQL queries to understand how they're built
- Build a CPU usage panel from scratch: `100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` — set the unit to Percent and add thresholds at 80 and 90
- Add a Histogram to your demo app and build a p95 latency panel using `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
- Add a dashboard variable that populates from `label_values(up, instance)` and rewire your panels to use `$instance` — a dropdown will appear that filters every panel

---

## Phase 4 — Break and Harden

- Kill Node Exporter with `pkill node_exporter`, watch the target turn red in Prometheus and the panels go blank in Grafana, then restart it and confirm auto-recovery
- Set `scrape_interval: 1s` on your app job, hammer the endpoint for 30 seconds, and check Status > TSDB Status to see the ingestion rate spike — then set it back to `15s`
- Write a `rules.yml` with a `TargetDown` alert (`expr: up == 0`, `for: 1m`), mount it into Prometheus, kill Node Exporter, and watch the alert move from Inactive → Pending → Firing in the Alerts tab
- Add Alertmanager to your `docker-compose.yml`, write an `alertmanager.yml` that routes to a Slack webhook or email, and wire it to Prometheus — kill Node Exporter and wait for the notification to arrive
- Create a read-only Viewer account in Grafana, log in as that user, and confirm you can see dashboards but all edit controls are gone

---

## Phase 5 — Advanced Goals (optional but valuable)

- Write a recording rule that pre-computes an expensive query into a new time series — update your Grafana panel to use the recorded metric name and notice queries become instant
- Add Loki and Promtail to your `docker-compose.yml`, add Loki as a Grafana data source, and use the split Explore pane to correlate a metric spike with the log lines that caused it
- Build a custom exporter from scratch without a client library — write a plain HTTP server that serves `/metrics` in Prometheus text format and add it as a scrape job
- Add `nginx-prometheus-exporter` to your stack, enable `stub_status` in `nginx.conf`, and build a panel showing active connections and requests/sec

---

## Phase 6 — Cloud Server Setup (do this once you have your credit card)

> All the phases above work locally first. When your card is ready, this phase moves your Docker Compose stack to a real server.

- Create an Oracle Cloud free-tier account at `cloud.oracle.com` — the Always Free tier gives you 2 AMD VMs with 1 GB RAM each; choose your home region carefully during sign-up, you cannot change it later
- Provision a VM with Ubuntu 22.04, add your SSH public key during setup, and connect with `ssh -i key.pem ubuntu@YOUR_IP`
- Install Docker Engine on the VM with `curl -fsSL https://get.docker.com | sh`, add your user to the docker group, and confirm with `docker run hello-world` without sudo
- Copy your project to the server with `scp -r` or `git clone` from a private repo — use a `.env` file for secrets and reference it in `docker-compose.yml` with `env_file: .env`
- In the Oracle Console open port `3000` for Grafana in the VCN Security List and run `sudo ufw allow 3000/tcp` on the VM — do not open port `9090` publicly
- Run `docker compose up -d` on the server, confirm all targets are UP by curling `localhost:9090/targets` from inside the VM, and verify Grafana loads at `YOUR_IP:3000` from your laptop