@REM 使用 UTF-8 编码
CHCP 65001 

:: 关闭回显，即执行本脚本时不显示执行路径和命令，直接显示结果
@echo off
rem @author luwuer

chcp 65001
echo 切换 utf-8 显示
color f8
set NGINX_DIR=%~dp0


echo 当前目录为  %~dp0  , 检测当前脚本是否放在 nginx.exe 目录中  
echo.    %NGINX_DIR%nginx.exe
if exist "%NGINX_DIR%nginx.exe" (
  cd /d %NGINX_DIR%
  echo nginx.exe 存在 ，脚本可以运行"
) else (
  echo ********** nginx.exe 不存在  
  echo ********** 请将此脚本放在 nginx.exe 同目录中  
  echo ********** 退出脚本 
  pause 
  exit 
)


:INFO
  echo.
  echo. --------------------- 进程列表 ---------------------
  tasklist|findstr /i "nginx.exe"
  if errorlevel 1 echo nginx未启动   
  echo.     
  echo. =========== nginx 脚本 ===========  
  echo. 1. 启动Nginx
  echo. 2. 重启Nginx
  echo. 3. 热加载Nginx
  echo. 4. 关闭Nginx
  echo. 5. 退出
  echo. 
  echo 请输入功能序号：
  set /p id=
    if "%id%"=="1" goto START
    if "%id%"=="2" goto RESTART
    if "%id%"=="3" goto RELOAD
    if "%id%"=="4" goto STOP
    if "%id%"=="5" exit
  pause

:START 
  start nginx.exe -c conf/nginx.conf -p ./
  echo "start nginx.exe -c conf/nginx.conf -p ./ 启动成功"
  goto INFO

:RESTART
  taskkill /F /IM nginx.exe > nul
  start nginx.exe
  echo "taskkill /F /IM nginx.exe > nul  &&  nginx.exe"
  echo 已重启
  goto INFO
  
:RELOAD
  echo 热加载 nginx -s reload
  nginx -s reload

:STOP
  taskkill /F /IM nginx.exe > nul
  echo "taskkill /F /IM nginx.exe > nul"
  echo 已关闭所有nginx进程
  goto INFO


goto :eof