#!/bin/sh
# 服务器初始化脚本(所有主机执行)

# 设置当前主机ip地址环境（带d的为开发用，带p的为预发布用，带t的为测试用，带a的为生产用）
IP_ENV=t


# 检查是否为root用户，脚本必须在root权限下运行 #
Opt_check_root(){
	echo -e "\033[33m >> 检查是否为root用户！ \033[0m"
	if [[ "$(whoami)" != "root" ]]; then
		echo -e "\033[31m >> 该脚本只能root权限执行 !\033[0m"
		exit 1
	fi
	echo -e "\033[32m >> 当前为root权限 ,符合脚本要求!\033[0m"
}

Opt_yum_update(){
	echo -e "\033[33m >> 安装并更新源！ \033[0m"
	# 备份默认YUM配置
	if [ ! -e "/etc/yum.repos.d/bak" ]; then
		mkdir /etc/yum.repos.d/bak
		mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/bak/CentOS-Base.repo.backup
	fi
	echo -e "\033[33m >> 安装aliyun源 !\033[0m"
	# 下载安装aliyun配置
	#下面Centos-7 也可以使用这个 Centos-${ver_nunber}
	curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
	# 下载安装aliyun EPEL源
	curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
	#更新系统
	echo -e "\033[33m >> 更新系统 !\033[0m"
	yum clean all && yum makecache
	echo -e "\033[32m  >> YUM 安装成功！未执行 yum update -y \033[0m"
	sleep 1
}

#disable selinux #关闭SELINUX
Opt_disable_selinux(){
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
echo -e "\033[31m selinux ok \033[0m"
sleep 1
}

#关闭 swap 分区
Opt_disable_swap(){
sync
sleep 1
swapoff -a 
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo -e "\033[31m swap ok \033[0m"
sleep 1
}

# 关闭防火墙
Opt_disable_firewall(){
systemctl stop firewalld && sudo systemctl disable firewalld	
}

#-----------优化 linux 参数---------------

histsize(){
#修改为记录50000条
sed -i 's/^HISTSIZE=.*$/HISTSIZE=50000/' /etc/profile
echo "local0.*                                                /var/command.log" >> /etc/rsyslog.conf
#记录命令到日志
echo "export PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; });logger '[euid=\$(whoami)]':\$(who am i):[`pwd`]\"\$msg\"; }'" >> /etc/profile
echo "export PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; });logger -p local0.notice -t bash -i HOST=[\$HOSTNAME],USER=\$USER,PPID=\$PPID,FROM=[\$SSH_CONNECTION],PWD=\$PWD,WHO=[\$(who am i)]: \"\$msg\"; }'" >> /etc/profile
}

# 配置时间同步
timesync_config(){
sed -i 's/^server.*iburst$//' /etc/chrony.conf
cat >> /etc/chrony.conf <<EOF
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst
server ntp3.aliyun.com iburst
server ntp4.aliyun.com iburst
server ntp5.aliyun.com iburst
server ntp6.aliyun.com iburst
server ntp7.aliyun.com iburst
EOF
sudo systemctl start chronyd
sudo systemctl enable chronyd
sudo chronyc sources -v
sudo chronyc makestep
}

# ——————————————————————————————————————————————————————————————————————
# 启动安装
main(){
echo "[1]##[检查是否为root用户，脚本必须在root权限下运行]###############################################"
	Opt_check_root			# 检查是否为root用户，脚本必须在root权限下运行 
	
	
echo "[2]##[更新yum源]###############################################"
	# Opt_yum_update			# 更新yum源 


echo "[4]##[关闭SELINUX]###############################################"
	Opt_disable_selinux			# 关闭SELINUX 


echo "[5]##[关闭swap分区]###############################################"
	Opt_disable_swap			# 关闭swap分区 


echo "[6]##[关闭防火墙]###############################################"
	Opt_disable_firewall			# 关闭防火墙 


echo "[7]##[关闭SELINUX]###############################################"
	Opt_disable_selinux			# 关闭SELINUX


echo "==================[优化]==============================================="

echo "[12]##[修改记录命令的历史大小]###############################################"
	histsize			# 修改为记录50000条，并记录命令到日志 /etc/profile


echo "[18]##[配置时间同步]###############################################"
	timesync_config			# 配置时间同步

echo "==================[完成]==============================================="
echo "[4]##[end-完成]###############################################"
	done_ok			# 最后显示
}


# 最后安装确认，按Y继续默认N，其他按键全部退出 #
Opt_confirm(){
	yn="n"
	echo "please input [Y\N]"
	echo -n "default [N]: "
	read yn
	if [ "$yn" != "y" -a "$yn" != "Y" ]; then
		echo "bye-bye!"
		exit 0
	fi
	Opt_begin		# 倒计时 #
}

# done
done_ok(){
cat << EOF
+-------------------------------------------------+
|               optimizer is done                 |
|   it's recommond to restart this server !       |
|            E-mail:1219946450@QQ.COM              |
|                                                 |
|             Please Reboot system                |
+-------------------------------------------------+
EOF
}

# 写入本次安装的日志 
main 2>&1 | tee -a /tmp/init-centos7-log-`date '+%Y%m%d-%H%M%S'`.log

