#!/usr/bin/env bash
# ==============================================================================
# Script: verify-node-exporter.sh
# Mục đích: Tự động kiểm tra sức khỏe VPS qua Node Exporter & Prometheus
# ==============================================================================

set -e

NODE_URL="http://localhost:9100/metrics"
PROMETHEUS_URL="http://localhost:9090"

echo "=========================================================="
echo " [BƯỚC 1] Kiểm tra kết nối Node Exporter (Port 9100)     "
echo "=========================================================="
if curl -s -f -o /dev/null "${NODE_URL}"; then
    echo "  [OK] Node Exporter đang phản hồi dữ liệu tại ${NODE_URL}"
else
    echo "  [ERROR] Không thể kết nối tới Node Exporter tại ${NODE_URL}"
    exit 1
fi

echo ""
echo "=========================================================="
echo " [BƯỚC 2] Kiểm tra đọc thông số phần cứng thực tế (Host) "
echo "=========================================================="
MEM_TOTAL=$(curl -s "${NODE_URL}" | grep "^node_memory_MemTotal_bytes " | awk '{print $2}')
MEM_AVAIL=$(curl -s "${NODE_URL}" | grep "^node_memory_MemAvailable_bytes " | awk '{print $2}')
DISK_SIZE=$(curl -s "${NODE_URL}" | grep 'node_filesystem_size_bytes{.*mountpoint="/".*}' | head -n 1 | awk '{print $2}')

echo "  - RAM Total: $(( MEM_TOTAL / 1024 / 1024 )) MB"
echo "  - RAM Available: $(( MEM_AVAIL / 1024 / 1024 )) MB"
echo "  - Root Disk Size: $(( DISK_SIZE / 1024 / 1024 / 1024 )) GB"

echo ""
echo "=========================================================="
echo " [BƯỚC 3] Kiểm tra Target Node trong Prometheus          "
echo "=========================================================="
TARGETS_JSON=$(curl -s "${PROMETHEUS_URL}/api/v1/targets")
if echo "${TARGETS_JSON}" | grep -q '"job":"node"'; then
    echo "  [SUCCESS] Job 'node' đã được Prometheus đăng ký thành công!"
fi

echo ""
echo "Kiểm tra hoàn tất!"
