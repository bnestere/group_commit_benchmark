BENCHMARK_SCRIPT=run.sh
RESULT_DIR=results

MARIADB_VERSION := $(shell $(MARIADB_HOME)/bin/mariadb --version | grep -Po "\K10.\d+[^,]+")
FLAMEGRAPH_DIR=$(RESULT_DIR)/flamegraphs/ncon$(N_CONNECTIONS)/log_bin$(LOG_BIN)/innodb_binlog$(INNODB_BINLOG)/innodb_flush_log$(INNODB_FLUSH_LOG)/sync_binlog$(SYNC_BINLOG)/wc$(WAIT_COUNT)/wus$(WAIT_USEC)/nq$(N_QUERIES)/slave_par_threads$(SLAVE_PARALLEL_THREADS)/rid$(RUN_ID)


run_benchmark: export BVAR_INNODB_FLUSH_LOG=$(INNODB_FLUSH_LOG)
run_benchmark: export BVAR_SYNC_BINLOG=$(SYNC_BINLOG)
run_benchmark: export BVAR_LOG_BIN=$(LOG_BIN)
run_benchmark: export BVAR_INNODB_BINLOG=$(INNODB_BINLOG)
run_benchmark: export BVAR_WAIT_COUNT=$(WAIT_COUNT)
run_benchmark: export BVAR_WAIT_USEC=$(WAIT_USEC)
run_benchmark: export BVAR_N_QUERIES=$(N_QUERIES)
run_benchmark: export BVAR_RUN_ID=$(RUN_ID)
run_benchmark: export BVAR_MARIADB_VERSION=$(MARIADB_VERSION)
run_benchmark: export BVAR_SLAVE_PARALLEL_THREADS=$(SLAVE_PARALLEL_THREADS)
run_benchmark:
	@echo {run_id:$(RUN_ID), log_bin:$(LOG_BIN), innodb_binlog:$(INNODB_BINLOG), innodb_flush:$(INNODB_FLUSH_LOG), sync_binlog:$(SYNC_BINLOG), wait_count:$(WAIT_COUNT), wait_usec:$(WAIT_USEC), n_queries:$(N_QUERIES), version:"$(MARIADB_VERSION) slave_parallel_threads:$(SLAVE_PARALLEL_THREADS)"}
	./$(BENCHMARK_SCRIPT) $(N_CONNECTIONS)

run_perf_record:
	mkdir -p $(FLAMEGRAPH_DIR)
	@$(MAKE) BENCHMARK_SCRIPT=run_replica-perf.sh run_benchmark
	perf script > out.perf
	stackcollapse-perf.pl out.perf > out.folded
	flamegraph.pl out.folded > fg.svg
	mv fg.svg $(FLAMEGRAPH_DIR)
	rm perf.data
	rm out.perf
	rm out.folded

run_n_connections:
	@$(MAKE) N_CONNECTIONS=16 run_benchmark
	@$(MAKE) N_CONNECTIONS=32 run_benchmark
	@$(MAKE) N_CONNECTIONS=64 run_benchmark
	@$(MAKE) N_CONNECTIONS=128 run_benchmark
	@$(MAKE) N_CONNECTIONS=256 run_benchmark
	@$(MAKE) N_CONNECTIONS=512 run_benchmark
	@$(MAKE) N_CONNECTIONS=1024 run_benchmark
	#@$(MAKE) N_CONNECTIONS=16 run_perf_record
	#@$(MAKE) N_CONNECTIONS=32 run_perf_record
	#@$(MAKE) N_CONNECTIONS=64 run_perf_record
	#@$(MAKE) N_CONNECTIONS=128 run_perf_record
	#@$(MAKE) N_CONNECTIONS=256 run_perf_record
	#@$(MAKE) N_CONNECTIONS=512 run_perf_record
	#@$(MAKE) N_CONNECTIONS=1024 run_perf_record

run_sync_opts:
	@$(MAKE) LOG_BIN=0 INNODB_FLUSH_LOG=0 SYNC_BINLOG=0 INNODB_BINLOG=0 run_n_connections
	@$(MAKE) LOG_BIN=0 INNODB_FLUSH_LOG=0 SYNC_BINLOG=0 INNODB_BINLOG=1 run_n_connections
	@$(MAKE) LOG_BIN=1 INNODB_FLUSH_LOG=0 SYNC_BINLOG=1 INNODB_BINLOG=0 run_n_connections
	@$(MAKE) LOG_BIN=1 INNODB_FLUSH_LOG=1 SYNC_BINLOG=0 INNODB_BINLOG=0 run_n_connections
	@$(MAKE) LOG_BIN=1 INNODB_FLUSH_LOG=1 SYNC_BINLOG=1 INNODB_BINLOG=0 run_n_connections

run_wait_counts:
	@$(MAKE) WAIT_COUNT=2 run_sync_opts
	@$(MAKE) WAIT_COUNT=4 run_sync_opts
	@$(MAKE) WAIT_COUNT=8 run_sync_opts
	@$(MAKE) WAIT_COUNT=16 run_sync_opts
	@$(MAKE) WAIT_COUNT=32 run_sync_opts

run_wait_usecs:
	@$(MAKE) WAIT_USEC=0 WAIT_COUNT=0 run_sync_opts
	#@$(MAKE) WAIT_USEC=100 run_wait_counts
	#@$(MAKE) WAIT_USEC=1000 run_wait_counts
	#@$(MAKE) WAIT_USEC=10000 run_wait_counts
	#@$(MAKE) WAIT_USEC=100000 run_wait_counts

run_nqueries:
	@$(MAKE) N_QUERIES=512 run_wait_usecs

run_benchmark_full:
	@$(MAKE) RUN_ID=1 run_nqueries
	@$(MAKE) RUN_ID=2 run_nqueries

run_replica_benchmark:
	@$(MAKE) N_QUERIES=512 WAIT_USEC=1000 WAIT_COUNT=8 LOG_BIN=1 INNODB_FLUSH_LOG=0 SYNC_BINLOG=1 INNODB_BINLOG=0 N_CONNECTIONS=32 SLAVE_PARALLEL_THREADS=0 run_perf_record
	@$(MAKE) N_QUERIES=512 WAIT_USEC=1000 WAIT_COUNT=8 LOG_BIN=1 INNODB_FLUSH_LOG=0 SYNC_BINLOG=1 INNODB_BINLOG=0 N_CONNECTIONS=32 SLAVE_PARALLEL_THREADS=1 run_perf_record

run_replica_benchmark_full:
	@$(MAKE) RUN_ID=1 run_replica_benchmark
	@$(MAKE) RUN_ID=2 run_replica_benchmark
	@$(MAKE) RUN_ID=3 run_replica_benchmark
	@$(MAKE) RUN_ID=4 run_replica_benchmark


graph:
	Rscript graph_results.R

clean:
	rm -f flush_benchmark.csv
	rm -rf run
	rm -rf $(RESULT_DIR)
