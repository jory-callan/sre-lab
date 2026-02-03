#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TODAY=$(date +%Y%m%d)
cd "$SCRIPT_DIR"

# Webhook 数组支持微信和钉钉
WEBHOOK_URLS=(
    "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=58ff0e2f-56f2-4b62-a172-e53e220140d2"
    "https://oapi.dingtalk.com/robot/send?access_token=0364e30848e069b1cc02572562230dc93828b0485eea745fcd1187a70498ea0a"
)

# 日志文件按天拆分
LOG_FILE="./push.sh_$TODAY.log"

echo "================ $(date '+%Y-%m-%d %H:%M:%S') ================" >> "$LOG_FILE"
# 执行 Ansible 并记录 使用 tee 实现屏幕显示 + 写入文件
ansible-playbook -i hosts nginx-reload-ssl-sync.yml 2>&1 | tee -a "$LOG_FILE"
# 捕获执行状态 (PIPESTATUS 获取管道第一个命令的退出码)
STATUS=${PIPESTATUS[0]}

# 判断结果
if [ $STATUS -eq 0 ]; then
    MSG_CONTENT="✅ SSL证书分发成功"
else
    MSG_CONTENT="❌ SSL证书分发失败\n请检查日志: $LOG_FILE"
fi

# 循环发送通知
for url in "${WEBHOOK_URLS[@]}"; do
    # 判断是否钉钉 & 是否失败 -> 触发 @所有人
    if [[ "$url" == *"dingtalk"* ]] && [ $STATUS -ne 0 ]; then
        #JSON_BODY="{\"msgtype\": \"text\", \"text\": {\"content\": \"$MSG_CONTENT\n@all\"}}"
        JSON_BODY="{\"msgtype\": \"text\", \"text\": {\"content\": \"$MSG_CONTENT\"}}"
    else
        JSON_BODY="{\"msgtype\": \"text\", \"text\": {\"content\": \"$MSG_CONTENT\"}}"
    fi
    
    # 发送请求
    curl -s -X POST "$url" -H "Content-Type: application/json" -d "$JSON_BODY" > /dev/null
done

