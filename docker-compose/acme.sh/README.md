# 使用方法
vi .env 确定 SSL_DIR 目录

# 检查证书有效期
./tools/check_ssl.sh h5.czwlinux.cloud
./tools/check_ssl.sh /data/ssl/h5.czwlinux.cloud.cer

# 参考
https://github.com/acmesh-official/acme.sh/wiki/Run-acme.sh-in-docker

``` bash

# office document url : https://github.com/acmesh-official/acme.sh/wiki/dnsapi2
# 阿里云
export Ali_Key="<key>"
export Ali_Secret="<secret>"
acme.sh --issue --dns dns_ali -d example.com -d *.example.com

# 腾讯云
export Tencent_SecretId="<Your SecretId>"
export Tencent_SecretKey="<Your SecretKey>"
acme.sh --issue --dns dns_tencent -d example.com -d *.example.com

#需要注册邮箱
acme.sh --register-account -m xxxxx@xx.xxx


# 签署指定域名证书
# 证书URL
CERT=demo.czwlinux.cloud
# 申请证书
acme.sh --issue --dns dns_ali -d $CERT
# 安装并到期自动更新证书
acme.sh --install-cert -d $CERT \
  --key-file /data/ssl/$CERT.key \
  --fullchain-file /data/ssl/$CERT.cer \
  --reloadcmd "docker exec nginx nginx -s reload"
# 移除不必要的证书：
acme.sh  --remove  -d  $CERT



# 申请泛域名证书
# 证书URL
CERT=demo.czwlinux.cloud
# 申请证书
acme.sh --issue --dns dns_ali -d $CERT -d *.$CERT
# 安装并到期自动更新证书
acme.sh --install-cert -d *.$CERT \
  --key-file /data/ssl/$CERT.key \
  --fullchain-file /data/ssl/$CERT.cer \
  --reloadcmd "docker exec nginx nginx -s reload"
# 移除不必要的证书：
acme.sh  --remove  -d  $CERT




docker compose up -d
docker exec acmesh --help
docker exec acmesh acme.sh --info
docker exec acmesh --register-account -m xxxxx@xx.xxx
docker exec acmesh --issue --dns dns_tencent -d czwlinux.cloud -d *.czwlinux.cloud
# nginx-ssl
docker exec acmesh --install-cert -d czwlinux.cloud -d *.czwlinux.cloud --key-file /ssl-dir/$CERT.key --fullchain-file /ssl-dir/czwlinux.cloud.cer  --reloadcmd "echo '======= acme auto reload cmd here =========' "

cp out/czwlinux.cloud_ecc/fullchain.cer  ../nginx/ssl/czwlinux.cloud.cer
cp out/czwlinux.cloud_ecc/czwlinux.cloud.key  ../nginx/ssl/czwlinux.cloud.key

# nginx config
ssl_certificate ssl/czwlinux.cloud.cer;
ssl_certificate_key ssl/czwlinux.cloud.key;

# 写一个定时任务 或者 将 acme.sh 安装到本机
# 添加自动更新任务
# 10 0 * * * docker exec acmesh --cron > /dev/null
# 10 1 * * * nginx -s reload    # 重新加载nginx配置

# 自 1.15.9+ , nginx 会自动重载
# ssl_certificate ssl/default.crt;
# ssl_certificate_key ssl/default.key;

```