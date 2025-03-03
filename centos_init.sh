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

# 阿里源
aliyun_repo="https://mirrors.aliyun.com/repo/Centos-7.repo"
# 上海交通大学源
# rocky_repo="https://mirrors.sjtug.sjtu.edu.cn/rocky"
# 阿里源
rocky_repo="https://mirrors.aliyun.com/rockylinux"

# Check if the system is CentOS 7 or Rocky Linux 8
if grep -qi 'CentOS Linux release 7' /etc/redhat-release; then
    # CentOS 7: Replace with Aliyun mirror
    if grep -q "mirrors.aliyun.com" /etc/yum.repos.d/CentOS-Base.repo; then
        show_progress "已配置阿里云 YUM 源"
    else
        show_progress "开始替换 CentOS 7 YUM 源为阿里云镜像源"
        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup 
        curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo 
        yum clean all && yum makecache
        if [ $? -eq 0 ]; then
            show_progress "替换 CentOS 7 YUM 源为阿里云镜像源 完成"
        else
            show_error "无法替换 CentOS 7 YUM 源为阿里云镜像源"
        fi
    fi
elif grep -qi 'Rocky Linux release 8' /etc/redhat-release; then
    # Rocky Linux 8: Replace with 上海交通大学 mirror
    show_progress "开始替换 Rocky Linux 8 YUM 源为国内镜像源"
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
	-e "s|^#baseurl=http://dl.rockylinux.org/\$contentdir|baseurl=${rocky_repo}|g" \
        -i.bak \
        /etc/yum.repos.d/[Rr]ocky-*.repo
	show_progress " Rocky Linux 8 YUM 国内镜像，开始更新缓存"
    yum clean all && yum makecache
    if [ $? -eq 0 ]; then
        show_progress "替换 Rocky Linux 8 YUM 国内镜像源 完成"
    else
        show_error "无法替换 Rocky Linux 8 YUM 国内镜像"
    fi
elif grep -qi 'Rocky Linux release 9' /etc/redhat-release; then
    # Rocky Linux 9: Replace with 上海交通大学 mirror
    show_progress "开始替换 Rocky Linux 9 YUM 国内镜像"
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
	-e "s|^#baseurl=http://dl.rockylinux.org/\$contentdir|baseurl=${rocky_repo}|g" \
        -i.bak \
        /etc/yum.repos.d/[Rr]ocky-*.repo
    show_progress "Rocky Linux 9 YUM 国内镜像，开始更新缓存"
    yum clean all && yum makecache
    if [ $? -eq 0 ]; then
        show_progress "替换 Rocky Linux 9 YUM 国内镜像 完成"
    else
        show_error "无法替换 Rocky Linux 9 YUM 国内镜像"
    fi
else
    show_error "不支持的操作系统版本或未能识别操作系统类型"
fi

show_progress "更新yum依赖"
sudo yum update -y  || show_error "无法更新yum依赖"

# 安装 Chrony
if ! command -v chronyc &> /dev/null; then
    yum install chrony -y || show_error "安装chrony"
else
    show_progress "Chrony 已经安装"
fi
# 设置时区
show_progress "设置时区"
if [ -f /usr/share/zoneinfo/Asia/Shanghai ]; then
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    hwclock -w
else
    show_error "无法找到时区文件 /usr/share/zoneinfo/Asia/Shanghai"
    exit 1
fi
# 启动和启用 Chrony 服务
systemctl start chronyd.service
systemctl enable chronyd.service
show_progress "启动和自启动 Chrony 服务完成"


# 修改 Chrony 配置文件
if grep -q "server ntp.aliyun.com" /etc/chrony.conf; then
    show_progress "已配置ntp.aliyun.com服务器"
else
    sed -i.bak -e '3,6 s/^/#/' -e '6a server ntp.aliyun.com minpoll 4 maxpoll 10 iburst' /etc/chrony.conf
    show_progress "修改 Chrony 配置文件"
fi
# 重启 Chrony 服务并检查时间同步源
systemctl restart chronyd.service || show_error "无法重启 Chrony 服务。"

# 验证 Chrony 服务是否正在运行
show_progress "验证 Chrony 服务是否正在运行..."
if systemctl is-active chronyd.service &> /dev/null; then
    show_progress "Chrony 服务正在运行."
else
    show_error "Chrony 服务未运行."
    exit 1
fi

# 验证时区是否设置正确
show_progress "验证时区是否设置正确..."
current_timezone=$(timedatectl status | grep "Time zone" | awk '{print $3}')

if [ "$current_timezone" == "Asia/Shanghai" ]; then
    show_progress "时区验证通过: Asia/Shanghai."
else
    show_error "时区验证失败: 当前时区为 $current_timezone，期望为 Asia/Shanghai."
    exit 1
fi

# 验证 Chrony 同步状态 (可选，可能需要一些时间同步)
show_progress "验证 Chrony 同步状态..."
chronyc_status=$(chronyc tracking)
if echo "$chronyc_status" | grep -q "System clock synchronised"; then
  show_progress "Chrony 同步状态：系统时钟已同步."
else
  show_progress "Chrony 同步状态：系统时钟可能尚未同步，请稍后重试. 详细信息:\n$chronyc_status"
fi

show_progress "Chrony 安装和配置验证完成."

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
  "registry-mirrors": [ "https://hub.littlediary.cn", "https://docker.hlmirror.com","https://hub.dockerx.org","https://cf-workers-docker-io-7cl.pages.dev"]
}
EOF
show_progress "配置 Docker 镜像加速器完成"

# 停止并禁用防火墙
systemctl stop firewalld && systemctl disable firewalld
if [ $? -eq 0 ]; then
    show_progress "停止并禁用防火墙完成"
else
    show_error "停止并禁用防火墙失败"
    exit 1
fi

# 重启 Docker 服务
systemctl daemon-reload && systemctl restart docker
if [ $? -eq 0 ]; then
    show_progress "重启 Docker 服务完成"
else
    show_error "重启 Docker 服务失败"
    exit 1
fi
