echo '=========== ssh try login but failed ============'
cat /var/log/secure|awk '/Failed/{print $(NF-3)}'|sort|uniq -c|awk '{print $2"="$1;}'

echo '=========== host.deny  ====================='
cat /etc/hosts.deny

echo '============  iptables -L INPUT ======================='
 iptables -L INPUT -n --line-numbers
