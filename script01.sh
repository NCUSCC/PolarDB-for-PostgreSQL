#!/bin/bash

# Set base directories
TPCH_DIR="/mnt/polardb/PolarDB-for-PostgreSQL/tpch-dbgen"
DATA_DIR="/data"
BUILD_DIR="/mnt/polardb/PolarDB-for-PostgreSQL"
COPY_SCRIPT="$BUILD_DIR/tpch_copy.sh"
PG_CTL_PATH="$BUILD_DIR/tmp_master_dir_polardb_pg_1100_bld"

# Generate test data
generate_data() {
    echo "Generating test data..."
    cd $TPCH_DIR
    make -f makefile.suite
    ./dbgen -f -s 0.1
}

# Prepare data directory
prepare_data_dir() {
    if [ ! -d "$DATA_DIR" ]; then
        echo "Creating /data directory..."
        sudo mkdir /data
    else
        echo "/data directory already exists."
    fi
    
    echo "Setting permissions on /data..."
    sudo chown -R postgres:postgres /data
    
    echo "Moving test data to /data..."
    sudo mv *.tbl $DATA_DIR
}

# Build the database
build_database() {
    echo "Building PolarDB..."
    cd $BUILD_DIR
    ./polardb_build.sh --without-fbl --debug=off
}

# Run tpch_copy.sh and measure the time
run_tpch_copy() {
    echo "Running tpch_copy.sh..."
    time $COPY_SCRIPT
}

# Stop PostgreSQL process
stop_pg() {
    echo "Stopping PostgreSQL..."
    pg_ctl stop -m fast -D $PG_CTL_PATH
}

# Clean up build artifacts
cleanup_build() {
    echo "Cleaning build files..."
    
    cd $TPCH_DIR
    make clean -f makefile.suite
    
    cd $BUILD_DIR
    make clean
    make distclean
}

# Clean up data directory
cleanup_data() {
    echo "Cleaning up data files..."
    sudo rm -rf $DATA_DIR/*.tbl
}

# Main process
main() {
    # Generate test data
    generate_data
    
    # Prepare data directory
    prepare_data_dir
    
    # Build the database
    build_database
    
    # Run tpch_copy.sh and measure time
    run_tpch_copy
    
    # Stop PostgreSQL and clean up the build
    stop_pg
    cleanup_build
    
    # Clean up data files
    cleanup_data
}

# Execute main process
main
