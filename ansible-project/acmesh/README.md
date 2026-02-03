acme.sh 证书分发到 web 服务器


```bash
# 1. 需要注册邮箱
acme.sh --register-account -m 1219946450@qq.com

# 2. 云产商的 acckesskey 和 Secret
# 阿里云
export Ali_Key="<key>"
export Ali_Secret="<secret>"
# 腾讯云
export Tencent_SecretId="<Your SecretId>"
export Tencent_SecretKey="<Your SecretKey>"


# 3. 开始申请证书
# 申请泛域名证书 *.demo.czwlinux.cloud
# 证书URL
CERT=demo.czwlinux.cloud
# 申请证书
acme.sh --issue --dns dns_ali -d $CERT -d *.$CERT
# 安装并到期自动更新证书
acme.sh --install-cert -d *.$CERT \
  --key-file /data/ssl/$CERT.key \
  --fullchain-file /data/ssl/$CERT.pem \
  --reloadcmd "docker exec nginx nginx -s reload"
# 移除不必要的证书：
acme.sh  --remove  -d  $CERT


# 实际示例 申请泛域名证书 *.czwlinux.cloud
CERT=czwlinux.cloud
# 申请泛域名证书，必须要两个 -d 
acme.sh --issue --dns dns_ali -d *.$CERT -d $CERT
# 申请单个域名证书
acme.sh --issue --dns dns_ali -d $CERT

# 自动申请证书，以及配置 reloadcmd 命令
acme.sh --install-cert -d *.${CERT} \
  --key-file /data/opsdir/project/nginx/ssl/${CERT}.key \
  --fullchain-file /data/opsdir/project/nginx/ssl/${CERT}.pem \
  --reloadcmd "bash /data/opsdir/ansible/nginx-ssl/push.sh"

# 查询证书文件
ls -ahl /data/opsdir/project/nginx/ssl/

```