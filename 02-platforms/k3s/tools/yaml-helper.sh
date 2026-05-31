#!/bin/bash
# YAML 配置解析工具
# 用于在 shell 脚本中读取 YAML 配置
# 依赖: yq (https://github.com/mikefarah/yq) 或 python

# ==============================================
# 检查 YAML 解析工具
# ==============================================
check_yq_tool() {
    if command -v yq &> /dev/null; then
        echo "yq"
    elif command -v python3 &> /dev/null; then
        echo "python"
    else
        echo ""
    fi
}

# ==============================================
# 使用 yq 读取 YAML
# ==============================================
read_yaml_yq() {
    local file="$1"
    local key="$2"
    yq -r "$key" "$file" 2>/dev/null
}

# ==============================================
# 使用 Python 读取 YAML
# ==============================================
read_yaml_python() {
    local file="$1"
    local key="$2"
    
    # 转换 jq 风格的路径为 Python 字典访问
    key=$(echo "$key" | sed 's/^\.//; s/\./\["/g; s/\([^"]*\)$/\1"\]/')
    
    python3 -c "
import yaml
import sys
try:
    with open('$file', 'r') as f:
        data = yaml.safe_load(f)
    value = data$key
    if isinstance(value, list):
        print('\n'.join(str(x) for x in value))
    elif isinstance(value, bool):
        print(str(value).lower())
    elif value is not None:
        print(str(value))
except Exception:
    pass
" 2>/dev/null
}

# ==============================================
# 读取 YAML 配置（通用函数）
# ==============================================
yaml_get() {
    local file="$1"
    local key="$2"
    
    if [ ! -f "$file" ]; then
        echo ""
        return
    fi
    
    local tool=$(check_yq_tool)
    
    if [ "$tool" = "yq" ]; then
        read_yaml_yq "$file" "$key"
    elif [ "$tool" = "python" ]; then
        read_yaml_python "$file" "$key"
    else
        echo ""
    fi
}

# ==============================================
# 读取 YAML 布尔值
# ==============================================
yaml_get_bool() {
    local file="$1"
    local key="$2"
    local default="${3:-false}"
    
    local value=$(yaml_get "$file" "$key")
    
    if [ -z "$value" ]; then
        echo "$default"
        return
    fi
    
    if [ "$value" = "true" ] || [ "$value" = "True" ] || [ "$value" = "yes" ] || [ "$value" = "1" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# ==============================================
# 读取 YAML 字符串（带默认值）
# ==============================================
yaml_get_str() {
    local file="$1"
    local key="$2"
    local default="${3:-}"
    
    local value=$(yaml_get "$file" "$key")
    
    if [ -z "$value" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}
