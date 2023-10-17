# SQL

## rollback_monitor.sql
This evaluates USED_UBLK, that is number of undo blocks it needs to roll back. If rolling back, USED_UBLK would be decreasing towards 0. For other transactions that aren't rolling back, they will be increasing as they generate rollback. Run in 1 min intervals, to estimate rollback time e.g. previous USED_UBLK - current USED_UBLK to get the roll back rate per minute then divide roll back rate per minute / total USED_UBLK.

## rman_monitor.sql
Monitors the progress of an rman copy and provides estimates for completion time. 

## index_monitor.sql
Monitors the progress of an index creation. Provides work ratio and estimated completion time. 

## datapump_mon.sql
Monitors the progress of a datapump operation. Provides work ratio and estimated completion time. 

## generic_longops_monitor.sql
Query against the gv$session_longops to quickly find out how much of a specific DL statement has been completed. Operations over 6 seconds qualify for this view.

## archive_log_generation_per_day.sql
Provides a breakdown of the archive log generation per day. Helpful for sizing and parameter tunning. 
