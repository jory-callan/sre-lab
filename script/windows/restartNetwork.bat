@REM 使用 UTF-8 编码
CHCP 65001 

@REM 查询计算机上所有的网卡（包括虚拟网卡）
@REM netsh interface show interface
@REM 使用方式 以管理员方式运行

@echo off
echo ...
echo 正在重启 WLAN 网卡
netsh interface set interface "WLAN" disable
echo 网卡已关闭
netsh interface set interface "WLAN" enabled
echo 网卡重启成功
pause 