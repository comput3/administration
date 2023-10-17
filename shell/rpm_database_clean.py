#!/usr/bin/env python3
"""
The RPM database is a central database used by the RPM Package Manager to store information about installed packages on a Red Hat Enterprise Linux (RHEL) system. 
The script provided has several functions that allow you to check the integrity of the RPM database, create a backup of the database, restore the database from a backup, and rebuild the database. 

Author: Joe Huck
"""
import platform
import os
import sys
import fcntl
import subprocess
import datetime 

def check_rpm():
    # Run the timeout command with a timeout of 8 seconds and the rpm command
    process = subprocess.Popen(["timeout", "-k", "4", "8s", "rpm", "-qa"], stdout=subprocess.PIPE)
    try:
        # Wait for the process to complete
        output, _ = process.communicate()
    except subprocess.TimeoutExpired:
        # If the process times out, kill it and return False
        process.kill()
        return False

    # Check the exit code of the process
    if process.returncode == 0:
        # If the exit code is zero, run the rpmdb_verify command
        result = subprocess.run(["/usr/lib/rpm/rpmdb_verify", "/var/lib/rpm/Packages"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode == 0:
            # If the command returns a zero exit code, return True
            return True
        else:
            # If the command returns a non-zero exit code, return False
            return False
    else:
        # If the exit code is non-zero, return False
        return False

def backup_rpm_database():
    # Change to the /var/lib directory
    os.chdir("/var/lib")
    # Create the name for the backup file using the current date and time
    backup_file_name = "rpmdb-" + datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S") + ".tar.gz"
    # Create the full path to the backup file
    backup_file_path = os.path.join("/var/preserve", backup_file_name)
    # Run the tar command to create a gzip archive of the rpm directory
    subprocess.run(["tar", "-zcvf", backup_file_path, "rpm"])

def restore_rpm_database(backup_file_path):
    try:
        # Extract the contents of the backup file to the RPM database directory
        subprocess.run(["tar", "-zxvf", backup_file_path, "-C", "/var/lib"])

        # Reset the SELinux attributes on the restored RPM database files
        subprocess.run(["restorecon", "-v", "/var/lib/rpm/*"])
    except Exception as e:
        # If an exception is raised, log an error message
        logging.error("An error occurred while restoring the RPM database: %s", e)

def rebuild_rpm_database():
    try:
        # Check if any RPM or package management commands are running
        result = subprocess.run(["ps", "aux"], stdout=subprocess.PIPE)
        output = result.stdout.decode()
        if "rpm" in output or "yum" in output or "up2date" in output:
            # If any RPM or package management commands are running, log an error message and return
            logging.error("Cannot rebuild RPM database because an RPM or package management command is running")
            return
        
        # Check if any files in the RPM database directory are open
        result = subprocess.run(["lsof", "+d", "/var/lib/rpm"], stdout=subprocess.PIPE)
        output = result.stdout.decode()
        if output:
            # If any files are open, log an error message and return
            logging.error("Cannot rebuild RPM database because some RPM database files are open")
            return

        # Remove the working RPM database files
        subprocess.run(["rm", "-f", "/var/lib/rpm/__db*"])

        # Validate that there are no corrupt packages
        os.chdir("/var/lib/rpm")
        result = subprocess.run(["/usr/lib/rpm/rpmdb_verify", "Packages"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode != 0:
            # If the rpmdb_verify command returns a non-zero exit code, log an error message and return
            logging.error("Cannot rebuild RPM database because there are corrupt packages")
            return

        # Rebuild the RPM database files
        subprocess.run(["rpm", "-vv", "--rebuilddb"])

        # Reset the SELinux attributes on the new RPM database files
        subprocess.run(["restorecon", "-v", "/var/lib/rpm/*"])

def main():
    # Construct the full path to the lock file
    lock_file_path = os.path.join("/tmp", "lock.txt")

    # Check if the lock file exists
    if os.path.exists(lock_file_path):
    # Print an error message
        print("ERROR: An existing lock file was found. This script cannot run while the lock file exists.")
        # Exit the script
        sys.exit(1)

    try:
    # Open the lock file in write mode
        with open(lock_file_path, "w") as lock_file:
            # Obtain a lock on the file using the LOCK_EX flag
            fcntl.flock(lock_file, fcntl.LOCK_EX)

            if platform.system() != "Linux":
                print("This script is intended for use on Linux systems. Exiting.")
                sys.exit()

            # Check if check_rpm() returns False
            if not check_rpm():
                # If check_rpm() returns False, exit the program with an error code
                sys.exit(1)

            backup_rpm_database()
            rebuild_rpm_database()

    finally:
        # Remove the lock file if it exists
        if os.path.exists(lock_file_path):
            os.remove(lock_file_path)

if __name__ == "__main__":
    main()
