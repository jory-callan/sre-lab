# 用于生成随机字符串，
# 使用场景: 生成随机密码.
# 使用方式: genpasswd 20
genpasswd() {
    local l=$1
    [ "$l" == "" ] && l=20
    tr -dc A-Za-z0-9_ < /dev/urandom | head -c ${l} | xargs
}
