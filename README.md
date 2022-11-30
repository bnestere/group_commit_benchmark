Benchmarks for MariaDB Group Commit

Scripts to automate benchmarking and graphing of transaction
commits under various group commit parameterizations. Specifically,
it varies innodb\_flush\_log\_at\_trx\_commit, sync\_binlog,
binlog\_commit\_wait\_count, binlog\_commit\_wait\_used, and the
number of connecting threads.

Before running the benchmarks, make sure to set the environment
variables MARIADB\_HOME to point to the MariaDB install directory.

To run the benchmarks, run

```
make run_benchmark_full
```

To modify the parameters to benchmark, edit the Makefile


To graph the results, you'll need an install of R along with the
following packages installed:
 * tidyverse
 * ggpubr
 * firatheme
 * stringr

and run
```
make graph
```
