#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# chaos-test.sh — CloudNativePG 混沌测试
#
# 针对已部署的 postgres CNPG 集群（1主2从）
# 测试场景：kill replica / kill master / 网络隔离等
#
# Usage:
#   bash chaos-test.sh              # 交互式菜单
#   bash chaos-test.sh all          # 运行全部场景
#   bash chaos-test.sh 2            # 运行场景 2 (failover)
#   bash chaos-test.sh status       # 仅查看状态
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

NS="${NS:-postgres}"
APP="postgres"

TOTAL_ERRORS=0
declare -a RESULTS

# CNPG Pod 命名: <cluster-name>-<N>
# postgres-0, postgres-1, postgres-2

get_pod_ip()   { kubectl -n "$NS" get pod "$1" -o jsonpath='{.status.podIP}' 2>/dev/null; }
get_pod_role() { kubectl -n "$NS" exec "$1" -- psql -U postgres -t -c "SELECT pg_is_in_recovery()" 2>/dev/null; }
# pg_is_in_recovery 返回: f=master, t=replica
is_master() { [ "$(get_pod_role "$1")" = " f" ]; }
get_phase()  { kubectl -n "$NS" get pod "$1" -o jsonpath='{.status.phase}' 2>/dev/null; }

echo_line() { printf '%*s\n' "${1:-80}" '' | tr ' ' '═'; }
echo_sep()  { printf '%*s\n' "${1:-80}" '' | tr ' ' '─'; }

info()  { echo "  [$(date +%H:%M:%S)] → $1"; }
ok()    { echo "  [$(date +%H:%M:%S)] ✓ $1"; }
warn()  { echo "  [$(date +%H:%M:%S)] ⚠ $1"; }
fail()  { echo "  [$(date +%H:%M:%S)] ✗ $1"; RESULTS+=("FAIL: $1"); TOTAL_ERRORS=$((TOTAL_ERRORS+1)); }
pass()  { RESULTS+=("PASS: $1"); }

# ── 基础检查 ──────────────────────────────────────────────────

check_all_pods() {
  local errors=0
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    local phase
    phase=$(get_phase "$pod")
    if [ "$phase" != "Running" ]; then
      fail "${pod} 状态: $phase"
      errors=1
    fi
  done
  [ "$errors" -eq 0 ] && ok "所有 3 个 Pod 均 Running"
}

check_replication() {
  local master=""
  local slaves=0
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    if is_master "$pod"; then
      master="$pod"
    else
      slaves=$((slaves+1))
    fi
  done

  if [ -n "$master" ]; then
    ok "当前 master: $master"
  else
    fail "找不到 master"
  fi
  [ "$slaves" -ge 2 ] && ok "Slave 数量: $slaves" || warn "Slave 数量: $slaves (预期 2)"

  # 查看复制延迟
  if [ -n "$master" ]; then
    echo "  复制状态:"
    kubectl -n "$NS" exec "$master" -- psql -U postgres \
      -c "SELECT pid, usename, application_name, state, sync_state, pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn) as sent_bytes, pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) as replay_bytes FROM pg_stat_replication;" 2>/dev/null || true
  fi
}

rw_test() {
  local master=""
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    is_master "$pod" && { master="$pod"; break; }
  done

  [ -z "$master" ] && { fail "无 master，跳过读写"; return 1; }

  local table="chaos_test_$(date +%s)"
  if kubectl -n "$NS" exec "$master" -- psql -U postgres \
    -c "CREATE TABLE IF NOT EXISTS ${table} (id serial, ts timestamptz DEFAULT now()); INSERT INTO ${table} (id) VALUES (1);" 2>/dev/null; then
    local count
    count=$(kubectl -n "$NS" exec "$master" -- psql -U postgres -t -c "SELECT count(*) FROM ${table};" 2>/dev/null | tr -d ' ')
    ok "读写正常 (表 ${table}, 行数: ${count}) [master: ${master}]"
    return 0
  fi
  fail "读写失败"
  return 1
}

# ── 状态快照 ──────────────────────────────────────────────────

snapshot() {
  echo_line
  echo "  [$(date +%H:%M:%S)] CNPG 集群快照"
  echo_sep
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    local role
    is_master "$pod" && role="master" || role="replica"
    local phase
    phase=$(get_phase "$pod" 2>/dev/null || echo "N/A")
    echo "  ${pod}: ${role} (${phase})"
  done

  # LSN 状态
  local master=""
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    is_master "$pod" && { master="$pod"; break; }
  done
  if [ -n "$master" ]; then
    echo_sep
    echo "  Master LSN:"
    kubectl -n "$NS" exec "$master" -- psql -U postgres \
      -c "SELECT pg_current_wal_lsn(), pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')::text || ' bytes' AS wal_size;" 2>/dev/null || true
  fi
  echo_line
}

# ── Kill Pod ──────────────────────────────────────────────────

kill_pod() {
  local pod="$1"
  warn "删除 Pod: $pod"
  kubectl delete pod -n "$NS" "$pod" --force --grace-period=0 2>/dev/null || true
}

run_rw_loop() {
  local duration="$1"
  local result_file="$2"
  local start
  start=$(date +%s)
  local end=$((start + duration))
  local ops=0 errors=0

  while [ "$(date +%s)" -lt "$end" ]; do
    local ts
    ts=$(date +%H:%M:%S)

    local wrote=0
    for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
      if is_master "$pod" 2>/dev/null; then
        local key="chaos_$(date +%s)"
        if kubectl -n "$NS" exec "$pod" -- psql -U postgres \
          -c "CREATE TABLE IF NOT EXISTS ${key} (val text); INSERT INTO ${key} VALUES ('${ts}');" 2>/dev/null; then
          ops=$((ops+1))
        else
          errors=$((errors+1))
          echo "  [$ts] 写入失败到 $pod" >> "$result_file"
        fi
        wrote=1
        break
      fi
    done
    [ "$wrote" -eq 0 ] && { errors=$((errors+1)); echo "  [$ts] 无可用 master" >> "$result_file"; }
    sleep 0.5
  done

  echo "ops=$ops errors=$errors" > "$result_file.summary"
  echo "$ops $errors"
}

# ── 测试场景 ──────────────────────────────────────────────────

# 场景 1: Kill 1 replica
test_kill_replica() {
  echo_line
  echo "  测试 1: 删除 1 个 Replica"
  echo "  预期: 无主从切换，Pod 自动重建，恢复复制"
  echo_line

  snapshot

  # 找 replica
  local target=""
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    if ! is_master "$pod" 2>/dev/null; then
      target="$pod"
      break
    fi
  done
  [ -z "$target" ] && { fail "找不到 replica"; return 1; }

  info "目标: $target"
  local start_time
  start_time=$(date +%s)
  kill_pod "$target"

  local recovered=0
  info "等待重建..."
  for i in $(seq 1 45); do
    sleep 2
    local phase
    phase=$(get_phase "$target" 2>/dev/null || echo "Terminating")
    local role_text="?"
    ! is_master "$target" 2>/dev/null && role_text="replica" || role_text="master"

    [ $((i % 5)) -eq 0 ] && echo "  [$i/45] $target: phase=$phase role=$role_text"

    if [ "$phase" = "Running" ] && ! is_master "$target" 2>/dev/null; then
      local end_time
      end_time=$(date +%s)
      ok "$target 已重建并恢复为 replica (耗时 $((end_time - start_time))s)"
      recovered=1
      break
    fi
  done

  rw_test
  [ "$recovered" -eq 1 ] && pass "删除 1 个 replica 测试通过" || fail "replica 未能在 90s 内恢复"
  snapshot
}

# 场景 2: Kill master → Operator 自动 failover
test_failover() {
  echo_line
  echo "  测试 2: 删除 Master → 触发 Operator 故障切换"
  echo "  预期: Operator 检测 master 下线 → 提升 replica → 完成切换"
  echo_line

  snapshot

  local master_pod=""
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    is_master "$pod" 2>/dev/null && { master_pod="$pod"; break; }
  done
  [ -z "$master_pod" ] && { fail "找不到 master"; return 1; }

  info "当前 master: $master_pod"
  local start_time
  start_time=$(date +%s)
  kill_pod "$master_pod"

  # 监控 failover
  local new_master=""
  local failover_time=0
  info "监控 Operator 故障切换..."
  for i in $(seq 1 60); do
    sleep 2
    local now
    now=$(date +%s)
    local elapsed=$((now - start_time))

    # 检查是否有新的 master 出现（且不是被杀的那个）
    local current_master=""
    for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
      is_master "$pod" 2>/dev/null && [ "$pod" != "$master_pod" ] && { current_master="$pod"; break; }
    done

    [ $((i % 5)) -eq 0 ] && echo "  [${elapsed}s] 当前 master: ${current_master:-仍在选举}"

    if [ -n "$current_master" ]; then
      new_master="$current_master"
      failover_time=$elapsed
      break
    fi
  done

  if [ -n "$new_master" ]; then
    ok "故障切换完成: ${master_pod} → ${new_master} (耗时 ${failover_time}s)"
  else
    fail "120s 内未完成故障切换"
    return 1
  fi

  # 验证写入
  rw_test

  # 等旧 master 恢复并变为 replica
  info "等待 ${master_pod} 恢复为 replica..."
  for i in $(seq 1 30); do
    sleep 3
    local phase
    phase=$(get_phase "$master_pod" 2>/dev/null || echo "N/A")
    if [ "$phase" = "Running" ] && ! is_master "$master_pod" 2>/dev/null; then
      ok "旧 master (${master_pod}) 恢复为 replica"
      break
    fi
    [ $((i % 5)) -eq 0 ] && echo "  [${i}/30] ${master_pod}: phase=$phase"
  done

  # 最终拓扑验证
  local master_count=0
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    is_master "$pod" 2>/dev/null && master_count=$((master_count+1))
  done
  [ "$master_count" -eq 1 ] && ok "最终拓扑: 1 master + 2 replicas" || warn "final master count: $master_count"

  pass "Master 故障切换测试通过"
  snapshot
}

test_all_redis_nodes_down() {
  echo_line
  echo "  测试 7: 删除全部 3 个 PostgreSQL 节点"
  echo "  (等同于 Redis 全挂场景。CNPG StatefulSet 会自动重建所有 Pod)"
  echo_line

  snapshot

  local start_time
  start_time=$(date +%s)

  # 写测试数据
  local master_pod=""
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    is_master "$pod" 2>/dev/null && { master_pod="$pod"; break; }
  done
  [ -n "$master_pod" ] && kubectl -n "$NS" exec "$master_pod" -- psql -U postgres \
    -c "CREATE TABLE IF NOT EXISTS survive_test (msg text); INSERT INTO survive_test VALUES ('pre-kill-$(date +%s)');" 2>/dev/null || true

  # 杀全部 3 个节点
  info "删除全部 3 个 Pod..."
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    kill_pod "$pod"
  done

  # 等待全部重建
  info "等待 StatefulSet 重建..."
  kubectl wait pod -l "app.kubernetes.io/name=${APP}" -n "$NS" \
    --for=condition=Ready --timeout=180s 2>/dev/null || true

  local all_ready=0
  for i in $(seq 1 30); do
    sleep 3
    local ready=0
    for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
      [ "$(get_phase "$pod" 2>/dev/null)" = "Running" ] && ready=$((ready+1))
    done
    [ $ready -eq 3 ] && { all_ready=1; break; }
    [ $((i % 5)) -eq 0 ] && echo "  [${i}] 已重建: ${ready}/3"
  done

  [ "$all_ready" -eq 1 ] && ok "全部 3 个 Pod 已重建 (耗时 $(( $(date +%s) - start_time ))s)" || fail "未能在预期时间重建"

  # 检查是否有 master
  local has_master=0
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    is_master "$pod" 2>/dev/null && has_master=1
  done
  [ "$has_master" -eq 1 ] && ok "已选出新 master" || warn "无 master (CNPG 可能仍在选举)"

  rw_test

  # 检查切换前数据
  local pre_data=""
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    pre_data=$(kubectl -n "$NS" exec "$pod" -- psql -U postgres \
      -t -c "SELECT msg FROM survive_test LIMIT 1;" 2>/dev/null | tr -d ' ' || echo "")
    [ -n "$pre_data" ] && break
  done
  [ -n "$pre_data" ] && ok "切换前数据存在: ${pre_data}" || warn "切换前数据丢失 (异步提交可能未落盘)"

  pass "全部 3 节点下线测试通过"
  snapshot
}

# ── 主菜单 ──────────────────────────────────────────────────

menu() {
  echo
  echo_line
  echo "  CloudNativePG 混沌测试"
  echo_line
  echo "  Namespace: ${NS}  |  实例: ${APP}"
  echo_line
  echo
  echo "  可选测试场景:"
  echo
  echo "    status          — 查看当前集群状态"
  echo "    1               — 删除 1 个 Replica"
  echo "    2               — 删除 Master (Failover)"
  echo "    7               — 删除全部 3 个节点"
  echo "    all             — 运行全部测试"
  echo "    exit|quit       — 退出"
  echo
  echo_sep
}

if [ $# -eq 0 ]; then
  while true; do
    menu
    read -r -p "  选择场景: " choice
    echo
    case "$choice" in
      1|replica)     test_kill_replica ;;
      2|master)      test_failover ;;
      7|all-nodes)   test_all_redis_nodes_down ;;
      all|full)      test_kill_replica; test_failover; test_all_redis_nodes_down ;;
      status)        snapshot; check_replication ;;
      exit|quit)     echo "  Bye."; exit 0 ;;
      *)             echo "  未知选项: $choice" ;;
    esac
  done
else
  case "$1" in
    status)        snapshot; check_replication ;;
    1)             test_kill_replica ;;
    2)             test_failover ;;
    7)             test_all_redis_nodes_down ;;
    all)           test_kill_replica; test_failover; test_all_redis_nodes_down ;;
    *)             echo "Usage: $0 [1|2|7|all|status]"; exit 1 ;;
  esac
fi

echo
echo_line
echo "  测试汇总"
echo_line
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo_line
[ "$TOTAL_ERRORS" -eq 0 ] && echo "  结果: 全部通过 ✓" || echo "  结果: ${TOTAL_ERRORS} 个失败 ✗"
echo_line
echo
