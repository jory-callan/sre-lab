# 倒序查看内存占用
getMemoryUsage()
{
    memory=` ps -auxf | sort -nr -k 4 | head -10`
    echo $memory
}

# 查看cpu占用前十的程序
getCpuUsage()
{
    cpu=`ps -auxf | sort -nr -k 3 | head -10`
    echo $cpu
}
