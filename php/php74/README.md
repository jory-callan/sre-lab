### crontab
采用是 dillon’s dcron
重载，等待几十秒钟过后即可自动重载配置文件
echoecho "" > /etc/crontabs/cron.update
或者采用
crontab -e
crontab -u www-data -e
或者采用
touch /etc/crontabs/root


更新，去掉了 dcron  Alpine 自带的 busybox crond 省心省力 不需要重载自动生效
crond -f -l 2  # 前台启动 crond 服务



### supervisor
重启supervisor服务
supervisorctl restart all
service supervisor restart
重启某个服务
supervisorctl restart service_name
更新配置文件
supervisorctl update