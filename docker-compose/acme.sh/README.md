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

#签署泛域名
#开始签名证书
acme.sh --issue --dns dns_tencent -d xxx.com -d *.xxx.com

#签署指定域名
#证书URL
CERT=ims-prod.jingxishenghuo1688.com
#申请证书：  #安装并到期自动更新证书：
acme.sh --issue --dns dns_ali -d $CERT
acme.sh --install-cert -d $CERT \
  --key-file /data/ssl/$CERT.key \
  --fullchain-file /data/ssl/$CERT.pem \
  --reloadcmd "docker exec nginx nginx -s reload"
# 移除不必要的证书：
acme.sh  --remove  -d  $CERT



docker compose up -d
docker exec acme.sh --help
docker exec acme.sh --issue -d example.com --standalone

```