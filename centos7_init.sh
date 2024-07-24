#!/bin/bash
# 错误处理
set -e
# 函数：显示进度信息
function show_progress() {
    echo -e "\n[\033[1;32m+\033[0m] $1"
}

# 函数：显示错误信息并退出
function show_error() {
    echo -e "\n[\033[1;31m!\033[0m] 错误: $1"
    exit 1
}
# 备份并替换 CentOS YUM 源为阿里云镜像源
if grep -q "mirrors.aliyun.com" /etc/yum.repos.d/CentOS-Base.repo; then
    show_progress "已配置阿里云 YUM 源"
else
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup 
    curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo 
    yum clean all && yum makecache
    if [ $? -eq 0 ]; then
        show_progress "替换 CentOS YUM 源为阿里云镜像源"
    else
        show_error "无法替换 YUM 源为阿里云镜像源"
    fi
fi



sudo yum update -y  || show_error "无法更新yum依赖"

# 安装 Chrony
if ! command -v chronyc &> /dev/null; then
    yum install chrony -y || show_error "安装chrony"
else
    show_progress "Chrony 已经安装"
fi


# 设置时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock -w
echo "时区设置完成"

# 启动和启用 Chrony 服务
systemctl start chronyd.service
systemctl enable chronyd.service
show_progress "启动和启用 Chrony 服务完成"

# 修改 Chrony 配置文件
if grep -q "server ntp.aliyun.com" /etc/chrony.conf; then
    show_progress "已配置ntp.aliyun.com服务器"
else
    sed -i.bak -e '3,6 s/^/#/' -e '6a server ntp.aliyun.com minpoll 4 maxpoll 10 iburst' /etc/chrony.conf
    show_progress "修改 Chrony 配置文件"
fi
# 重启 Chrony 服务并检查时间同步源
systemctl restart chronyd.service || show_error "无法重启 Chrony 服务。"


# 安装 Docker
show_progress "移除旧 Docker..."
yum remove docker docker-common docker-selinux docker-engine -y 
show_progress "安装docker所需依赖.."
yum install -y yum-utils device-mapper-persistent-data lvm2 
show_progress "设置docker阿里镜像源.."
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo 

show_progress "开始安装 Docker..."
sudo yum install docker-ce -y 
systemctl restart docker && systemctl enable docker
show_progress "重启Docker并设置开机启动"

# 配置 Docker 镜像加速器
cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  },
  "registry-mirrors": ["https://cf-workers-docker-io-7cl.pages.dev", "https://registry.cn-hangzhou.aliyuncs.com" ]
}
EOF
show_progress "配置 Docker 镜像加速器完成"

# 停止并禁用防火墙
systemctl stop firewalld && systemctl disable firewalld
show_progress "停止并禁用防火墙完成"

# 重启 Docker 服务
systemctl daemon-reload && systemctl restart docker
show_progress "重启 Docker 服务完成"
