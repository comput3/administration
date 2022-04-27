#!/usr/bin/env python3
import subprocess as sp
import traceback
import fcntl
import os

def get_dentry_cache():
    dentry_info = sp.getoutput('grep -i dentry /proc/slabinfo')
    return int(dentry_info.split()[1])

def main():
    try:
        lock_file = '/tmp/dentry.lock'
        lock = open(lock_file, 'w')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        dentry_cache = get_dentry_cache()

        if dentry_cache >= 3e+7:
            try:
                rc = sp.call('sync;echo 3 > /proc/sys/vm/drop_caches', shell=True)
                dentry_cache_new = get_dentry_cache()
                if (rc > 0) or (dentry_cache <= dentry_cache_new):
                    print('Failed to drop dentry cache')
            except Exception:
                traceback.print_exc()

        fcntl.flock(lock, fcntl.LOCK_UN)
        if os.path.isfile(lock_file):
            os.remove(lock_file)
    except IOError as err:
        raise SystemExit('Unable to obtain file lock: {}'.format(lock_file))

if __name__ == "__main__":
    main()
