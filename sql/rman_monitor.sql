set pages 5000 lines 200
col operation for a10
col "MB/s" for 9999
select 
    operation, 
    start_time,
    sysdate "Current_Time", 
    round(mbytes_processed) "MB Processed",
    round(mbytes_processed/((sysdate - start_time)*24*60*60)) "MB/s",
    round((sysdate - start_time)*24,2) "Total Hrs Run",round(mbytes_processed/dbsize_mbytes*100,2) "Percent Complete",
--  round(dbsize_mbytes/round(mbytes_processed/((sysdate - start_time)*24*60*60))/60/60/24,2) "EST Days Total Days",
    round((dbsize_mbytes - mbytes_processed)/(mbytes_processed/((sysdate - start_time)*24*60*60))/60/60/24,2) "EST Days to complete:",
    to_char(start_time + (sysdate-start_time)/(mbytes_processed/dbsize_mbytes),'DD-MON-YYYY HH24:MI:SS') "EST Day Completed"
FROM
    v$rman_status,(select sum(bytes)/1024/1024 dbsize_mbytes from v$datafile)
WHERE 
    mbytes_processed>0 
AND
--operation like '%BACKUP%' and 
status like 'RUNNING%';
