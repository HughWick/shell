#!/bin/bash

# 函数：检查命令执行结果
check_command() {
    if [ $? -eq 0 ]; then
        echo -e "\e[32m$1 完成\e[0m"  # 成功状态为绿色
    else
        echo -e "\e[31m$1 失败\e[0m"  # 失败状态为红色
        exit 1
    fi
}

# 错误处理
set -e

# 安装 Chrony
if ! command -v chronyc &> /dev/null; then
    echo "Chrony未安装，开始安装..."
    yum install chrony -y
    check_command "安装 Chrony"
fi

# 设置时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock -w
echo "时区设置完成"

# 启动和启用 Chrony 服务
systemctl start chronyd.service
systemctl enable chronyd.service
echo "启动和启用 Chrony 服务完成"

# 修改 Chrony 配置文件
if grep -q "server ntp.aliyun.com" /etc/chrony.conf; then
    echo "已配置ntp.aliyun.com服务器"
else
    sed -i.bak -e '3,6 s/^/#/' -e '6a server ntp.aliyun.com minpoll 4 maxpoll 10 iburst' /etc/chrony.conf
    check_command "修改 Chrony 配置文件"
fi

# 重启 Chrony 服务并检查时间同步源
systemctl restart chronyd.service
echo "重启 Chrony 服务完成"

# 安装 Docker
echo "安装docker所需依赖.."
sudo yum update -y && \
yum remove docker docker-common docker-selinux docker-engine -y && \
yum install -y yum-utils device-mapper-persistent-data lvm2 && \
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo 

echo "开始安装 Docker..."
sudo yum install docker-ce -y 
check_command "安装 Docker"

systemctl restart docker && systemctl enable docker
check_command "重启Docker并设置开机启动"

# 配置 Docker 镜像加速器
cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  },
  "registry-mirrors": [ "https://registry.cn-hangzhou.aliyuncs.com" , "https://docker.m.daocloud.io"]
}
EOF
echo "配置 Docker 镜像加速器完成"

# 停止并禁用防火墙
systemctl stop firewalld && systemctl disable firewalld
echo "停止并禁用防火墙完成"

# 重启 Docker 服务
systemctl daemon-reload && systemctl restart docker
echo "重启 Docker 服务完成"

echo "脚本执行完毕"
