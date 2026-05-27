#!/bin/bash
# ==========================================
# Temporal CLI Wrapper - 强制 Namespace Retention 为 1年！
# ==========================================
# 使用方法：
# 1. 把这个文件保存为 ~/bin/temporal
# 2. chmod +x ~/bin/temporal
# 3. 确保 ~/bin 在 PATH 最前面！
# ==========================================

# 真正的 temporal CLI（假设在 /usr/local/bin/temporal）
if [ -x "/usr/local/bin/temporal.real" ]; then
  REAL_TEMPORAL="/usr/local/bin/temporal.real"
elif [ -x "/usr/bin/temporal.real" ]; then
  REAL_TEMPORAL="/usr/bin/temporal.real"
else
  REAL_TEMPORAL="$(which temporal)"
fi

# 检查是否是 namespace create 命令
if [[ "$1" == "operator" && "$2" == "namespace" && "$3" == "create" ]]; then
  echo "🚀 使用 Temporal CLI Wrapper - 自动添加 --retention 8760h0m0s（1年）！"
  shift 3
  
  # 检查有没有传 --retention，如果有就不用再加了
  RETENTION_SET=0
  for arg in "$@"; do
    if [[ "$arg" == --retention* ]]; then
      RETENTION_SET=1
      break
    fi
  done
  
  if [ "$RETENTION_SET" -eq 0 ]; then
    echo "⚠️  自动添加 --retention 8760h0m0s！"
    exec "$REAL_TEMPORAL" operator namespace create --retention 8760h0m0s "$@"
  else
    echo "ℹ️  你已指定 --retention，使用你指定的值！"
    exec "$REAL_TEMPORAL" operator namespace create "$@"
  fi
else
  exec "$REAL_TEMPORAL" "$@"
fi