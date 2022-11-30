#!/bin/bash
#
# Runs a single benchmark.
#
# Easiest to invoke using the Makefile, which automates benchmarking different
# test parameters and aggregating their results together.
#
# If invoking manually, ensure to set a number of environment variables
# before calling:
#   MARIADB_HOME: Install directory of MariaDB
#   BVAR_MARIADB_VERSION: The version of MariaDB being tested
#   BVAR_INNODB_FLUSH_LOG: innodb_flush_log_at_trx_commit mariadbd option value
#   BVAR_SYNC_BINLOG: sync_binlog mariadbd option value
#   BVAR_WAIT_COUNT: binlog_commit_wait_count mariadbd option value
#   BVAR_WAIT_USEC: binlog_commit_wait_usec mariadbd option value
#   BVAR_N_QUERIES: Number-of-queries option to mariadb-slap
#   BVAR_RUN_ID: Unique identifier to provide in the CSV output file
#

if [ $# -lt 1 ]
then
  echo "Incorrect args"
  echo "Call with args ./runner.sh <connection_count>"
  exit 1
fi

connection_count=$1

if [[ -z "${MARIADB_HOME}" ]];
then
  echo "Environment variable MARIADB_HOME must be set"
  exit 1
fi

if [[ -z "${BVAR_MARIADB_VERSION}" ]];
then
  echo "Environment variable BVAR_MARIADB_VERSION must be set"
  exit 1
fi

if [[ -z "${BVAR_INNODB_FLUSH_LOG}" ]];
then
  echo "Environment variable BVAR_INNODB_FLUSH_LOG must be set"
  exit 1
fi

if [[ -z "${BVAR_SYNC_BINLOG}" ]];
then
  echo "Environment variable BVAR_SYNC_BINLOG must be set"
  exit 1
fi

if [[ -z "${BVAR_WAIT_COUNT}" ]];
then
  echo "Environment variable BVAR_WAIT_COUNT must be set"
  exit 1
fi

if [[ -z "${BVAR_WAIT_USEC}" ]];
then
  echo "Environment variable BVAR_WAIT_USEC must be set"
  exit 1
fi

if [[ -z "${BVAR_N_QUERIES}" ]];
then
  echo "Environment variable BVAR_N_QUERIES must be set"
  exit 1
fi

if [[ -z "${BVAR_RUN_ID}" ]];
then
  echo "Environment variable BVAR_RUN_ID must be set"
  exit 1
fi

DATABASE="bench"
RESULT_DIR=results
RUN_DIR=~/run/mariadb
DATA_DIR=$RUN_DIR/data

CFG_FILE=benchmark.cnf

AGGREGATE_RESULT_FILE="flush_benchmark.csv"
if [ ! -f "$AGGREGATE_RESULT_FILE" ]; then
  echo "version,run_id,connection_count,connection_no,innodb_flush_log_at_trx_commit,sync_binlog,binlog_commit_wait_count,binlog_commit_wait_usec,n_queries,engine,benchmark_type,average_time_to_run_queries,min_time_to_run_queries,max_time_to_run_queries,clients_running_queries,queries_per_client" > $AGGREGATE_RESULT_FILE
fi

rm -rf $RESULT_DIR
mkdir -p $RESULT_DIR

start_server() {
  echo "Starting Server.."
  $MARIADB_HOME/bin/mysqld --defaults-file=$CFG_FILE
  echo "Server successfully shutdown"
  exit 0
}

do_update() {
  table_id=$1
  result_file="$RESULT_DIR/out.t${table_id}.csv"
  echo "Slapping table ${DATABASE}.t$table_id"
  $MARIADB_HOME/bin/mysqlslap --defaults-file=$CFG_FILE --query="update ${DATABASE}.t$table_id set b=b+1 where a=1" --engine="innodb" --csv="$result_file" --delimiter=";" --concurrency=1 --number-of-queries=$BVAR_N_QUERIES --create-schema="$DATABASE"

  while IFS="," read -r engine mode avg min max nclients queries_per_client
  do
    echo "$BVAR_MARIADB_VERSION,$BVAR_RUN_ID,$connection_count,$1,$BVAR_INNODB_FLUSH_LOG,$BVAR_SYNC_BINLOG,$BVAR_WAIT_COUNT,$BVAR_WAIT_USEC,$BVAR_N_QUERIES,$engine,update,$avg,$min,$max,$nclients,$queries_per_client" >> $AGGREGATE_RESULT_FILE
  done < $result_file

}

cp template.cnf $CFG_FILE

echo "datadir=$DATA_DIR" >> $CFG_FILE
echo "innodb_flush_log_at_trx_commit=$BVAR_INNODB_FLUSH_LOG" >> $CFG_FILE
echo "sync_binlog=$BVAR_SYNC_BINLOG" >> $CFG_FILE
echo "binlog_commit_wait_count=$BVAR_WAIT_COUNT" >> $CFG_FILE
echo "binlog_commit_wait_usec=$BVAR_WAIT_USEC" >> $CFG_FILE

echo "Initializing mariadbd.."
rm -rf $RUN_DIR
mkdir -p $RUN_DIR
$MARIADB_HOME/scripts/mysql_install_db --basedir=$MARIADB_HOME --datadir=$DATA_DIR --defaults-file=$CFG_FILE

echo "Starting mariadbd.."
start_server &
SERVER_PID=$!
sleep 1
echo "..Started"

echo "Creating tables.."
$MARIADB_HOME/bin/mariadb --socket=/tmp/mysql.sock -e "CREATE DATABASE IF NOT EXISTS $DATABASE"
for (( c=1; c<=$1; c++ ))
do 
  $MARIADB_HOME/bin/mariadb --socket=/tmp/mysql.sock -e "CREATE TABLE ${DATABASE}.t$c (a int, b int) engine=innodb;insert into ${DATABASE}.t$c (a, b) values (1, 1);"
done

for (( c=1; c<=$1; c++ ))
do 
  do_update $c &
done


err=0

for job in `jobs -p`
do
  if [ $job -ne $SERVER_PID ];
  then
    wait $job || let "err+=1"
  fi
done

echo "Updates complete, shutting down server"
$MARIADB_HOME/bin/mariadb --socket=/tmp/mysql.sock -e "SHUTDOWN"

wait $SERVER_PID

if [ "$err" -ne "0" ];
then
  echo "$err Mariadb connections failed"
fi

echo ""
