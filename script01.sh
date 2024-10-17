#!/bin/bash

# 函数：检查当前用户是否为 root，如果是，则切换为 postgres 用户执行脚本
check_user() {
    if [ "$EUID" -eq 0 ]; then
        echo "当前是 root 用户，正在切换到 postgres 用户执行..."
        # 切换为 postgres 用户并执行当前脚本
        sudo -u postgres bash -c "$0"
        exit
    fi
}

# 日志文件名：根据当前日期生成日志文件名
LOG_FILE="/var/log/tpch_script_$(date +'%Y%m%d').log"

# 设置基础目录变量
TPCH_DIR="/mnt/polardb/PolarDB-for-PostgreSQL/tpch-dbgen"  # TPCH 数据生成工具的目录
DATA_DIR="/data"  # 存放测试数据的目录
BUILD_DIR="/mnt/polardb/PolarDB-for-PostgreSQL"  # PolarDB 项目的构建目录
COPY_SCRIPT="$BUILD_DIR/tpch_copy.sh"  # 数据导入脚本路径
PG_CTL_PATH="$BUILD_DIR/tmp_master_dir_polardb_pg_1100_bld"  # PostgreSQL 控制路径

# 函数：生成测试数据
generate_data() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 生成测试数据..." | tee -a "$LOG_FILE"
    cd $TPCH_DIR || exit
    make -f makefile.suite
    ./dbgen -f -s 0.1  # 生成规模为 0.1 的测试数据
}

# 函数：准备数据目录
prepare_data_dir() {
    if [ ! -d "$DATA_DIR" ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - 创建 /data 目录..." | tee -a "$LOG_FILE"
        sudo mkdir /data
    else
        echo "$(date +'%Y-%m-%d %H:%M:%S') - /data 目录已存在." | tee -a "$LOG_FILE"
    fi
    
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 设置 /data 目录权限..." | tee -a "$LOG_FILE"
    sudo chown -R postgres:postgres /data  # 设置目录权限为 postgres 用户
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 移动测试数据到 /data ..." | tee -a "$LOG_FILE"
    sudo mv *.tbl $DATA_DIR  # 移动生成的测试数据到 /data
}

# 函数：构建数据库
build_database() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 构建 PolarDB 数据库..." | tee -a "$LOG_FILE"
    cd $BUILD_DIR || exit
    ./polardb_build.sh --without-fbl --debug=off  # 构建 PolarDB 数据库
}

# 函数：运行 tpch_copy.sh 并记录执行时间
run_tpch_copy() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 运行 tpch_copy.sh 脚本..." | tee -a "$LOG_FILE"
    { time $COPY_SCRIPT; } 2>&1 | tee -a "$LOG_FILE"
}

# 函数：停止 PostgreSQL 进程
stop_pg() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 停止 PostgreSQL 服务..." | tee -a "$LOG_FILE"
    pg_ctl stop -m fast -D $PG_CTL_PATH  # 快速停止 PostgreSQL 进程
}

# 函数：清理构建文件
cleanup_build() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 清理构建文件..." | tee -a "$LOG_FILE"
    
    cd $TPCH_DIR || exit
    make clean -f makefile.suite  # 清理 TPCH 生成的文件
    
    cd $BUILD_DIR || exit
    make clean  # 清理 PolarDB 项目构建文件
    make distclean  # 彻底清理所有构建痕迹
}

# 函数：清理数据目录
cleanup_data() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 清理数据文件..." | tee -a "$LOG_FILE"
    sudo rm -rf $DATA_DIR/*.tbl  # 删除 /data 目录下的所有 .tbl 文件
}

# 主流程函数
main() {
    check_user  # 检查用户权限
    
    # 生成测试数据
    generate_data
    
    # 准备数据目录
    prepare_data_dir
    
    # 构建数据库
    build_database
    
    # 运行 tpch_copy.sh 并记录时间
    run_tpch_copy
    
    # 停止 PostgreSQL 并清理构建文件
    stop_pg
    cleanup_build
    
    # 清理数据文件
    cleanup_data
}

# 执行主流程
main