#!/bin/bash

# 用法提示
if [ $# -ne 1 ]; then
    echo "用法: $0 <域名 | 证书文件路径>"
    echo "例如: $0 h5.czwlinux.cloud"
    echo "例如: $0 /data/ssl/h5.czwlinux.cloud.cer"
    exit 1
fi

TARGET="$1"

# 如果是域名
if [[ "$TARGET" =~ ^https?:// ]] || [[ "$TARGET" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    DOMAIN="$TARGET"
    if [[ ! "$DOMAIN" =~ ^https?:// ]]; then
        DOMAIN="https://$DOMAIN"
    fi

    EXPIRE_DATE=$(echo | openssl s_client -servername "${TARGET}" -connect "${TARGET}:443" 2>/dev/null \
        | openssl x509 -noout -enddate \
        | cut -d= -f2)

# 如果是证书文件
elif [ -f "$TARGET" ]; then
    EXPIRE_DATE=$(openssl x509 -in "$TARGET" -noout -enddate | cut -d= -f2)
else
    echo "❌ 无法识别的目标：$TARGET"
    exit 1
fi

# 计算剩余天数
EXPIRE_TIMESTAMP=$(date -d "$EXPIRE_DATE" +%s)
NOW_TIMESTAMP=$(date +%s)

DAYS_LEFT=$(( (EXPIRE_TIMESTAMP - NOW_TIMESTAMP) / 86400 ))

echo "📅 SSL 证书到期时间: $EXPIRE_DATE"
echo "⏳ 剩余有效天数: $DAYS_LEFT 天"

if [ "$DAYS_LEFT" -lt 30 ]; then
    echo "⚠️  警告：证书即将过期！"
elif [ "$DAYS_LEFT" -lt 0 ]; then
    echo "❌  警告：证书已过期！"
else
    echo "✅ 证书有效"
fi

