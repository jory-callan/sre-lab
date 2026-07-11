@REM 初始化
@REM 使用 UTF-8 编码
CHCP 65001 
@REM 蓝底白字
color 1F 

echo "==== 更改编码方式为 UTF-8"
title 运行Redis

@echo off
echo "==== 最小化运行"
%1(start /min cmd.exe /c %0 :& exit )
echo "==== 代码写在这下面,最小化运行至任务栏"

@REM 开始编辑

c:

cd "C:\admin-env\redis\redis7.0.5"

.\redis-server.exe  ..\redis.conf 

@REM 结束编辑
echo "==== 可能程序没起来会异常退出，这里阻塞住，方便查看原因"
pause