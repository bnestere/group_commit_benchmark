BENCHMARK_SCRIPT=run.sh

MARIADB_VERSION := $(shell $(MARIADB_HOME)/bin/mariadb --version | grep -Po "\K10.\d+[^,]+")


run_benchmark: export BVAR_INNODB_FLUSH_LOG=$(INNODB_FLUSH_LOG)
run_benchmark: export BVAR_SYNC_BINLOG=$(SYNC_BINLOG)
run_benchmark: export BVAR_WAIT_COUNT=$(WAIT_COUNT)
run_benchmark: export BVAR_WAIT_USEC=$(WAIT_USEC)
run_benchmark: export BVAR_N_QUERIES=$(N_QUERIES)
run_benchmark: export BVAR_RUN_ID=$(RUN_ID)
run_benchmark: export BVAR_MARIADB_VERSION=$(MARIADB_VERSION)
run_benchmark:
	@echo {run_id:$(RUN_ID), innodb_flush:$(INNODB_FLUSH_LOG), sync_binlog:$(SYNC_BINLOG), wait_count:$(WAIT_COUNT), wait_usec:$(WAIT_USEC), n_queries:$(N_QUERIES), version:"$(MARIADB_VERSION)"}
	./$(BENCHMARK_SCRIPT) $(N_CONNECTIONS)

run_n_connections:
	@$(MAKE) N_CONNECTIONS=16
	@$(MAKE) N_CONNECTIONS=32
	@$(MAKE) N_CONNECTIONS=64

run_sync_opts:
	@$(MAKE) INNODB_FLUSH_LOG=1 SYNC_BINLOG=0 run_n_connections
	@$(MAKE) INNODB_FLUSH_LOG=0 SYNC_BINLOG=1 run_n_connections
	@$(MAKE) INNODB_FLUSH_LOG=1 SYNC_BINLOG=1 run_n_connections

run_wait_counts:
	@$(MAKE) WAIT_COUNT=2 run_sync_opts
	@$(MAKE) WAIT_COUNT=4 run_sync_opts
	@$(MAKE) WAIT_COUNT=8 run_sync_opts
	@$(MAKE) WAIT_COUNT=16 run_sync_opts
	@$(MAKE) WAIT_COUNT=32 run_sync_opts

run_wait_usecs:
	@$(MAKE) WAIT_USEC=100 run_wait_counts
	@$(MAKE) WAIT_USEC=1000 run_wait_counts
	@$(MAKE) WAIT_USEC=10000 run_wait_counts
	@$(MAKE) WAIT_USEC=100000 run_wait_counts

run_nqueries:
	@$(MAKE) N_QUERIES=1000 run_wait_usecs

run_benchmark_full: clean
	@$(MAKE) RUN_ID=1 run_nqueries
	@$(MAKE) RUN_ID=2 run_nqueries

graph:
	Rscript graph_results.R

clean:
	rm -f flush_benchmark.csv
	rm -rf run
