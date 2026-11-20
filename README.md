# Session 13 - Bài tập 3: Khám sức khỏe máy chủ với Node Exporter

Dự án triển khai và cấu hình **Prometheus** kết hợp **Node Exporter** qua Docker Compose để giám sát toàn diện sức khỏe phần cứng máy chủ Linux (VPS): CPU, RAM, Disk Space, Network IO.

---

## 🎯 Mục tiêu bài làm

1. **Docker Compose**: Cấu hình Node Exporter container với đầy đủ volume mounts `/proc`, `/sys`, `/rootfs` để đọc thông số phần cứng thực tế.
2. **Prometheus Config**: Bổ sung job `node` trong `prometheus.yml` để tự động scrape metrics định kỳ từ Node Exporter.
3. **Giải đáp bẫy bảo mật**: Phân tích rủi ro của port mặc định `9100` khi public ra Internet mà không có mật khẩu và phương pháp phòng ngừa chuẩn DevOps.

---

## 🏗️ Kiến trúc giám sát

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MÁY CHỦ THẬT (HOST VPS)                         │
│   /proc (CPU, RAM)   ──────►  Mount /host/proc (ro)                    │
│   /sys (Hardware)    ──────►  Mount /host/sys (ro)                     │
│   / (Disk Filesystem)──────►  Mount /rootfs (ro)                       │
│                                       │                                │
│                                       ▼                                │
│                   ┌──────────────────────────────────────┐             │
│                   │ Container: node-exporter             │             │
│                   │ Port: 127.0.0.1:9100 (Localhost only)│             │
│                   └──────────────────┬───────────────────┘             │
│                                      │                                 │
│                                      │ Scrape metrics qua Docker Net   │
│                                      ▼                                 │
│                   ┌──────────────────────────────────────┐             │
│                   │ Container: prometheus-server         │             │
│                   │ Job: 'node' (Scrape interval: 10s)   │             │
│                   └──────────────────────────────────────┘             │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Cấu hình cốt lõi

### 1. `docker-compose.yml` (Trích đoạn Node Exporter)
```yaml
node-exporter:
  image: prom/node-exporter:v1.7.0
  container_name: node-exporter
  ports:
    - "127.0.0.1:9100:9100" # An toàn: chỉ localhost
  volumes:
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
    - /:/rootfs:ro
  command:
    - '--path.procfs=/host/proc'
    - '--path.sysfs=/host/sys'
    - '--path.rootfs=/rootfs'
    - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
```

### 2. `prometheus/prometheus.yml` (Job `node`)
```yaml
scrape_configs:
  - job_name: 'node'
    scrape_interval: 10s
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          instance: 'vps-production'
          environment: 'production'
```

---

## 🖼️ Minh chứng hoàn thành (Proofs)

Các ảnh chụp màn hình minh chứng trong `homework/session_13/exercise_03/`:
1. `node_exporter_docker_compose_proof.png`: Cấu hình Docker Compose với các volume `/proc`, `/sys`, `/rootfs`.
2. `prometheus_config_node_job_proof.png`: Block `job_name: 'node'` trong `prometheus.yml` và kiểm tra `promtool check config`.
3. `node_exporter_metrics_verification_proof.png`: Kiểm tra curl metrics và các câu truy vấn PromQL về RAM, CPU, Ổ đĩa.

---

## 🚀 Hướng dẫn kiểm tra

```bash
# 1. Khởi chạy toàn bộ stack:
docker compose up -d

# 2. Kiểm tra log Node Exporter:
docker compose logs node-exporter

# 3. Kiểm tra metrics tài nguyên Host:
curl -s http://localhost:9100/metrics | grep -E "node_memory_MemTotal_bytes|node_filesystem_size_bytes"

# 4. Kiểm tra target đã UP trong Prometheus:
curl -s http://localhost:9090/api/v1/targets | jq .
```
