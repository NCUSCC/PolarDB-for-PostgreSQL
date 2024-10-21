#!/bin/bash

# default configuration
pg_user=postgres
pg_database=postgres
pg_host=localhost
pg_port=5432
clean=
tpch_dir=tpch-dbgen
data_dir=/data

# Function to print the current timestamp with millisecond precision
print_timestamp() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S.%3N')] $1"
}

# Optimize PostgreSQL settings for bulk loading
optimize_postgres() {
    print_timestamp "Optimizing PostgreSQL configuration for bulk loading..."
    psql -c "ALTER SYSTEM SET maintenance_work_mem = '2GB';"
    psql -c "ALTER SYSTEM SET checkpoint_timeout = '1h';"
    psql -c "ALTER SYSTEM SET max_wal_size = '10GB';"
    psql -c "ALTER SYSTEM SET wal_level = minimal;"
    psql -c "ALTER SYSTEM SET synchronous_commit = off;"
    psql -c "ALTER SYSTEM SET shared_buffers = '4GB';"
    psql -c "ALTER SYSTEM SET work_mem = '256MB';"
    psql -c "SELECT pg_reload_conf();"
    print_timestamp "PostgreSQL configuration optimized."
}

# Script usage information
usage () {
cat <<EOF

  1) Use default configuration to run tpch_copy
  ./tpch_copy.sh
  2) Use limited configuration to run tpch_copy
  ./tpch_copy.sh --user=postgres --db=postgres --host=localhost --port=5432
  3) Clean the test data. This step will drop the database or tables.
  ./tpch_copy.sh --clean

EOF
  exit 0;
}

for arg do
  val=`echo "$arg" | sed -e 's;^--[^=]*=;;'`

  case "$arg" in
    --user=*)                   pg_user="$val";;
    --db=*)                     pg_database="$val";;
    --host=*)                   pg_host="$val";;
    --port=*)                   pg_port="$val";;
    --clean)                    clean=on ;;
    -h|--help)                  usage ;;
    *)                          echo "wrong options : $arg";
                                exit 1
                                ;;
  esac
done

export PGPORT=$pg_port
export PGHOST=$pg_host
export PGDATABASE=$pg_database
export PGUSER=$pg_user

# Clean the tpch test data
if [[ $clean == "on" ]]; then
  print_timestamp "Cleaning up the TPCH test data..."
  make clean
  if [[ $pg_database == "postgres" ]]; then
    echo "Dropping all TPCH tables..."
    psql -c "drop table if exists customer cascade"
    psql -c "drop table if exists lineitem cascade"
    psql -c "drop table if exists nation cascade"
    psql -c "drop table if exists orders cascade"
    psql -c "drop table if exists part cascade"
    psql -c "drop table if exists partsupp cascade"
    psql -c "drop table if exists region cascade"
    psql -c "drop table if exists supplier cascade"
  else
    echo "Dropping the TPCH database: $PGDATABASE"
    psql -c "drop database if exists $PGDATABASE" -d postgres
  fi
  print_timestamp "TPCH test data cleanup completed."
  exit;
fi

# Optimize PostgreSQL configuration before loading data
print_timestamp "Starting PostgreSQL optimization..."
optimize_postgres

###################### PHASE 1: create table ######################
if [[ $PGDATABASE != "postgres" ]]; then
  print_timestamp "Creating the TPCH database: $PGDATABASE..."
  psql -c "create database $PGDATABASE" -d postgres
  print_timestamp "Database $PGDATABASE created."
fi

print_timestamp "Creating TPCH tables..."
psql -f $tpch_dir/dss.ddl
print_timestamp "TPCH tables created."

###################### PHASE 2: load data ######################
print_timestamp "Starting data loading process..."

psql -c "\COPY nation FROM '$data_dir/nation.tbl' WITH (FORMAT csv, DELIMITER '|');" &
psql -c "\COPY region FROM '$data_dir/region.tbl' WITH (FORMAT csv, DELIMITER '|');" &
psql -c "\COPY part FROM '$data_dir/part.tbl' WITH (FORMAT csv, DELIMITER '|');" &
psql -c "\COPY supplier FROM '$data_dir/supplier.tbl' WITH (FORMAT csv, DELIMITER '|');" &
psql -c "\COPY partsupp FROM '$data_dir/partsupp.tbl' WITH (FORMAT csv, DELIMITER '|');" &
psql -c "\COPY customer FROM '$data_dir/customer.tbl' WITH (FORMAT csv, DELIMITER '|');" &
psql -c "\COPY orders FROM '$data_dir/orders.tbl' WITH (FORMAT csv, DELIMITER '|');" &
psql -c "\COPY lineitem FROM '$data_dir/lineitem.tbl' WITH (FORMAT csv, DELIMITER '|');" &

# Wait for all background processes to finish
wait
print_timestamp "Data loading completed."

###################### PHASE 3: add primary and foreign key ######################
print_timestamp "Adding primary and foreign keys..."
psql -f $tpch_dir/dss.ri
print_timestamp "Primary and foreign keys added."