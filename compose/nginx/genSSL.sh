#!/bin/bash
 
# 输入参数
read -p "请输入域名(默认www.demo.com):" DOMAIN
DOMAIN=${DOMAIN:-www.demo.com}

read -p "请输入私钥密码(默认123456):" PASSWD
PASSWD=${PASSWD:-123456} 
echo $PASSWD > $DOMAIN.passwd.txt

read -p "请输入证书过期时间(默认36500):" DAYS  
DAYS=${DAYS:-36500}

# 生成CA密钥和证书 
echo "生成 CA 秘钥"
openssl genrsa  -passout file:$DOMAIN.passwd.txt  -aes128 -out $DOMAIN.ca.key 2048 

echo "生成 CA 无密码秘钥"
openssl rsa  -passin file:$DOMAIN.passwd.txt  -in $DOMAIN.ca.key  -out $DOMAIN.ca.no.key

echo "生成 CA 根证书"
SUBJECT="/C=US/SN=NYC/L=HardCorp-1/O=Organization/OU=HardCorp-1/CN=$DOMAIN"
openssl req -new -x509 -days $DAYS  -sha1 -extensions v3_ca -subj "$SUBJECT" -key $DOMAIN.ca.no.key -out $DOMAIN.ca.crt

# 生成服务器密钥
echo "生成 server 秘钥"
openssl genrsa  -passout file:$DOMAIN.passwd.txt -aes128 -out $DOMAIN.server.key 2048 

# 生成无密码密钥
echo "生成 server 无密码秘钥"
openssl rsa -passin file:$DOMAIN.passwd.txt  -in $DOMAIN.server.key -out $DOMAIN.server.no.key

# 生成服务器CSR和证书
echo "生成 server 证书请求文件 csr"
#SUBJECT="/C=US/SN=NYC/L=HardCorp-1/O=Organization/OU=HardCorp-1/CN=$DOMAIN"
openssl req -new -days $DAYS -sha1 -extensions v3_ca -subj "$SUBJECT" -key $DOMAIN.server.no.key -out  $DOMAIN.server.csr
echo "使用 CA 证书签名 server 证书"
#这个生成的文件名 www.srl 序列号文件，用于记录CA已经签发了多少证书,用于证书序列号的唯一性。每个签名证书的序列号会递增,避免重复。
openssl x509 -days $DAYS -req -in $DOMAIN.server.csr -CA $DOMAIN.ca.crt -CAkey $DOMAIN.ca.no.key -CAcreateserial -out $DOMAIN.server.crt 

# 输出位置
echo "证书位置:/$DOMAIN.server.crt"
echo "密钥位置:/$DOMAIN.server.no.key"

echo """
SSL/TLS证书中的相关文件格式的概念如下:
    CA根证书(ca.crt):用于签发下级证书的自签名证书,代表证书颁发机构。
    服务端证书(server.crt):部署在服务端,由CA签发,用于向客户端表明服务器身份。
    客户端证书(client.crt):部署在客户端,由CA签发,用于向服务器表明客户端身份。
    .key文件:包含证书对应的私钥,服务器端需要此文件。
    .csr文件:证书签名请求文件,申请证书时生成,提交给CA签发证书。
    .pem文件:PEM格式的证书文件,包含了证书信息,可读格式。
    .crt文件:通常就是PEM格式的证书文件,CRT是证书文件的常用扩展名。
"""

echo "TODO:"
echo "Copy $DOMAIN.crt to /etc/nginx/ssl/$DOMAIN.crt"
echo "Copy $DOMAIN.key to /etc/nginx/ssl/$DOMAIN.key"
echo "Add configuration in nginx:"
echo "server {"
echo "    ..."
echo "    listen 443 ssl;"
echo "    ssl_certificate     /etc/nginx/ssl/$DOMAIN.crt;"
echo "    ssl_certificate_key /etc/nginx/ssl/$DOMAIN.key;"
echo "}"