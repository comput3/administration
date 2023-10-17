SELECT 
    OPNAME, 
    SID, 
    SERIAL#, 
    CONTEXT, 
    SOFAR, 
    TOTALWORK,
        ROUND(SOFAR/TOTALWORK*100,2) "%_COMPLETE"
FROM 
    GV$SESSION_LONGOPS
WHERE 
    OPNAME in
        (
            SELECT 
                d.job_name
            FROM 
                gv$session s 
                ,gv$process p 
                ,dba_datapump_sessions d
            WHERE 
                p.addr=s.paddr 
            AND 
                s.saddr=d.saddr
        )
AND 
    OPNAME NOT LIKE '%aggregate%'
AND 
    TOTALWORK != 0
AND 
    SOFAR <> TOTALWORK;
