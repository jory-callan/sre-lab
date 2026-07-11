#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# chaos-test.sh — Redis Sentinel 混沌测试
#
# 针对已部署的 redis (Replication) + redis-sentinel
# 测试场景：kill replica / kill master / kill sentinel / 仲裁丢失
#
# Usage:
#   bash chaos-test.sh              # 交互式菜单
#   bash chaos-test.sh all          # 运行全部场景
#   bash chaos-test.sh 2            # 运行场景 2 (failover)
#   bash chaos-test.sh status       # 仅查看状态
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

NS="${NS:-redis}"
APP="redis"
SENTINEL="redis-sentinel"

TOTAL_ERRORS=0
declare -a RESULTS

get_pod_ip()     { kubectl -n "$NS" get pod "$1" -o jsonpath='{.status.podIP}' 2>/dev/null; }
get_pod_role()   { kubectl exec -n "$NS" "$1" -- redis-cli ROLE 2>/dev/null | head -1; }
get_phase()      { kubectl -n "$NS" get pod "$1" -o jsonpath='{.status.phase}' 2>/dev/null; }
get_sentinel_master()  { kubectl exec -n "$NS" "${SENTINEL}-0" -- redis-cli -p 26379 SENTINEL GET-MASTER-ADDR-BY-NAME redis 2>/dev/null | head -1; }
get_sentinel_info()   { kubectl exec -n "$NS" "${SENTINEL}-0" -- redis-cli -p 26379 INFO sentinel 2>/dev/null | grep "master0"; }

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
  for pod in "${APP}-0" "${APP}-1" "${APP}-2" "${SENTINEL}-0" "${SENTINEL}-1" "${SENTINEL}-2"; do
    local phase
    phase=$(get_phase "$pod" 2>/dev/null)
    [ "$phase" != "Running" ] && { fail "${pod} 状态: $phase"; errors=1; }
  done
  [ "$errors" -eq 0 ] && ok "所有 6 个 Pod 均 Running"
}

check_replication() {
  local master=""
  local slaves=0
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    local role
    role=$(get_pod_role "$pod" 2>/dev/null)
    [ "$role" = "master" ] && master="$pod"
    echo "$role" | grep -q "slave" && slaves=$((slaves+1))
  done
  [ -n "$master" ] && ok "当前 master: $master" || fail "找不到 master"
  [ "$slaves" -ge 2 ] && ok "Slave 数量: $slaves" || warn "Slave 数量: $slaves"
}

check_sentinel() {
  local master_ip
  master_ip=$(get_sentinel_master 2>/dev/null || echo "")
  [ -n "$master_ip" ] && [ "$master_ip" != "nil" ] && ok "Sentinel master: $master_ip" || fail "Sentinel 无法获取 master"
  local sinfo
  sinfo=$(get_sentinel_info 2>/dev/null || echo "N/A")
  echo "  Sentinel: $sinfo"
}

rw_test() {
  local master_pod=""
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    [ "$(get_pod_role "$pod" 2>/dev/null)" = "master" ] && { master_pod="$pod"; break; }
  done
  [ -z "$master_pod" ] && { fail "无 master"; return 1; }

  local key="chaos-$(date +%s)"
  if kubectl exec -n "$NS" "$master_pod" -- redis-cli SET "$key" "ok-$(date +%H:%M:%S)" 2>/dev/null; then
    local val
    val=$(kubectl exec -n "$NS" "$master_pod" -- redis-cli GET "$key" 2>/dev/null)
    echo "$val" | grep -q "ok-" && ok "读写正常 [master: ${master_pod}]" && return 0
  fi
  fail "读写失败"
  return 1
}

# ── 状态快照 ──────────────────────────────────────────────────

snapshot() {
  echo_line
  echo "  [$(date +%H:%M:%S)] 集群快照"
  echo_sep
  for pod in "${APP}-0" "${APP}-1" "${APP}-2" "${SENTINEL}-0" "${SENTINEL}-1" "${SENTINEL}-2"; do
    local role="" phase
    phase=$(get_phase "$pod" 2>/dev/null || echo "N/A")
    echo "$pod" | grep -q "sentinel" && role="sentinel" || role=$(get_pod_role "$pod" 2>/dev/null || echo "N/A")
    echo "  ${pod}: ${role} (${phase})"
  done
  echo_sep
  echo "  $(get_sentinel_info 2>/dev/null || echo 'Sentinel: N/A')"
  echo_line
}

# ── Kill Pod ──────────────────────────────────────────────────

kill_pod() {
  warn "删除 Pod: $1"
  kubectl delete pod -n "$NS" "$1" --force --grace-period=0 2>/dev/null || true
}

# ── 测试场景 ──────────────────────────────────────────────────

# 场景 1: Kill 1 replica
test_kill_replica() {
  echo_line
  echo "  测试 1: 删除 1 个 Slave"
  echo_line
  snapshot

  local target=""
  for pod in "${APP}-1" "${APP}-2"; do
    local role
    role=$(get_pod_role "$pod" 2>/dev/null)
    if echo "$role" | grep -q "slave"; then target="$pod"; break; fi
  done
  [ -z "$target" ] && { fail "找不到 slave"; return 1; }

  info "目标: $target"
  local start_time
  start_time=$(date +%s)
  kill_pod "$target"

  local recovered=0
  for i in $(seq 1 45); do
    sleep 2
    local phase role
    phase=$(get_phase "$target" 2>/dev/null || echo "Terminating")
    role=$(get_pod_role "$target" 2>/dev/null || echo "N/A")
    if [ $((i % 5)) -eq 0 ]; then echo "  [$i/45] $target: phase=$phase role=$role"; fi
    if [ "$phase" = "Running" ] && echo "$role" | grep -q "slave"; then
      ok "$target 已重建 (耗时 $(( $(date +%s) - start_time ))s)"
      recovered=1; break
    fi
  done

  rw_test
  [ "$recovered" -eq 1 ] && pass "删除 slave 测试通过" || fail "slave 未恢复"
  snapshot
}

# 场景 2: Kill master → failover
test_failover() {
  echo_line
  echo "  测试 2: 删除 Master → Sentinel 故障切换"
  echo_line
  snapshot

  local master_pod master_ip
  master_pod=""; master_ip=""
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    [ "$(get_pod_role "$pod" 2>/dev/null)" = "master" ] && { master_pod="$pod"; master_ip=$(get_pod_ip "$pod"); break; }
  done
  [ -z "$master_pod" ] && { fail "找不到 master"; return 1; }

  # 写入测试数据
  kubectl exec -n "$NS" "$master_pod" -- redis-cli SET failover-test "before-$(date +%s)" 2>/dev/null || true
  info "当前 master: $master_pod ($master_ip)"
  local start_time
  start_time=$(date +%s)
  kill_pod "$master_pod"

  local new_master="" failover_time=0
  for i in $(seq 1 60); do
    sleep 2
    local elapsed=$(( $(date +%s) - start_time ))
    local current_master_ip
    current_master_ip=$(get_sentinel_master 2>/dev/null || echo "")

    [ $((i % 5)) -eq 0 ] && echo "  [${elapsed}s] sentinel master=$current_master_ip"

    if [ -n "$current_master_ip" ] && [ "$current_master_ip" != "$master_ip" ] && [ "$current_master_ip" != "nil" ]; then
      for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
        local pip role
        pip=$(get_pod_ip "$pod" 2>/dev/null || echo "")
        role=$(get_pod_role "$pod" 2>/dev/null || echo "")
        if { [ "$pip" = "$current_master_ip" ] || [ "$role" = "master" ]; } && [ "$pod" != "$master_pod" ]; then
          new_master="$pod"; failover_time=$elapsed; break 2
        fi
      done
    fi
  done

  [ -n "$new_master" ] && ok "故障切换: ${master_pod} → ${new_master} (${failover_time}s)" || { fail "120s 内未完成切换"; return 1; }

  # 验证数据
  local test_val
  test_val=$(kubectl exec -n "$NS" "$new_master" -- redis-cli GET failover-test 2>/dev/null || echo "")
  echo "$test_val" | grep -q "before-" && ok "数据完整" || warn "切换前数据不可读"

  rw_test

  # 等旧 master 恢复为 slave
  for i in $(seq 1 30); do
    sleep 3
    local phase role
    phase=$(get_phase "$master_pod" 2>/dev/null || echo "N/A")
    role=$(get_pod_role "$master_pod" 2>/dev/null || echo "N/A")
    [ "$phase" = "Running" ] && echo "$role" | grep -q "slave" && { ok "旧 master 恢复为 slave"; break; }
    [ $((i % 5)) -eq 0 ] && echo "  [${i}/30] ${master_pod}: $role ($phase)"
  done

  local final_role=0
  local final_master=""
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    local role
    role=$(get_pod_role "$pod" 2>/dev/null || echo "?")
    [ "$role" = "master" ] && { final_role=$((final_role+1)); final_master="$pod"; }
  done
  [ "$final_role" -eq 1 ] && ok "最终: 1 master ($final_master) + 2 slaves" || warn "master 数量: $final_role"

  pass "Master 故障切换测试通过"
  snapshot
}

# 场景 3: Kill 1 sentinel
test_kill_sentinel() {
  echo_line
  echo "  测试 3: 删除 1 个 Sentinel"
  echo_line
  snapshot

  local target="${SENTINEL}-0"
  local start_time
  start_time=$(date +%s)
  kill_pod "$target"
  sleep 5

  rw_test

  for i in $(seq 1 15); do
    sleep 2
    [ "$(get_phase "$target" 2>/dev/null)" = "Running" ] && { ok "Sentinel 已重建 (耗时 $(( $(date +%s) - start_time ))s)"; break; }
  done

  pass "删除 1 个 Sentinel 测试通过"
  snapshot
}

# 场景 5: Kill 2 sentinels (quorum 丢失)
test_quorum_lost() {
  echo_line
  echo "  测试 5: 删除 2 个 Sentinels (仲裁丢失)"
  echo "  预期: 剩余 1 个 sentinel 无法满足 quorum，不应发生切换"
  echo_line
  snapshot

  local master_before
  master_before=$(get_sentinel_master)

  kill_pod "${SENTINEL}-1"
  kill_pod "${SENTINEL}-2"
  sleep 3

  info "剩余 sentinel 状态:"
  echo "  $(get_sentinel_info 2>/dev/null || echo 'N/A')"
  sleep 5

  local master_pod=""
  for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
    [ "$(get_pod_role "$pod" 2>/dev/null)" = "master" ] && { master_pod="$pod"; break; }
  done

  local saw_failover=0
  if [ -n "$master_pod" ]; then
    info "杀死 master (仲裁不足情况下)..."
    kill_pod "$master_pod"
    sleep 10

    local current_master_ip
    current_master_ip=$(get_sentinel_master 2>/dev/null || echo "")
    if [ -n "$current_master_ip" ] && [ "$current_master_ip" != "$master_before" ] && [ "$current_master_ip" != "nil" ]; then
      for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
        [ "$(get_pod_role "$pod" 2>/dev/null)" = "master" ] && [ "$pod" != "$master_pod" ] && { warn "⚠ 仲裁不足时仍发生了切换"; saw_failover=1; break; }
      done
    fi
  fi

  [ "$saw_failover" -eq 0 ] && ok "仲裁不足时未自动切换 (符合预期)" || warn "仲裁不足时发生了切换"

  # 恢复
  kubectl wait pod --for=condition=Ready -l "app.kubernetes.io/name=${SENTINEL}" -n "$NS" --timeout=120s 2>/dev/null || true
  sleep 10

  for i in $(seq 1 30); do
    sleep 3
    local master_count=0
    for pod in "${APP}-0" "${APP}-1" "${APP}-2"; do
      [ "$(get_pod_role "$pod" 2>/dev/null)" = "master" ] && master_count=$((master_count+1))
    done
    [ "$master_count" -eq 1 ] && { ok "集群已恢复"; rw_test; break; }
    [ $((i % 5)) -eq 0 ] && echo "  [${i}/30] masters=$master_count"
  done

  pass "Sentinel 仲裁丢失测试通过"
  snapshot
}

# 场景 6: Kill 3 sentinels (全部下线)
test_all_sentinels_down() {
  echo_line
  echo "  测试 6: 删除全部 3 个 Sentinels"
  echo_line
  snapshot

  local start_time
  start_time=$(date +%s)
  for i in 0 1 2; do kill_pod "${SENTINEL}-${i}"; done
  sleep 5

  rw_test

  kubectl wait pod --for=condition=Ready -l "app.kubernetes.io/name=${SENTINEL}" -n "$NS" --timeout=120s 2>/dev/null || true
  ok "全部 Sentinels 恢复 (耗时 $(( $(date +%s) - start_time ))s)"
  pass "全部 Sentinels 下线测试通过"
}

# ── 主菜单 ──────────────────────────────────────────────────

menu() {
  echo
  echo_line
  echo "  Redis Sentinel 混沌测试"
  echo_line
  echo "  Namespace: ${NS}  |  实例: ${APP} / ${SENTINEL}"
  echo_line
  echo
  echo "  可选测试场景:"
  echo
  echo "    status          — 查看当前集群状态"
  echo "    1               — 删除 1 个 Slave"
  echo "    2               — 删除 Master (Failover)"
  echo "    3               — 删除 1 个 Sentinel"
  echo "    5               — 删除 2 个 Sentinels (仲裁丢失)"
  echo "    6               — 删除全部 3 个 Sentinels"
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
      1|slave)         test_kill_replica ;;
      2|master)        test_failover ;;
      3|1sentinel)     test_kill_sentinel ;;
      5|quorum)        test_quorum_lost ;;
      6|allsentinel)   test_all_sentinels_down ;;
      all|full)        test_kill_replica; test_failover; test_kill_sentinel; test_quorum_lost; test_all_sentinels_down ;;
      status)          snapshot ;;
      exit|quit)       echo "  Bye."; exit 0 ;;
      *)               echo "  未知选项: $choice" ;;
    esac
  done
else
  case "$1" in
    status)   snapshot ;;
    1)        test_kill_replica ;;
    2)        test_failover ;;
    3)        test_kill_sentinel ;;
    5)        test_quorum_lost ;;
    6)        test_all_sentinels_down ;;
    all)      test_kill_replica; test_failover; test_kill_sentinel; test_quorum_lost; test_all_sentinels_down ;;
    *)        echo "Usage: $0 [1|2|3|5|6|all|status]"; exit 1 ;;
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
