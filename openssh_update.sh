#!/bin/bash

# 显示进度的函数
function show_progress() {
    echo -e "\n[\033[1;32m+\033[0m] $1"
}

# 显示错误的函数
function show_error() {
    echo -e "\n[\033[1;31m!\033[0m] 错误: $1"
    exit 1
}

# 更新系统并安装必要的软件包
show_progress "更新系统并安装必要的软件包..."
yum update -y || show_error "无法更新系统。"
yum install -y vim gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel zlib-devel tcp_wrappers-devel tcp_wrappers libedit-devel perl-IPC-Cmd wget tar lrzsz nano || show_error "无法安装所需的软件包。"

# 下载并解压源文件
show_progress "下载并解压源文件..."
cd /usr/local/src || show_error "无法切换到 /usr/local/src 目录。"
wget https://www.zlib.net/zlib-1.3.1.tar.gz || show_error "无法下载 zlib 源码。"
wget https://www.openssl.org/source/openssl-3.2.1.tar.gz || show_error "无法下载 OpenSSL 源码。"
wget https://mirrors.aliyun.com/openssh/portable/openssh-9.7p1.tar.gz || show_error "无法下载 OpenSSH 源码。"
tar -zxvf zlib-1.3.1.tar.gz || show_error "无法解压 zlib 源码。"
tar -zxvf openssl-3.2.1.tar.gz || show_error "无法解压 OpenSSL 源码。"
tar -zxvf openssh-9.7p1.tar.gz || show_error "无法解压 OpenSSH 源码。"

# 编译并安装 zlib
show_progress "编译并安装 zlib..."
cd /usr/local/src/zlib-1.3.1 || show_error "无法切换到 zlib 源码目录。"
./configure --prefix=/usr/local/src/zlib || show_error "无法配置 zlib。"
make -j 14 && make test && make install || show_error "无法编译并安装 zlib。"

# 编译并安装 OpenSSL
show_progress "编译并安装 OpenSSL..."
cd /usr/local/src/openssl-3.2.1 || show_error "无法切换到 OpenSSL 源码目录。"
./config --prefix=/usr/local/src/openssl || show_error "无法配置 OpenSSL。"
make -j 14 && make install || show_error "无法编译并安装 OpenSSL。"

# 更新系统 OpenSSL 路径
show_progress "更新 OpenSSL 路径..."
mv /usr/bin/openssl /usr/bin/oldopenssl || show_error "无法移动旧的 openssl 二进制文件。"
ln -s /usr/local/src/openssl/bin/openssl /usr/bin/openssl || show_error "无法创建 openssl 的符号链接。"
ln -s /usr/local/src/openssl/lib64/libssl.so.3 /usr/lib64/libssl.so.3 || show_error "无法创建 libssl.so 的符号链接。"
ln -s /usr/local/src/openssl/lib64/libcrypto.so.3 /usr/lib64/libcrypto.so.3 || show_error "无法创建 libcrypto.so 的符号链接。"
echo "/usr/local/src/openssl/lib64" >> /etc/ld.so.conf || show_error "无法更新 ld.so.conf。"
ldconfig || show_error "无法运行 ldconfig。"

# 验证 OpenSSL 版本
show_progress "验证 OpenSSL 版本..."
openssl version -v || show_error "无法验证 OpenSSL 版本。"

# 删除旧版 OpenSSH 并安装新版本
show_progress "删除旧版 OpenSSH 并安装新版本..."
yum remove -y openssh || show_error "无法删除旧版 OpenSSH。"
rm -rf /etc/ssh/* || show_error "无法删除 SSH 配置文件。"
cd /usr/local/src/openssh-9.7p1 || show_error "无法切换到 OpenSSH 源码目录。"
./configure --prefix=/usr/local/src/ssh --sysconfdir=/etc/ssh --with-pam --with-ssl-dir=/usr/local/src/openssl --with-zlib=/usr/local/src/zlib || show_error "无法配置 OpenSSH。"
make -j 14 && make install || show_error "无法编译并安装 OpenSSH。"

# 更新 SSH 配置
show_progress "更新 SSH 配置..."
cp -rf /usr/local/src/openssh-9.7p1/contrib/redhat/sshd.init /etc/init.d/sshd || show_error "无法复制 sshd.init。"
cp -rf /usr/local/src/openssh-9.7p1/contrib/redhat/sshd.pam /etc/pam.d/sshd || show_error "无法复制 sshd.pam。"
cp -rf /usr/local/src/ssh/sbin/sshd /usr/sbin/sshd || show_error "无法复制 sshd 二进制文件。"
cp -rf /usr/local/src/ssh/bin/ssh /usr/bin/ssh || show_error "无法复制 ssh 二进制文件。"
cp -rf /usr/local/src/ssh/bin/ssh-keygen /usr/bin/ssh-keygen || show_error "无法复制 ssh-keygen 二进制文件。"
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config || show_error "无法更新 sshd_config。"

# 重启 SSH 守护进程
show_progress "重启 SSH 守护进程..."
/etc/init.d/sshd restart || show_error "无法重启 SSH 守护进程。"

# 验证 SSH 守护进程状态
show_progress "验证 SSH 守护进程状态..."
/etc/init.d/sshd status || show_error "无法验证 SSH 守护进程状态。"

# 将 SSH 守护进程添加到系统启动项
show_progress "将 SSH 守护进程添加到系统启动项..."
chkconfig --add sshd || show_error "无法将 SSH 守护进程添加到系统启动项。"

# 验证 SSH 客户端版本
show_progress "验证 SSH 客户端版本..."
ssh -V || show_error "无法验证 SSH 客户端版本。"

echo -e "\n[\033[1;32m+\033[0m] 脚本成功执行完成。"