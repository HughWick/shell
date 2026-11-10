#!/bin/bash
# 错误处理
set -e
# 显示进度信息
function show_progress() {
    echo -e "\n[\033[1;32m+\033[0m] $1"
}

# 显示错误信息并退出
function show_error() {
    echo -e "\n[\033[1;31m!\033[0m] 错误: $1"
    exit 1
}

# 阿里源 centos
aliyun_repo="https://mirrors.aliyun.com/repo/Centos-7.repo"
# ===================Rocky linux=========================
# 阿里源
# rocky_repo="https://mirrors.aliyun.com/rockylinux"
# 中国科技大学
rocky_repo="https://mirrors.ustc.edu.cn/rocky"
# 上海交通大学源
# rocky_repo="https://mirrors.sjtug.sjtu.edu.cn/rocky"

# 备份路径
backup_dir="/etc/yum.repos.d/backup"
# 定义更新 YUM 源的函数
update_yum_repo() {
  local os_version="$1"
  local repo_url="$2"
  local repo_file=""
  local backup_pattern=""
  
  echo "当前系统版本: $os_version"
  
  case "$os_version" in
    "CentOS Linux release 7"*)
      repo_file="/etc/yum.repos.d/CentOS-Base.repo"
      backup_pattern="CentOS-Base.repo"
      ;;
    "Rocky Linux release 8"*)
      # 修改匹配模式，去掉中间的横杠强制匹配
      repo_file="/etc/yum.repos.d/rocky*.repo"
      backup_pattern="rocky*.repo"
      ;;
    "Rocky Linux release 9"*)
      # 修改匹配模式，确保能匹配到 rocky.repo
      repo_file="/etc/yum.repos.d/rocky*.repo"
      backup_pattern="rocky*.repo"
      ;;
    *)
      show_error "---不支持的操作系统版本: $os_version"
      return 1
      ;;
  esac
  # 创建备份目录
  mkdir -p "$backup_dir"
  show_progress "备份原始 YUM 源配置文件..."
  # 修正 find 命令以匹配正确的文件名
  find /etc/yum.repos.d/ -maxdepth 1 -name "$backup_pattern" -exec cp -rf {} "$backup_dir/" \; 
  
  show_progress "开始替换 $os_version YUM 源为国内镜像源"

  if [[ "$os_version" == "CentOS Linux release 7"* ]]; then
     # CentOS 7 处理逻辑不变
     if grep -q "mirrors.aliyun.com" "$repo_file"; then
        show_progress "已配置阿里云 YUM 源"
        return 0
     else
        curl -o "$repo_file" "$repo_url"
     fi
  else
    # === Rocky Linux 8/9 通用修复版 ===
    # 1. 将 mirrorlist 注释掉
    # 2. 将 baseurl 取消注释
    # 3. 将 dl.rockylinux.org/$contentdir 替换为国内源地址    
    # 确保文件存在再执行
    if ls $repo_file 1> /dev/null 2>&1; then
        sed -e 's|^mirrorlist=|#mirrorlist=|g' \
            -e 's|^#baseurl=|baseurl=|g' \
            -e "s|http://dl.rockylinux.org/\$contentdir|${repo_url}|g" \
            -e "s|https://dl.rockylinux.org/\$contentdir|${repo_url}|g" \
            -i.bak \
            $repo_file
    else
        show_error "未找到 YUM 配置文件: $repo_file"
    fi
    if [ $? -ne 0 ]; then
      show_error "替换 $os_version YUM 源配置文件失败"
      return 1
    fi
  fi
  
  show_progress "$os_version YUM 国内镜像替换完成，开始清理并生成缓存..."
  # 强制生成缓存以验证源是否有效
  yum clean all
  yum makecache
}
# 获取操作系统版本
os_release=$(cat /etc/redhat-release 2>/dev/null)
# 判断操作系统类型并执行相应的操作
if [[ "$os_release" =~ 'CentOS Linux release 7' ]]; then
  update_yum_repo "$os_release" "$aliyun_repo"
elif [[ "$os_release" =~ 'Rocky Linux release 8' ]]; then
  update_yum_repo "$os_release" "$rocky_repo"
elif [[ "$os_release" =~ 'Rocky Linux release 9' ]]; then
  update_yum_repo "$os_release" "$rocky_repo"
else
  show_error "不支持的操作系统版本或未能识别操作系统类型"
fi

show_progress "更新yum依赖"
sudo yum update -y  || show_error "无法更新yum依赖"
# 安装并配置 Chrony (国内版)
install_and_configure_chrony() {
  show_progress "正在检查并安装 Chrony"
  if ! command -v chronyc &> /dev/null; then
      yum install chrony -y || show_error "无法安装 chrony"
  else
      echo "Chrony 已经安装"
  fi
  show_progress "配置国内 NTP 服务器 (阿里云/腾讯云)"
  CHRONY_CONF="/etc/chrony.conf"
  if [ -f "$CHRONY_CONF" ]; then
      cp "$CHRONY_CONF" "${CHRONY_CONF}.bak"
      # 移除旧的源，注入国内最快的源
      sed -i '/^pool /d' "$CHRONY_CONF"
      sed -i '/^server /d' "$CHRONY_CONF"
      # 插入阿里云、腾讯云以及国家授时中心源
      sed -i '1i server ntp.aliyun.com iburst\nserver ntp.tencent.com iburst\nserver ntp.ntsc.ac.cn iburst' "$CHRONY_CONF"
      # 修改 makestep 为 -1，允许在任何时间点通过步进修正是巨大的时间偏差（解决2070年等问题）
      if grep -q "makestep" "$CHRONY_CONF"; then
          sed -i 's/^makestep.*/makestep 1.0 -1/' "$CHRONY_CONF"
      else
          echo "makestep 1.0 -1" >> "$CHRONY_CONF"
      fi
  fi
  show_progress "设置时区为 Asia/Shanghai"
  if command -v timedatectl &> /dev/null; then
      timedatectl set-timezone Asia/Shanghai
      timedatectl set-ntp yes
  else
      ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  fi
  hwclock -w || true
  show_progress "重启 Chrony 服务"
  systemctl daemon-reload
  systemctl enable chronyd --now
  systemctl restart chronyd
}
# 时间同步
install_and_configure_chrony

# 安装 Docker
show_progress "移除旧 Docker..."
yum remove docker docker-common docker-selinux docker-engine -y 
show_progress "安装docker所需依赖.."
yum install -y yum-utils device-mapper-persistent-data lvm2 
show_progress "设置docker阿里镜像源.."
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo 

# ================= 1. Linux 生产环境通用基线调优 =================
show_progress "配置系统通用内核参数与高并发句柄上限..."

# 1.1 提高用户登录会话与进程资源限制 (PAM Limits)
cat > /etc/security/limits.d/99-baseline.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 65535
* hard nproc 65535
EOF

# 1.2 提高系统内核级全局文件上限与网络基础排队队列 (Sysctl)
cat > /etc/sysctl.d/99-baseline.conf <<EOF
fs.file-max = 2097152
fs.nr_open = 2097152
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_tw_reuse = 1
EOF
sysctl --system > /dev/null 2>&1

# 1.3 提高 systemd 系统级服务与守护进程默认限制
if ! grep -q "DefaultLimitNOFILE=1048576" /etc/systemd/system.conf; then
    echo "DefaultLimitNOFILE=1048576" >> /etc/systemd/system.conf
    echo "DefaultLimitNPROC=65535" >> /etc/systemd/system.conf
fi
systemctl daemon-reexec

show_progress "系统通用基线优化完成"

# ================= 2. 防火墙配置 =================
show_progress "正在停止并禁用防火墙..."
systemctl stop firewalld && systemctl disable firewalld
if [ $? -eq 0 ]; then
    show_progress "停止并禁用防火墙完成"
else
    show_error "停止并禁用防火墙失败"
    exit 1
fi

show_progress "开始安装 Docker..."
yum install docker-ce -y 
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
  "registry-mirrors": [ "https://hub.rat.dev", "https://docker.sparkcr.cn","https://docker-registry.nmqu.com"]
}
EOF
show_progress "配置 Docker 镜像加速器完成"

# 重启 Docker 服务
systemctl daemon-reload && systemctl restart docker
if [ $? -eq 0 ]; then
    show_progress "重启 Docker 服务完成"
else
    show_error "重启 Docker 服务失败"
    exit 1
fi
