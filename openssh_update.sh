#!/bin/bash

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

# 安装必要的软件包
# function install_dependencies() {
#     show_progress "安装必要的软件包..."
#     if command -v yum &> /dev/null; then
#         if grep -qi 'CentOS Linux release 7' /etc/redhat-release; then
#             mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup \
#             && curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo \
#             && yum clean all && yum makecache
#             yum update -y || show_error "无法更新系统。"
#             # yum install -y vim gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel zlib-devel tcp_wrappers-devel libedit-devel perl-IPC-Cmd wget tar lrzsz nano || show_error "无法安装所需的软件包。"
#             yum install -y gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel zlib-devel tcp_wrappers-devel libedit-devel perl-IPC-Cmd wget tar || show_error "无法安装所需的软件包。"
#         elif grep -qi 'Rocky Linux release 8' /etc/redhat-release; then
#              yum update -y || show_error "无法更新系统。"
#              # yum install -y vim gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel zlib-devel perl-IPC-Cmd wget tar lrzsz perl-Pod-Html || show_error "无法安装所需的软件包。"
#              yum install -y gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel zlib-devel perl-IPC-Cmd wget tar perl-Pod-Html  || show_error "无法安装所需的软件包。"
#         fi
#     elif command -v apt-get &> /dev/null; then
#         apt-get update -y || show_error "无法更新系统。"
#         apt-get install -y vim gcc g++ make autoconf libssl-dev zlib1g-dev libpcre3-dev libpam0g-dev libedit-dev perl wget tar lrzsz nano || show_error "无法安装所需的软件包。"
#     else
#         show_error "不支持的 Linux 发行版。"
#     fi
# }
# linux 发行版
DISTRO=""
# 版本号
VERSION=""
# 安装包目录
SRC_DIR="/usr/local/src"
# 版本号
zlib_version="1.3.1"
# openssl_version="3.2.1"
# 腾讯最新只有3.2.0
openssl_version="3.2.0"
openssh_version="9.8p1"
# 根据版本号组合后名字
zlib_package="zlib-${zlib_version}.tar.gz"
openssl_package="openssl-${openssl_version}.tar.gz"
openssh_package="openssh-${openssh_version}.tar.gz"

# zlib、openssl、openssh下载url
ZLIB_URL="https://www.zlib.net/${zlib_package}"
# openssl_url="https://www.openssl.org/source/${openssl_package}"
openssl_url="https://mirrors.cloud.tencent.com/openssl/source/${openssl_package}"
OPENSSH_URL="https://mirrors.aliyun.com/openssh/portable/${openssh_package}"


ZLIB_SRC_DIR="${SRC_DIR}/zlib-${zlib_version}"
OPENSSL_SRC_DIR="${SRC_DIR}/openssl-${openssl_version}"
OPENSSH_SRC_DIR="${SRC_DIR}/openssh-${openssh_version}"

# 获取操作系统发行版及版本信息
function get_distro_info() {
    # 检查是否安装了 lsb_release 命令
    if command -v lsb_release &> /dev/null; then
        # 使用 lsb_release 获取发行版名称
        DISTRO=$(lsb_release -i | awk -F':\t' '{print \\$2}')
        # 使用 lsb_release 获取操作系统版本
        VERSION=$(lsb_release -r | awk -F':\t' '{print \\$2}')
    # 如果没有 lsb_release 命令，则检查 /etc/os-release 文件
    elif [ -f /etc/os-release ]; then
        # 从 /etc/os-release 文件中提取发行版ID
        DISTRO=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
        # 从 /etc/os-release 文件中提取版本ID
        VERSION=$(grep ^VERSION_ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
    else
        # 如果没有找到任何相关信息，输出错误信息
        show_error "无法检测到操作系统版本。"
    fi
}
# 安装依赖包
function install_dependencies() {
    show_progress "安装必要的软件包..."
    # 根据发行版和版本执行不同的安装步骤
    if [[ "$DISTRO" =~ ^(centos|rocky)$ ]]; then
        if [[ "$DISTRO" == "centos" && "$VERSION" == "7"* ]]; then
            # CentOS 7 配置阿里云镜像
            mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup \
            && curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo \
            && yum clean all && yum makecache
        elif [[ "$DISTRO" == "rocky" && "$VERSION" =~ ^8\.[0-9]+$ ]]; then
            # Rocky Linux 8.x 系列（例如 8.6, 8.7）
            echo "检测到 Rocky Linux 8.x 系列，执行相关操作..."
            # 这里可以添加 Rocky 8 的特定操作
            yum update -y || show_error "无法更新系统。"
        elif [[ "$DISTRO" == "rocky" && "$VERSION" =~ ^9\.[0-9]+$ ]]; then
            # Rocky Linux 9.x 系列（例如 9.5）
            echo "检测到 Rocky Linux 9.x 系列，执行相关操作..."
            yum update -y || show_error "无法更新系统。"
        fi
        # 安装必要的软件包
        yum install -y gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel zlib-devel perl-IPC-Cmd perl-Pod-Html wget tar || show_error "无法安装所需的软件包。"
    elif [[ "$DISTRO" == "Ubuntu" || "$DISTRO" == "Debian" ]]; then
        # 针对 Ubuntu 和 Debian 系列的系统
        apt-get update -y || show_error "无法更新系统。"
        apt-get install -y gcc g++ make autoconf libssl-dev zlib1g-dev libpcre3-dev libpam0g-dev libedit-dev perl wget tar lrzsz || show_error "无法安装所需的软件包。"
    else
        show_error "不支持的 Linux 发行版：$DISTRO $VERSION。"
    fi
}

# 下载并解压源文件
function download_and_extract() {
    cd "${SRC_DIR}" || show_error "无法切换到 ${SRC_DIR} 目录。"
    # wget --show-progress -q "${ZLIB_URL}" || show_error "无法下载 zlib 源码。"
    # wget --show-progress -q "${openssl_url}" || show_error "无法下载 OpenSSL 源码。"
    # wget --show-progress -q "${OPENSSH_URL}" || show_error "无法下载 OpenSSH 源码。"
    show_progress "下载zlib"
    wget  "${ZLIB_URL}" || show_error "无法下载 zlib 源码。"
    show_progress "下载openssh"
    wget  "${OPENSSH_URL}" || show_error "无法下载 OpenSSH 源码。"
    tar -zxvf "${zlib_package}" || show_error "无法解压 zlib 源码。"
    tar -zxvf "${openssh_package}" || show_error "无法解压 OpenSSH 源码。"

    show_progress "下载openssl"
    wget  "${openssl_url}" || show_error "无法下载 OpenSSL 源码。"
    show_progress "解压openssl"
    tar -zxvf "${openssl_package}" || show_error "无法解压 OpenSSL 源码。"
}

# 编译并安装 zlib
function install_zlib() {
    cd "${ZLIB_SRC_DIR}" || show_error "无法切换到 zlib 源码目录。"
    ./configure --prefix="${SRC_DIR}/zlib" || show_error "无法配置 zlib。"
    show_progress "编译 zlib..."
    make -j "$(nproc)"  || show_error "zlib编译失败"
    show_progress "安装 zlib..."
    make test && make install || show_error "无法安装 zlib。"
}

function check_openssl(){
    show_progress "检查 OpenSSL 版本..."
    # 获取当前 OpenSSL 版本
    local current_version=$(openssl version 2>&1 | awk '{print $2}')
    # 使用正则表达式匹配版本号，提取主版本号、次版本号和修订版本号
    if [[ "$current_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)([a-zA-Z\-]*)$ ]]; then
        local major_version="${BASH_REMATCH[1]}"
        local minor_version="${BASH_REMATCH[2]}"
        local patch_version="${BASH_REMATCH[3]}"
        # 将版本号转换为数值进行比较
        local current_version_num=$((major_version * 10000 + minor_version * 100 + patch_version))
        # 比较版本号是否大于等于 3.0.0
        if (( current_version_num >= 30000 )); then
            show_progress "当前 OpenSSL 版本 (${current_version}) 大于等于 3.0.0，无需更新。"
            return 0  # 退出函数，不执行更新操作
        else
            install_openssl
            update_openssl_path
        fi
    else
        show_error "无法正确解析 OpenSSL 版本 '${current_version}'，将继续尝试更新。"
    fi
}

# 编译并安装 OpenSSL
function install_openssl() {
    cd "${OPENSSL_SRC_DIR}" || show_error "无法切换到 OpenSSL 源码目录。"
    show_progress "配置 OpenSSL"
    ./config --prefix="${SRC_DIR}/openssl" || show_error "无法配置 OpenSSL。"
    show_progress "编译 OpenSSL"
    make -j "$(nproc)" || show_error "无法编译 OpenSSL。"
    show_progress "安装 OpenSSL"
    make install || show_error "无法安装 OpenSSL。"
}

# 更新系统 OpenSSL 路径
function update_openssl_path() {   
    show_progress "更新 OpenSSL 路径..."
    # 备份旧的 openssl 二进制文件
    mv /usr/bin/openssl /usr/bin/oldopenssl || show_error "无法移动旧的 openssl 二进制文件。"
    # 创建 openssl 符号链接，如果已存在则先删除
    [[ -e /usr/lib64/libssl.so.3 ]] && rm /usr/lib64/libssl.so.3
    ln -s "${SRC_DIR}/openssl/lib64/libssl.so.3" /usr/lib64/libssl.so.3 || show_error "无法创建 libssl.so 的符号链接。"
    # 创建 libcrypto 符号链接，如果已存在则先删除
    [[ -e /usr/lib64/libcrypto.so.3 ]] && rm /usr/lib64/libcrypto.so.3
    ln -s "${SRC_DIR}/openssl/lib64/libcrypto.so.3" /usr/lib64/libcrypto.so.3 || show_error "无法创建 libcrypto.so 的符号链接。"
    # 更新 ld.so.conf 文件
    echo "${SRC_DIR}/openssl/lib64" >> /etc/ld.so.conf || show_error "无法更新 ld.so.conf。"
    # 运行 ldconfig 更新动态链接库缓存
    ldconfig || show_error "无法运行 ldconfig。"
}

# # 安装并配置 OpenSSH
# function install_openssh() {
#     show_progress "卸载openssh7.4p1..."
#     yum remove -y openssh
#     rm -rf /etc/ssh/*
#     cd "${OPENSSH_SRC_DIR}" || show_error "无法切换到 OpenSSH 源码目录。"
#     ./configure --prefix="${SRC_DIR}/ssh" --sysconfdir=/etc/ssh --with-pam --with-ssl-dir="${SRC_DIR}/openssl" --with-zlib="${SRC_DIR}/zlib" || show_error "无法配置 OpenSSH。"
#     show_progress "编译 OpenSSH..."
#     make -j "$(nproc)" || show_error "无法编译 OpenSSH。"
#     show_progress "安装 OpenSSH..."
#     make install || show_error "无法安装 OpenSSH。"
#     show_progress "配置 OpenSSH..."
#     cp -rf "${OPENSSH_SRC_DIR}/contrib/redhat/sshd.init" /etc/init.d/sshd || show_error "无法复制 sshd.init。"
#     cp -rf "${OPENSSH_SRC_DIR}/contrib/redhat/sshd.pam" /etc/pam.d/sshd || show_error "无法复制 sshd.pam。"
#     cp -rf "${SRC_DIR}/ssh/sbin/sshd" /usr/sbin/sshd || show_error "无法复制 sshd 二进制文件。"
#     cp -rf "${SRC_DIR}/ssh/bin/ssh" /usr/bin/ssh || show_error "无法复制 ssh 二进制文件。"
#     cp -rf "${SRC_DIR}/ssh/bin/ssh-keygen" /usr/bin/ssh-keygen || show_error "无法复制 ssh-keygen 二进制文件。"
#     echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config || show_error "无法更新 sshd_config。"
#     echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config || show_error "无法更新 sshd_config。"
#     show_progress "重启 OpenSSH..."
#     /etc/init.d/sshd restart || show_error "无法重启 SSH 守护进程。"
#     chkconfig --add sshd || show_error "无法将 SSH 守护进程添加到系统启动项。"
# }
function install_openssh() {
    show_progress "卸载 openssh7.4p1..."
    yum remove -y openssh
    rm -rf /etc/ssh/*
    cd "${OPENSSH_SRC_DIR}" || show_error "无法切换到 OpenSSH 源码目录。"
    # 配置 OpenSSH
    ./configure --prefix="${SRC_DIR}/ssh" --sysconfdir=/etc/ssh --with-pam --with-ssl-dir="${SRC_DIR}/openssl" --with-zlib="${SRC_DIR}/zlib" || show_error "无法配置 OpenSSH。"
    show_progress "编译 OpenSSH..."
    make -j "$(nproc)" || show_error "无法编译 OpenSSH。"    
    show_progress "安装 OpenSSH..."
    make install || show_error "无法安装 OpenSSH。"    
    show_progress "配置 OpenSSH..."
    cp -rf "${OPENSSH_SRC_DIR}/contrib/redhat/sshd.pam" /etc/pam.d/sshd || show_error "无法复制 sshd.pam。"
    cp -rf "${SRC_DIR}/ssh/sbin/sshd" /usr/sbin/sshd || show_error "无法复制 sshd 二进制文件。"
    cp -rf "${SRC_DIR}/ssh/bin/ssh" /usr/bin/ssh || show_error "无法复制 ssh 二进制文件。"
    cp -rf "${SRC_DIR}/ssh/bin/ssh-keygen" /usr/bin/ssh-keygen || show_error "无法复制 ssh-keygen 二进制文件。"
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config || show_error "无法更新 sshd_config。"
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config || show_error "无法更新 sshd_config。"
    # 判断系统是否使用 systemd 或 init.d
    if [[ -f "/lib/systemd/system/sshd.service" || -f "/etc/systemd/system/sshd.service" ]]; then
        show_progress "配置 systemd 服务..."        
        # 在 Rocky Linux 8/9 上使用 systemd 管理 OpenSSH
        cp -rf "${OPENSSH_SRC_DIR}/contrib/redhat/sshd.service" /etc/systemd/system/sshd.service || show_error "无法复制 sshd.service。"
        # 重新加载 systemd 配置
        systemctl daemon-reload || show_error "无法重新加载 systemd 配置。"        
        # 启用并启动 OpenSSH 服务
        systemctl enable sshd || show_error "无法启用 SSH 服务。"
        systemctl start sshd || show_error "无法启动 SSH 服务。"
    else
        # 旧版 CentOS 7 系列，使用 init.d 管理
        show_progress "配置 init.d 服务..."
        # 确保 /etc/init.d/ 目录存在
        if [ ! -d "/etc/init.d" ]; then
            mkdir -p /etc/init.d
        fi
        # 使用 init.d 管理 OpenSSH
        cp -rf "${OPENSSH_SRC_DIR}/contrib/redhat/sshd.init" /etc/init.d/sshd || show_error "无法复制 sshd.init。"
        chmod +x /etc/init.d/sshd || show_error "无法赋予 sshd.init 脚本执行权限。"        
        # 启用并启动 OpenSSH 服务
        chkconfig --add sshd || show_error "无法将 SSH 守护进程添加到系统启动项。"
        service sshd start || show_error "无法启动 SSH 守护进程。"
    fi
    show_progress "重启 OpenSSH..."
    # 使用适合系统的命令重启 SSH 服务
    if systemctl is-active --quiet sshd; then
        systemctl restart sshd || show_error "无法重启 SSH 服务。"
    else
        /etc/init.d/sshd restart || show_error "无法重启 SSH 守护进程。"
    fi
}
# 清理临时文件和源码目录
function cleanup() {
    show_progress "清理临时文件..."
    rm -rf "${SRC_DIR}/${zlib_package}" "${SRC_DIR}/${openssl_package}" "${SRC_DIR}/${openssh_package}"
    show_progress "清理临时源码目录..."
    rm -rf "${ZLIB_SRC_DIR}" "${OPENSSL_SRC_DIR}" "${OPENSSH_SRC_DIR}"
}

# 永久关闭 SELinux 的函数
function close_se_status(){
    get_distro_info
    # 检查操作系统是否为 Rocky Linux 8.x
    if [[ "$DISTRO" == "rocky" && "$VERSION" =~ ^8\.[0-9]+$ ]]; then
        # 检查 SELinux 配置文件是否存在
        if [[ -f /etc/selinux/config ]]; then
            # 使用 sed 命令将 SELINUX 状态改为 disabled
            sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
            # 提示用户修改成功
            show_progress "SELinux 已永久关闭，修改 /etc/selinux/config 文件完成。"
        else
            # 如果配置文件不存在，提示错误
            show_error "SELinux 配置文件 /etc/selinux/config 不存在。"
        fi
    fi
}

# 主函数：执行所有步骤
function main() {
    get_distro_info
    install_dependencies
    download_and_extract
    install_zlib
    check_openssl
    install_openssh
    cleanup
    close_se_status
    show_progress "脚本成功执行完成。"
}

# 执行主函数
main
