# 判断当前cpu线程数量和内存使用情况
getCpuThreads()
{
    cpuThreads=`cat /proc/cpuinfo | grep "processor" | wc -l`
    echo $cpuThreads
}

#判断当前cpu使用率
getCpuUsage()
{
    cpuUsage=`top -b -n 1 | grep "Cpu(s)" | awk '{print $2}' | cut -d '%' -f 1`
    echo $cpuUsage
}

#判断当前内存使用率
getMemoryOver()
{
    memoryOver=`free -m | grep Mem | awk '{print $3/$2 * 100.0}'`
    echo $memoryOver
}

#判断当前存储使用率
getStorageOver()
{
    storageOver=`df -h | grep /dev/sda1 | awk '{print $5}' | cut -d '%' -f 1`
    echo $storageOver
}

#uuid生成
getUuid()
{
    uuid=`uuidgen`
    echo $uuid
}

#在当前文件夹下创建目录fakeFile，并在新建的目录里生成5G的空文件，使用uuid生成文件名，文件前缀为fakeFile
createFakeFile()
{
    mkdir fakeFile
    dd if=/dev/zero of=fakeFile/$(getUuid) bs=1M count=1024
}

#判断当前操作系统是否安装了java环境
checkJava()
{
    java -version
    if [ $? -eq 0 ];then
        echo "java is installed"
    else
        echo "java is not installed"
    fi
}


main(){
  #判断当前操作系统是否安装了java环境，如果没有安装则提示，并退出脚本
  if [ ! -n "$(which java)" ]; then
    echo "请先安装java环境"
    exit 
  fi

  #如果当前cou使用没有超过50%，则运行程序 java -jar xxx.jar
  if [ `getCpuUsage` -lt 50 ] && [ `getMemoryOver` -eq 1 ];then
    java -jar /home/java/test.jar
  else
    echo "cpu使用率超过80%或内存使用率超过50%，不运行程序"
  fi

  #如果内存使用率没有超过50%，则运行程序 java -jar xxx.jar 
  if [ `getMemoryOver` -lt 50 ];then
    java -jar /home/java/test.jar
  else
    echo "内存使用率超过50%，不运行程序"
  fi

  #循环判断如果存储使用率没有超过50%，则 生成空文件 直到 存储达到50%
  while [ `getStorageOver` -lt 50 ];do
    createFakeFile
  done
}