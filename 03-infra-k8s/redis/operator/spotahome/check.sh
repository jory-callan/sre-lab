#!/usr/bin/env bash
set -euo pipefail

NS="${1:-redis-spotahome}"
PASS="${2:-redis@czw}"
RFR="rfr-redisfailover-ha"       # Redis StatefulSet 前缀
RFS="rfs-redisfailover-ha"       # Sentinel Deployment 名称
SVC="rfrm-redisfailover-ha"      # 外部 Service 名称
PASS_OK=true
FAIL=0

green() { printf "  \033[32m✔ %s\033[0m\n" "$1"; }
red()   { printf "  \033[31m✘ %s\033[0m\n" "$1"; }
info()  { printf "\n\033[36m━━━ %s ━━━\033[0m\n" "$1"; }
warn()  { printf "  \033[33m! %s\033[0m\n" "$1"; }

check() {
  local name=$1 desc=$2
  shift 2
  if "$@"; then
    green "$name"
  else
    PASS_OK=false
    red "$name — $desc"
    ((FAIL++))
  fi
}

echo "╔═══════════════════════════════════════════════╗"
echo "║  Redis Failover 健康检查                       ║"
echo "║  命名空间: $NS                                   "
echo "╚═══════════════════════════════════════════════╝"

# ─── 1. 基础设施 ───
info "1/7 基础设施"

echo -n "  ·  Namespace:        "; kubectl get ns "$NS" -o jsonpath='{.status.phase}' 2>/dev/null && echo "" || red "NOT FOUND"
echo -n "  ·  CRD:              "; kubectl get crd redisfailovers.databases.spotahome.com -o jsonpath='{.spec.names.kind}' 2>/dev/null && echo "" || red "NOT FOUND"
echo -n "  ·  Operator Pod:     "
OP_POD=$(kubectl get pod -n "$NS" -l app=redisoperator -o name 2>/dev/null | head -1)
if [ -n "$OP_POD" ]; then
  OP_READY=$(kubectl get "$OP_POD" -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
  if [ "$OP_READY" = "true" ]; then green "Ready"; else red "Not Ready"; fi
else
  red "Not Found"
fi

echo -n "  ·  RedisFailover CR: "
kubectl get redisfailover -n "$NS" redisfailover-ha -o jsonpath='{.metadata.name}' 2>/dev/null && echo "" || red "NOT FOUND"

echo -n "  ·  PVC:              "
PVC_STATUS=$(kubectl get pvc -n "$NS" -l app=redisfailover-ha -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
if echo "$PVC_STATUS" | tr ' ' '\n' | grep -v "^Bound$" &>/dev/null; then
  red "Not all Bound ($PVC_STATUS)"
else
  PVC_COUNT=$(kubectl get pvc -n "$NS" -l app=redisfailover-ha --no-headers 2>/dev/null | wc -l | tr -d ' ')
  green "$PVC_COUNT Bound"
fi

# ─── 2. Pod 状态 ───
info "2/7 Pod 状态"

PODS=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null)
echo "$PODS" | awk '{printf "  ·  %-30s %-10s %-10s\n", $1, $3, $2}'

# 检查是否有 CrashLoopBackOff / Error / Pending
BAD=$(echo "$PODS" | awk '!/Running|Completed/' | wc -l | tr -d ' ')
if [ "$BAD" -gt 0 ]; then
  red "$BAD pod(s) not Running"
  FAIL=$((FAIL + BAD))
else
  green "All pods Running"
fi

# Node 分布
echo ""
echo "  Pod 分布:"
kubectl get pods -n "$NS" -o wide --no-headers 2>/dev/null | awk '{printf "    %-35s ➜ %s\n", $1, $7}'

# ─── 3. Redis 连通性 ───
info "3/7 Redis 连通性"

check "PING" "redis-cli PING 失败" \
  kubectl exec -n "$NS" "$OP_POD" -- redis-cli -a "$PASS" -h "$SVC" PING 2>/dev/null | grep -q "PONG"

# ─── 4. 读写测试 ───
info "4/7 读写测试"

KEY="czw:check:$(date +%s)"
VAL="ok-$$"

check "SET" "写入失败" \
  kubectl exec -n "$NS" "$OP_POD" -- redis-cli -a "$PASS" -h "$SVC" SET "$KEY" "$VAL" 2>/dev/null | grep -q "OK"

READ=$(kubectl exec -n "$NS" "$OP_POD" -- redis-cli -a "$PASS" -h "$SVC" GET "$KEY" 2>/dev/null)
if [ "$READ" = "$VAL" ]; then
  green "GET — 写入/读取一致 (key=$KEY, val=$READ)"
else
  red "GET — 值不匹配 (期待 $VAL, 读到 $READ)"
  PASS_OK=false
  ((FAIL++))
fi

kubectl exec -n "$NS" "$OP_POD" -- redis-cli -a "$PASS" -h "$SVC" DEL "$KEY" 2>/dev/null &>/dev/null

# ─── 5. 版本与角色 ───
info "5/7 Redis 版本与角色"

# 版本
VER=$(kubectl exec -n "$NS" "${RFR}-0" -- redis-server --version 2>/dev/null | grep -oP 'v=\K[0-9.]+' || true)
if [ -n "$VER" ]; then
  green "Redis 版本 v$VER"
else
  red "Redis 版本获取失败"
  PASS_OK=false
  ((FAIL++))
fi

# 每个 Pod 的角色
echo ""
for i in 0 1 2; do
  ROLE=$(kubectl exec -n "$NS" "${RFR}-${i}" -- redis-cli -a "$PASS" ROLE 2>/dev/null | head -1 | tr '[:lower:]' '[:upper:]')
  case "$ROLE" in
    MASTER)  echo "  ${RFR}-${i}:  $ROLE $(printf '\033[32m★\033[0m')" ;;
    SLAVE|REPLICA) echo "  ${RFR}-${i}:  $ROLE";;
    *)       echo "  ${RFR}-${i}:  $ROLE $(printf '\033[31m?\033[0m')";;
  esac
done

# ─── 6. Sentinel 健康 ───
info "6/7 Sentinel 集群"

# Sentinel master 地址
echo -n "  ·  Sentinel 已知的 Master: "
kubectl exec -n "$NS" deployment/"$RFS" -- redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster 2>/dev/null | paste -d: - -

# Sentinel 数量
echo -n "  ·  Sentinel 在线节点: "
NUM_S=$(kubectl exec -n "$NS" deployment/"$RFS" -- redis-cli -p 26379 SENTINEL sentinels mymaster 2>/dev/null | grep -c "ip=" || true)
echo "$((NUM_S + 1))"  # +1 是当前节点自身

# quorum
echo -n "  ·  Sentinel quorum: "
kubectl exec -n "$NS" deployment/"$RFS" -- redis-cli -p 26379 SENTINEL ckquorum mymaster 2>/dev/null | head -1

# ─── 7. 复制与一致性 ───
info "7/7 复制链路"

MASTER_IP=$(kubectl exec -n "$NS" deployment/"$RFS" -- redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster 2>/dev/null | head -1)
echo "  ·  Master 地址: $MASTER_IP"

# Service endpoint 是否指向当前 master
SVC_EP=$(kubectl get endpoints -n "$NS" "$SVC" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
if [ "$SVC_EP" = "$MASTER_IP" ]; then
  green "Service endpoint 与 Sentinel master 一致 ($SVC_EP)"
else
  warn "Service endpoint ($SVC_EP) ≠ Sentinel master ($MASTER_IP) — 可能在故障切换中"
fi

# Replica 同步延迟
echo "  ·  Replica 同步:"
for i in 0 1 2; do
  ROLE=$(kubectl exec -n "$NS" "${RFR}-${i}" -- redis-cli -a "$PASS" ROLE 2>/dev/null | head -1)
  if [ "$ROLE" = "slave" ] || [ "$ROLE" = "replica" ]; then
    LAG=$(kubectl exec -n "$NS" "${RFR}-${i}" -- redis-cli -a "$PASS" ROLE 2>/dev/null | tail -4 | head -1)
    echo "    ${RFR}-${i} 延迟: ${LAG}s"
  fi
done

# ─── 汇总 ───
echo ""
echo "╔═══════════════════════════════════════════════╗"
if [ "$FAIL" -eq 0 ]; then
  printf "║  \033[32m结果: ✅ 全部通过\033[0m                                ║\n"
  echo "╚═══════════════════════════════════════════════╝"
  exit 0
else
  printf "║  \033[31m结果: ❌ %d 项检查未通过\033[0m                          ║\n" "$FAIL"
  echo "╚═══════════════════════════════════════════════╝"
  exit 1
fi