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
function install_dependencies() {
    show_progress "安装必要的软件包..."
    if command -v yum &> /dev/null; then
        if grep -qi 'CentOS Linux release 7' /etc/redhat-release; then
            mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup \
            && curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo \
            && yum clean all && yum makecache
            yum update -y || show_error "无法更新系统。"
            yum install -y vim gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel zlib-devel tcp_wrappers-devel libedit-devel perl-IPC-Cmd wget tar lrzsz nano || show_error "无法安装所需的软件包。"
            # yum install -y gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel zlib-devel tcp_wrappers-devel libedit-devel perl-IPC-Cmd wget tar || show_error "无法安装所需的软件包。"
        elif grep -qi 'Rocky Linux release 8' /etc/redhat-release; then
             yum update -y || show_error "无法更新系统。"
             # yum install -y vim gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel zlib-devel perl-IPC-Cmd wget tar lrzsz perl-Pod-Html || show_error "无法安装所需的软件包。"
             yum install -y gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel zlib-devel perl-IPC-Cmd wget tar perl-Pod-Html  || show_error "无法安装所需的软件包。"
        fi
    elif command -v apt-get &> /dev/null; then
        apt-get update -y || show_error "无法更新系统。"
        apt-get install -y vim gcc g++ make autoconf libssl-dev zlib1g-dev libpcre3-dev libpam0g-dev libedit-dev perl wget tar lrzsz nano || show_error "无法安装所需的软件包。"
    else
        show_error "不支持的 Linux 发行版。"
    fi
}
# 版本遍历
zlib_version="1.3.1"
# openssl_version="3.2.1"
# 腾讯最新只有3.2.0
openssl_version="3.2.0"
openssh_version="9.7p1"

zlib_package="zlib-${zlib_version}.tar.gz"
openssl_package="openssl-${openssl_version}.tar.gz"
# zlib、openssl、openssh下载url
ZLIB_URL="https://www.zlib.net/${zlib_package}"
openssl_url="https://www.openssl.org/source/${openssl_package}"
# openssl_url="https://mirrors.cloud.tencent.com/openssl/source/${openssl_package}"
OPENSSH_URL="https://mirrors.aliyun.com/openssh/portable/openssh-${openssh_version}.tar.gz"

SRC_DIR="/usr/local/src"
ZLIB_SRC_DIR="${SRC_DIR}/zlib-${zlib_version}"
OPENSSL_SRC_DIR="${SRC_DIR}/openssl-${openssl_version}"
OPENSSH_SRC_DIR="${SRC_DIR}/openssh-${openssh_version}"

# 下载并解压源文件
function download_and_extract() {
    # show_progress "下载 zlib、openssl、openssh 并解压源文件..."
    cd "${SRC_DIR}" || show_error "无法切换到 ${SRC_DIR} 目录。"
    # wget --show-progress -q "${ZLIB_URL}" || show_error "无法下载 zlib 源码。"
    # wget --show-progress -q "${openssl_url}" || show_error "无法下载 OpenSSL 源码。"
    # wget --show-progress -q "${OPENSSH_URL}" || show_error "无法下载 OpenSSH 源码。"
    show_progress "下载zlib"
    wget  "${ZLIB_URL}" || show_error "无法下载 zlib 源码。"
    show_progress "下载openssl"
    wget  "${openssl_url}" || show_error "无法下载 OpenSSL 源码。"
    show_progress "下载openssh"
    wget  "${OPENSSH_URL}" || show_error "无法下载 OpenSSH 源码。"
    
    tar -zxvf "${zlib_package}" || show_error "无法解压 zlib 源码。"
    tar -zxvf "${openssl_package}" || show_error "无法解压 OpenSSL 源码。"
    tar -zxvf "openssh-${openssh_version}.tar.gz" || show_error "无法解压 OpenSSH 源码。"
}

# 编译并安装 zlib
function install_zlib() {
    show_progress "编译并安装 zlib..."
    cd "${ZLIB_SRC_DIR}" || show_error "无法切换到 zlib 源码目录。"
    ./configure --prefix="${SRC_DIR}/zlib" || show_error "无法配置 zlib。"
    make -j "$(nproc)" && make test && make install || show_error "无法编译并安装 zlib。"
}

# 编译并安装 OpenSSL
function install_openssl() {
    show_progress "编译并安装 OpenSSL..."
    cd "${OPENSSL_SRC_DIR}" || show_error "无法切换到 OpenSSL 源码目录。"
    ./config --prefix="${SRC_DIR}/openssl" || show_error "无法配置 OpenSSL。"
    make -j "$(nproc)" && make install || show_error "无法编译并安装 OpenSSL。"
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

# 安装并配置 OpenSSH
function install_openssh() {
    show_progress "卸载openssh7.4p1..."
    yum remove -y openssh
    rm -rf /etc/ssh/*
    show_progress "安装并配置 OpenSSH..."
    cd "${OPENSSH_SRC_DIR}" || show_error "无法切换到 OpenSSH 源码目录。"
    ./configure --prefix="${SRC_DIR}/ssh" --sysconfdir=/etc/ssh --with-pam --with-ssl-dir="${SRC_DIR}/openssl" --with-zlib="${SRC_DIR}/zlib" || show_error "无法配置 OpenSSH。"
    make -j "$(nproc)" && make install || show_error "无法编译并安装 OpenSSH。"
    cp -rf "${OPENSSH_SRC_DIR}/contrib/redhat/sshd.init" /etc/init.d/sshd || show_error "无法复制 sshd.init。"
    cp -rf "${OPENSSH_SRC_DIR}/contrib/redhat/sshd.pam" /etc/pam.d/sshd || show_error "无法复制 sshd.pam。"
    cp -rf "${SRC_DIR}/ssh/sbin/sshd" /usr/sbin/sshd || show_error "无法复制 sshd 二进制文件。"
    cp -rf "${SRC_DIR}/ssh/bin/ssh" /usr/bin/ssh || show_error "无法复制 ssh 二进制文件。"
    cp -rf "${SRC_DIR}/ssh/bin/ssh-keygen" /usr/bin/ssh-keygen || show_error "无法复制 ssh-keygen 二进制文件。"
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config || show_error "无法更新 sshd_config。"
    /etc/init.d/sshd restart || show_error "无法重启 SSH 守护进程。"
    chkconfig --add sshd || show_error "无法将 SSH 守护进程添加到系统启动项。"
}
# 清理临时文件和源码目录
function cleanup() {
    show_progress "清理临时文件和源码目录..."
    rm -rf "${SRC_DIR}/${zlib_package}" "${SRC_DIR}/${openssl_package}" "${SRC_DIR}/openssh-${openssh_version}.tar.gz"
    rm -rf "${ZLIB_SRC_DIR}" "${OPENSSL_SRC_DIR}" "${OPENSSH_SRC_DIR}"
}

# 主函数：执行所有步骤
function main() {
    install_dependencies
    download_and_extract
    install_zlib
    install_openssl
    update_openssl_path
    install_openssh
    cleanup
    show_progress "脚本成功执行完成。"
}

# 执行主函数
main
