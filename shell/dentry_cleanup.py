#!/usr/bin/env python3
import os

def main():
    # Get the current size of the dentry cache
    dentry_cache_size = os.popen("cat /proc/sys/fs/dentry-state | awk '{print $1}'").read()

    try:
        # Convert the size of the dentry cache to an integer
        dentry_cache_size = int(dentry_cache_size)
    except ValueError:
        # If the conversion fails, print an error message and exit
        print("Failed to convert dentry cache size to integer")
        exit()

    # If the size of the dentry cache exceeds 30000000, drop it
    if dentry_cache_size > 30000000:
        # Call the sync command to flush unwritten data to disk
        os.system("sync")

        # Drop the dentry cache
        os.system("echo 3 > /proc/sys/vm/drop_caches")

if __name__ == "__main__":
    main()
