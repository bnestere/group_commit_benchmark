library("tidyverse")
library("ggpubr")
library("firatheme")
library("stringr")

dat <- read.csv("flush_benchmark.csv") %>%
  mutate(flush_mode = case_when(
                                log_bin == 0 ~ "skip-log-bin",
                                sync_binlog == 1 & innodb_flush_log_at_trx_commit == 0 ~ "<b=1,i=0>",
                                sync_binlog == 0 & innodb_flush_log_at_trx_commit == 1 ~ "<b=0,i=1>",
                                TRUE ~ "<b=1,i=1>"
                                )) %>%
  mutate(TPS=n_queries/average_time_to_run_queries) %>%
  group_by(version,flush_mode,connection_count,binlog_commit_wait_count,binlog_commit_wait_usec,n_queries) %>%
  summarize(mean_tps=mean(TPS),sd_tps=sd(TPS)) %>%
  ungroup()

dat$flush_mode <- factor(dat$flush_mode, levels=c("skip-log-bin","<b=0,i=1>","<b=1,i=0>","<b=1,i=1>"))


title_txt <- str_glue('Group Commit and Sync Benchmark ({dat$version[[1]]})')
subtitle_txt <- str_glue('Trx Per Conn: {dat$n_queries[[1]]}; 1 Update per Trx')

# Labels
# Connections
conns.labs <- c("16 Conns", "32 Conns", "64 Conns")
names(conns.labs) <- c("16", "32", "64")
# Usecs
usecs.labs <- c("wait_usec=100", "wait_usec=1000", "wait_usec=10000", "wait_usec=100000")
names(usecs.labs) <- c("100","1000","10000","100000")

p <- dat %>% ggplot(aes(x=binlog_commit_wait_count,y=mean_tps,group=flush_mode)) +
  geom_line(aes(color=flush_mode)) +
  geom_point(aes(color=flush_mode)) +
  geom_ribbon(aes(ymin=mean_tps-sd_tps,ymax=mean_tps+sd_tps,fill=flush_mode),alpha=0.2) +
  guides(color=guide_legend(title="Flush Mode")) +
  ylab("Transactions per Second") +
  xlab("binlog_commit_wait_count") +
  facet_grid(connection_count ~ binlog_commit_wait_usec,
             labeller=labeller(binlog_commit_wait_usec=usecs.labs,connection_count=conns.labs)) +
  ggtitle(label=title_txt,subtitle=subtitle_txt) +
  theme_fira() +
  scale_colour_fira() +
  scale_fill_fira(guide="none")

ggexport(p, filename="group_commit_benchmark.png", width=800)

