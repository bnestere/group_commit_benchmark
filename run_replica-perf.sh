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
#   BVAR_LOG_BIN: log_bin mariadbd option value
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

if [[ -z "${BVAR_LOG_BIN}" ]];
then
  echo "Environment variable BVAR_LOG_BIN must be set"
  exit 1
fi

if [[ -z "${BVAR_RUN_ID}" ]];
then
  echo "Environment variable BVAR_RUN_ID must be set"
  exit 1
fi

if [[ -z "${BVAR_INNODB_BINLOG}" ]];
then
  echo "Environment variable BVAR_INNODB_BINLOG must be set"
  exit 1
fi

if [[ -z "${BVAR_SLAVE_PARALLEL_THREADS}" ]]; 
then
  echo "Environment variable BVAR_SLAVE_PARALLEL_THREADS must be set"
  exit 1
fi


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

CFG_FILE=$SCRIPT_DIR/benchmark.cnf
AGGREGATE_RESULT_FILE=$SCRIPT_DIR/repl_benchmark.csv
DATABASE="bench"
RUN_DIR=/dev/shm/bnestere/run
RESULT_DIR=$RUN_DIR/results
DATA_DIR=$RUN_DIR/var/mariadbd.1/data
DATA_DIR_REPL=$RUN_DIR/var/mariadbd.2/data
SOCKET=$RUN_DIR/mysql.sock
SOCKET_REPL=$RUN_DIR/mysql_repl.sock
DATA_DIR_REPL=$RUN_DIR/var/mariadbd.2/data

cp $SCRIPT_DIR/template.cnf $CFG_FILE
echo "log-bin=$BVAR_LOG_BIN" >> $CFG_FILE
if [ $BVAR_LOG_BIN -eq 1 ];
then
  echo "log-bin=$BVAR_LOG_BIN" >> $CFG_FILE
else
  echo "skip-log-bin" >> $CFG_FILE
fi
echo "innodb_flush_log_at_trx_commit=$BVAR_INNODB_FLUSH_LOG" >> $CFG_FILE
echo "sync_binlog=$BVAR_SYNC_BINLOG" >> $CFG_FILE
echo "binlog_commit_wait_count=$BVAR_WAIT_COUNT" >> $CFG_FILE
echo "binlog_commit_wait_usec=$BVAR_WAIT_USEC" >> $CFG_FILE
echo "" >> $CFG_FILE
echo "[mysqld.1]" >> $CFG_FILE
echo "datadir=$DATA_DIR" >> $CFG_FILE
echo "socket=$SOCKET" >> $CFG_FILE
echo "" >> $CFG_FILE
echo "[mysqld.2]" >> $CFG_FILE
echo "slave_parallel_threads=$BVAR_SLAVE_PARALLEL_THREADS" >> $CFG_FILE
echo "socket=$SOCKET_REPL" >> $CFG_FILE
echo "log_slave_updates" >> $CFG_FILE
echo "skip_slave_start" >> $CFG_FILE
echo "server_id=2" >> $CFG_FILE
echo "port=3307" >> $CFG_FILE
echo "datadir=$DATA_DIR_REPL" >> $CFG_FILE
echo "" >> $CFG_FILE
echo "[client]" >> $CFG_FILE
echo "socket=$SOCKET" >> $CFG_FILE
echo "" >> $CFG_FILE
echo "[client.2]" >> $CFG_FILE
echo "socket=$SOCKET_REPL" >> $CFG_FILE
echo "" >> $CFG_FILE

rm -rf $RUN_DIR
mkdir -p $RESULT_DIR
mkdir -p $DATA_DIR
mkdir -p $DATA_DIR_REPL

safe_exit() {
  echo "Force shutting down MariaDB Server.."
  $MARIADB_HOME/bin/mariadb --defaults-file="$CFG_FILE"  -e "SHUTDOWN"
}
trap safe_exit SIGINT


start_server() {
  echo "Starting Server $1.."
  $MARIADB_HOME/bin/mysqld --defaults-group-suffix=.$1 --defaults-file=$CFG_FILE
  echo "Server $1 successfully shutdown"
  exit 0
}

start_server_perf() {
  echo "Starting Server $1.."
  perf record --call-graph dwarf -F 999 -- $MARIADB_HOME/bin/mysqld --defaults-group-suffix=.$1 --defaults-file=$CFG_FILE
  echo "Server $1 successfully shutdown"
  exit 0
}

do_update() {
  table_id=$1
  result_file="$RESULT_DIR/out.t${table_id}.csv"
  echo "Slapping table ${DATABASE}.t$table_id"
  if [ $BVAR_INNODB_BINLOG -eq 1 ];
  then
    $MARIADB_HOME/bin/mysqlslap --defaults-file=$CFG_FILE  --query="start transaction;update ${DATABASE}.t$table_id set b=b+1 where a=1;insert into ${DATABASE}.binlog (domain_id,server_id,event) VALUES(${table_id},1,\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\");COMMIT" --engine="innodb" --csv="$result_file" --delimiter=";" --concurrency=1 --number-of-queries=$((BVAR_N_QUERIES*4)) --create-schema="$DATABASE"
  else
    $MARIADB_HOME/bin/mysqlslap --defaults-file=$CFG_FILE  --query="start transaction;update ${DATABASE}.t$table_id set b=b+1 where a=1;commit" --engine="innodb" --csv="$result_file" --delimiter=";" --concurrency=1 --number-of-queries=$((BVAR_N_QUERIES*3)) --create-schema="$DATABASE"
  fi

  #while IFS="," read -r engine mode avg min max nclients queries_per_client
  #do
  #  echo "$BVAR_MARIADB_VERSION,$BVAR_RUN_ID,$connection_count,$1,$BVAR_INNODB_FLUSH_LOG,$BVAR_SYNC_BINLOG,$BVAR_LOG_BIN,$BVAR_INNODB_BINLOG,$BVAR_WAIT_COUNT,$BVAR_WAIT_USEC,$BVAR_N_QUERIES,$engine,update,$avg,$min,$max,$nclients,$queries_per_client" >> $AGGREGATE_RESULT_FILE
  #done < $result_file

}


echo "Initializing mariadbd.."
$MARIADB_HOME/scripts/mysql_install_db --defaults-group-suffix=.1 --basedir=$MARIADB_HOME --datadir=$DATA_DIR --defaults-file=$CFG_FILE
$MARIADB_HOME/scripts/mysql_install_db --defaults-group-suffix=.2 --basedir=$MARIADB_HOME --datadir=$DATA_DIR_REPL --defaults-file=$CFG_FILE

start_server 1 &
SERVER_PID=$!
#start_server_perf 2 &
start_server 2 &
REPL_PID=$!
sleep 1
echo "..Started"

echo "Initializing replication.."

echo "..Creating repl user on primary.."
$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.1 --defaults-file="$CFG_FILE"  -e "RESET MASTER;"
$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.1 --defaults-file="$CFG_FILE"  -e "SET STATEMENT SQL_LOG_BIN=0 FOR CREATE USER 'replication_user'@'localhost' IDENTIFIED BY 'bigs3cret';"
$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.1 --defaults-file="$CFG_FILE"  -e "SET STATEMENT SQL_LOG_BIN=0 FOR GRANT REPLICATION SLAVE ON *.* TO 'replication_user'@'localhost';"

echo "..Connecting replica to primary.."
$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.2 --defaults-file="$CFG_FILE"  -e "RESET MASTER;"
$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.2 --defaults-file="$CFG_FILE"  -e "CHANGE MASTER TO MASTER_HOST='localhost', MASTER_USER='replication_user', MASTER_PASSWORD='bigs3cret', MASTER_PORT=3306, MASTER_USE_GTID=slave_pos;"
$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.2 --defaults-file="$CFG_FILE"  -e "start slave;"
sleep 1
echo "..Done"


echo "Stopping replica.."
$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.2 --defaults-file="$CFG_FILE"  -e "SHUTDOWN"
wait $REPL_PID
echo "..Done"

echo "Creating tables.."
$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.1 --defaults-file="$CFG_FILE"  -e "CREATE DATABASE IF NOT EXISTS $DATABASE"

if [ $BVAR_INNODB_BINLOG -eq 1 ];
then
  $MARIADB_HOME/bin/mariadb --defaults-group-suffix=.1 --defaults-file="$CFG_FILE"  -e "CREATE TABLE ${DATABASE}.binlog (domain_id int unsigned, server_id int unsigned, seq_no int unsigned auto_increment primary key, event longblob) engine=innodb;"
fi

for (( c=1; c<=$1; c++ ))
do 
  $MARIADB_HOME/bin/mariadb --defaults-group-suffix=.1 --defaults-file="$CFG_FILE"  -e "CREATE TABLE ${DATABASE}.t$c (a int primary key, b int) engine=innodb;insert into ${DATABASE}.t$c (a, b) values (1, 1);"
done

for (( c=1; c<=$1; c++ ))
do 
  do_update $c &
done


err=0

for job in `jobs -p`
do
  if [ $job -ne $SERVER_PID ] && [ $job -ne $REPL_PID ];
  then
    wait $job || let "err+=1"
  fi
done

echo "Primary queries finished, starting replica.."

start_server_perf 2 &
REPL_PID=$!
sleep 1
repl_start=`date +%s.%N`
$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.2 --defaults-file="$CFG_FILE"  -e "start slave;"


primary_gtid=`$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.1 --defaults-file="$CFG_FILE" -B -N -e "SELECT @@GLOBAL.gtid_binlog_pos"`
echo "..Waiting for slave to reach pos $primary_gtid.."
$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.2 --defaults-file="$CFG_FILE" -B -N -e "SELECT master_gtid_wait('$primary_gtid','30')"
repl_end=`date +%s.%N`
echo "..Done"

repl_runtime=$( echo "$repl_end - $repl_start" | bc -l )
echo "Replication took $repl_runtime seconds"

if [ ! -f "$AGGREGATE_RESULT_FILE" ]; then
  echo "version,run_id,slave_parallel_threads,end_state,runtime" > $AGGREGATE_RESULT_FILE
fi
echo "$BVAR_MARIADB_VERSION,$BVAR_RUN_ID,$BVAR_SLAVE_PARALLEL_THREADS,$primary_gtid,$repl_runtime" >> $AGGREGATE_RESULT_FILE

sleep 3

echo "Updates complete, shutting down replica.."
$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.2 --defaults-file="$CFG_FILE"  -e "SHUTDOWN"
wait $REPL_PID

echo "..Shutting down primary.."
$MARIADB_HOME/bin/mariadb --defaults-group-suffix=.1 --defaults-file="$CFG_FILE"  -e "SHUTDOWN"
wait $SERVER_PID

echo "..Done"

if [ "$err" -ne "0" ];
then
  echo "$err Mariadb connections failed"
fi

echo ""
