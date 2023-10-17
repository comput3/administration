SELECT 
    TRUNC(COMPLETION_TIME) ARCHIVED_DATE,
    SUM(BLOCKS * BLOCK_SIZE) / 1024 / 1024 SIZE_IN_MB
FROM
    V$ARCHIVED_LOG
GROUP BY 
    TRUNC(COMPLETION_TIME)
ORDER BY 1;
