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
    echo "$os_version"
  case "$os_version" in
    "CentOS Linux release 7"*)
      repo_file="/etc/yum.repos.d/CentOS-Base.repo"
      backup_pattern="CentOS-Base.repo"
      ;;
    "Rocky Linux release 8"*)
      repo_file="/etc/yum.repos.d/[Rr]ocky-*.repo"
      backup_pattern="Rocky-*.repo"
      ;;
    "Rocky Linux release 9"*)
      repo_file="/etc/yum.repos.d/[Rr]ocky-*.repo"
      backup_pattern="Rocky-*.repo"
      ;;
    *)
      show_error "---不支持的操作系统版本或未能识别操作系统类型"$os_version
      return 1
      ;;
  esac
  # 创建备份目录（如果不存在）
  mkdir -p "$backup_dir"
  show_progress "备份原始的 YUM 源配置文件..."
  # 使用 find 查找匹配的文件并执行备份
  find /etc/yum.repos.d/ -type f -name "Rocky-*.repo" -exec cp -rf {} "$backup_dir/" \; || show_error "备份源配置文件失败"
  show_progress "开始替换 $os_version YUM 源为国内镜像源"
  if [[ "$os_version" == "CentOS Linux release 7"* ]]; then
    if grep -q "mirrors.aliyun.com" "$repo_file"; then
      show_progress "已配置阿里云 YUM 源"
      return 0
    else
      curl -o "$repo_file" "$repo_url"
      if [ $? -ne 0 ]; then
        show_error "无法下载阿里云 YUM 源配置文件"
        return 1
      fi
    fi
  else
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e "s|^#baseurl=http://dl.rockylinux.org/\$contentdir|baseurl=${repo_url}|g" \
        -i.bak \
        $repo_file
    if [ $? -ne 0 ]; then
      show_error "替换 $os_version YUM 源配置文件失败"
      # 尝试回滚
      show_progress "尝试回滚源配置文件..."
      cp -rf "$backup_dir/$backup_pattern" /etc/yum.repos.d/ || show_error "回滚源配置文件失败"
      return 1
    fi
  fi
  show_progress "$os_version YUM 国内镜像，开始更新缓存"
  yum clean all && yum makecache
  if [ $? -eq 0 ]; then
    show_progress "替换 $os_version YUM 国内镜像源 完成"
    return 0
  else
    show_error "更新 $os_version YUM 缓存失败"
    # 尝试回滚 (for Rocky Linux)
    if [[ "$os_version" != "CentOS Linux release 7" ]]; then
      show_progress "尝试回滚源配置文件..."
      cp -rf "$backup_dir/$backup_pattern" /etc/yum.repos.d/ || show_error "回滚源配置文件失败"
      yum clean all && yum makecache
      if [ $? -eq 0 ]; then
        show_progress "回滚并恢复原始 YUM 源配置文件 完成"
      else
        show_error "回滚失败，无法恢复源配置文件"
      fi
    fi
    return 1
  fi
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

# 1. 重启服务
echo "[*] 正在重启 Chrony 服务..."
systemctl restart chronyd
systemctl enable chronyd

# 2. 强制立即步进时间 (关键步骤)
# makestep 可以消除巨大的时间偏差，不需要慢慢调整
echo "[*] 正在强制同步时间..."
chronyc -a makestep > /dev/null 2>&1
# 3. 循环等待同步成功 (增加重试机制)
echo "[*] 等待时间同步完成 (最多等待 30 秒)..."
SYNC_SUCCESS=false
for i in {1..30}; do
    # 检查 Leap status 是否为 Normal (已同步)
    if chronyc tracking | grep -q "Normal"; then
        SYNC_SUCCESS=true
        break
    fi
    sleep 1
done
# 4. 根据结果输出
if [ "$SYNC_SUCCESS" = true ]; then
    echo -e "\033[32m[+] Chrony 同步成功!\033[0m"
    chronyc tracking
else
    echo -e "\033[31m[-] Chrony 同步尚未完成 (可能是网络延迟或端口被封)，请稍后手动检查: chronyc tracking\033[0m"
    # 打印一次当前状态用于调试，但不中断脚本
    chronyc tracking
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
  "registry-mirrors": [  "https://docker.1ms.run", "https://docker.hlmirror.com","https://docker.1panel.live","https://hub.dockerx.org"]
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
