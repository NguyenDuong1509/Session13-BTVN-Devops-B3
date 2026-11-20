# BÁO CÁO PHÂN TÍCH: TRIỂN KHAI & BẢO MẬT NODE EXPORTER

## 1. Các Volume đặc biệt cần Mount vào Node Exporter Container

Khi Node Exporter chạy bên trong Docker Container, mặc định nó bị giới hạn trong môi trường ảo hóa (Container Namespaces & cgroups). Nếu không mount các file hệ thống từ Host, Node Exporter chỉ đo được thông số của chính container.

Để đọc được **thông số phần cứng thực tế của máy chủ Host (VPS)**, bắt buộc phải mount 3 volume đặc biệt sau ở chế độ chỉ đọc (`:ro` - read only):

| Volume Mount trên Host | Đường dẫn trong Container | Mục đích kỹ thuật |
| :--- | :--- | :--- |
| **`/proc`** | `/host/proc:ro` | Cho phép đọc các cấu trúc dữ liệu ảo của Linux kernel: thông tin CPU cores (`/proc/stat`), dung lượng RAM/Swap thực (`/proc/meminfo`), lưu lượng mạng interfaces (`/proc/net/dev`), tiến trình và system load average (`/proc/loadavg`). |
| **`/sys`** | `/host/sys:ro` | Cho phép đọc thông tin thiết bị phần cứng tầng sâu từ kernel subsystem: danh sách ổ đĩa cứng thực tế (`/sys/block`), tốc độ card mạng, thông số nhiệt độ phần cứng (thermal sensors), CPU throttling. |
| **`/` (Rootfs)** | `/rootfs:ro` | Cho phép trình thu thập filesystem đọc chính xác tổng dung lượng, dung lượng trống (free space) và số lượng inode khả dụng của các phân vùng ổ đĩa thực trên máy chủ thật. |

### Các tham số cờ (flags) đi kèm trong `docker-compose.yml`:
```yaml
command:
  - '--path.procfs=/host/proc'
  - '--path.sysfs=/host/sys'
  - '--path.rootfs=/rootfs'
  - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
```
*Lưu ý:* Cờ `--collector.filesystem.mount-points-exclude` giúp loại bỏ việc quét trùng các thư mục ảo nội bộ, tránh làm nhiễu dữ liệu metrics ổ đĩa.

---

## 2. Phân tích bẫy (The Trap): Port mặc định & Rủi ro bảo mật

### 2.1. Port mặc định của Node Exporter:
- Mặc định, Node Exporter lắng nghe trên cổng: **`9100`** (endpoint `/metrics`).

### 2.2. Rủi ro cực lớn khi Public Port 9100 ra ngoài Internet:
1. **Hoàn toàn KHÔNG có xác thực (No Authentication):**
   - Node Exporter sinh ra chỉ thuần túy làm collector/exporter, mặc định **không có mật khẩu (no auth)** và **truyền plaintext HTTP**.
2. **Nguy cơ trinh sát hệ thống (System Reconnaissance & Information Disclosure):**
   - Hacker truy cập `http://<IP_VPS>:9100/metrics` có thể đọc được toàn bộ "hồ sơ bệnh án" của máy chủ:
     - Phiên bản Linux kernel chính xác (giúp tìm lỗ hổng khai thác 1-day/0-day phù hợp).
     - Danh sách ổ cứng, tên các phân vùng mount, cấu trúc thư mục lưu trữ dữ liệu.
     - Danh sách card mạng, địa chỉ MAC, dải IP nội bộ private LAN.
     - Mức độ tải CPU, bộ nhớ RAM theo thời gian thực (giúp hacker xác định thời điểm hệ thống yếu nhất để thực hiện tấn công DDOS hoặc brute-force).
3. **Bị bypass bởi Docker iptables (Bài học Session 12 Bài 4):**
   - Nếu viết `ports: - "9100:9100"`, Docker tự tạo rule iptables mở toang cổng 9100 ra internet, vượt qua cả firewall UFW!

---

## 3. Giải pháp bảo mật chuẩn cho Node Exporter

1. **Chỉ bind vào localhost:**
   ```yaml
   ports:
     - "127.0.0.1:9100:9100"
   ```
2. **Hoặc chỉ giao tiếp qua Docker Internal Network:**
   Nếu Prometheus và Node Exporter cùng nằm trên một VPS, **không cần publish bất kỳ port nào ra ngoài host** (`ports:` có thể bỏ hoàn toàn). Prometheus gọi Node Exporter trực tiếp qua DNS nội bộ Docker:
   ```yaml
   # prometheus.yml
   - targets: ['node-exporter:9100']
   ```
3. **Cấu hình Firewall UFW (nếu Prometheus ở server khác):**
   ```bash
   sudo ufw deny 9100/tcp
   sudo ufw allow from <IP_PROMETHEUS_SERVER> to any port 9100 proto tcp
   ```
4. **Bật TLS và Basic Auth** thông qua file `--web.config.file` nếu buộc phải truyền dữ liệu qua Internet.
