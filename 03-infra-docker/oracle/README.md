# 部署 Oracle 11g 数据库
这里使用  registry.cn-hangzhou.aliyuncs.com/helowin/oracle_11g  镜像
2025年11月3日10:56:52  上面的现在新版本docker已经无法使用
现在使用  registry.cn-hangzhou.aliyuncs.com/akaiot/oracle_11g  镜像
可以拉取如下：
swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/akaiot/oracle_11g:latest
registry.cn-hangzhou.aliyuncs.com/akaiot/oracle_11g


# 部署
```bash
# 创建文件夹，此处作为数据库持久化目录
mkdir -p /data/oracle11g

cd  /data/oracle11g

# 创建 docker-compose 文件
cat > docker-compose.yml << EOF
version: "3.7"
services:
  app:
    image: registry.cn-hangzhou.aliyuncs.com/akaiot/oracle_11g:latest
    #image: oracle_11g:1.1
    container_name: oracle11g
    restart: always
    ports:
      - '1521:1521'
    environment:
      - TZ=Aisa/Shanghai
    volumes:
      - ./oracle_data/oradata/:/home/oracle/app/oracle/oradata
      - ./oracle_data/admin/:/home/oracle/app/oracle/admin
      - ./oracle_data/flash_recovery_area/:/home/oracle/app/oracle/flash_recovery_area
      - ./oracle_data/cfgtoollogs/:/home/oracle/app/oracle/cfgtoollogs
      - ./oracle_data/checkpoints/:/home/oracle/app/oracle/checkpoints
      - ./oracle_data/diag/:/home/oracle/app/oracle/diag
      - ./oracle_data/oradiag_oracle/:/home/oracle/app/oracle/oradiag_oracle
EOF

# 为了将数据文件持久化存储在宿主机,先启动一个临时的镜像，将里面的文件复制出来
docker run -itd --name oracle11g -p 1521:1521 registry.cn-hangzhou.aliyuncs.com/helowin/oracle_11g

# 等待 10 秒，等待程序初始化完成。

# 将容器里面的复制文件复制到宿主机当前目录下，对应于 docker-compose 里面的目录
docker cp  oracle11g:/home/oracle/app/oracle/oradata  ./oracle_data/oradata
docker cp  oracle11g:/home/oracle/app/oracle/admin  ./oracle_data/admin
docker cp  oracle11g:/home/oracle/app/oracle/flash_recovery_area  ./oracle_data/flash_recovery_area
docker cp  oracle11g:/home/oracle/app/oracle/cfgtoollogs  ./oracle_data/cfgtoollogs
docker cp  oracle11g:/home/oracle/app/oracle/checkpoints  ./oracle_data/checkpoints
docker cp  oracle11g:/home/oracle/app/oracle/diag  ./oracle_data/diag
docker cp  oracle11g:/home/oracle/app/oracle/oradiag_oracle  ./oracle_data/oradiag_oracle
# 复制完文件后，需要移除临时的容器
docker rm -f oracle11g

# 由于容器里是500用户的权限，因此需要更改权限，否则容器里程序无法读取数据
chown 500:500 -R /data/oracle11g

# 重新启动即可使用
docker-compose up -d 
```


# oracle默认参数
```bash
hostname: localhost
port: 1521
sid: helowin
username: system
password: helowin
```
# 其他信息
此镜像的用户 root 密码 helowin
用户 oracle , uid 500
如果需要进入容器中使用命令行操作则需要
```bash
docker exec -it oracle11g su root
输入密码默认: helowin
# 第一次执行需要加上环境变量，后续则不需要
cat >> /etc/profile >> EOF
export ORACLE_HOME=/home/oracle/app/oracle/product/11.2.0/dbhome_2
export ORACLE_SID=helowin
export PATH=$ORACLE_HOME/bin:$PATH
EOF

source /etc/profile
ln -s $ORACLE_HOME/bin/sqlplus /usr/bin

# 切换用户
su oracle
sqlplus /nolog
conn /as sysdba
alter user system identified by password;
alter user sys identified by password;
ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;

```



注意：
密码有效期7天，建议登陆上后立即修改密码
