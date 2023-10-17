col "Index Operation" for a60
SELECT 
    sess.sid as "Session ID", 
    sql.sql_text as "Index Operation",
    longops.totalwork, 
    longops.sofar,
    longops.elapsed_seconds/60 as "Runtime Mins",
    longops.time_remaining/60 as "ETA Mins"
FROM
    v$session sess, v$sql sql, v$session_longops longops
WHERE
    sess.sid=longops.sid
AND 
    sess.sql_address = sql.address
AND 
    sess.sql_address = longops.sql_address
AND 
    sess.status = 'ACTIVE'
AND 
    longops.totalwork > longops.sofar
AND 
    sess.sid not in (
                     SELECT
                        sys_context('USERENV', 'SID') SID
                     FROM 
                         DUAL)
AND UPPER(sql.sql_text) LIKE '%INDEX%';
