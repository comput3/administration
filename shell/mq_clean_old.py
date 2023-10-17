#!/usr/bin/env python3
"""
This script is a utility for managing IBM MQ installations on a machine post MQ upgrade.
Author: Joe Huck
"""
import platform
import re
import os
import sys
import glob
import fcntl
import shutil
import subprocess
import logging

# Set the logging level (e.g. DEBUG, INFO, WARNING, ERROR)
logging.basicConfig(level=logging.INFO)

# Set the log format
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# Set the log destination (e.g. a file or the console)
handler = logging.StreamHandler()  # log to the console
# handler = logging.FileHandler('log.txt')  # log to a file
handler.setFormatter(formatter)

# Add the handler to the logger
logger = logging.getLogger(__name__)
logger.addHandler(handler)

class MQInstallation:
    """
    This class represents an IBM MQ installation on a machine. It provides methods to get information about the installation, such as its version and installation path.
    """
    def __init__(self, installation):
        self.installation = installation

    def get_dspmqver_version(self):
        # Run the dspmqver command and return the version of MQ that is installed on the machine
        process = subprocess.Popen(["dspmqver", "-b", "-f", "2"], stdout=subprocess.PIPE)
        output, _ = process.communicate()
        dspmqver_version = output.decode().strip()
        return dspmqver_version

    def get_install_path(self):
        # Run the dspmqinst command with the -n option to get information about the installation
        process = subprocess.Popen(["dspmqinst", "-n", self.installation], stdout=subprocess.PIPE)
        output, error = process.communicate()

        # Check the return code of the dspmqinst command
        if process.returncode != 0:
            logger.error(f"Failed to get information about the MQ installation {self.installation}. The dspmqinst command returned a non-zero exit code.")
            return None

        # Split the output into a list of lines
        lines = output.decode().strip().split('\n')

        # Iterate over the list of lines
        for line in lines:
            # Check if the line starts with "InstallPath"
            if line.startswith("InstPath"):
                # Split the line into words
                words = line.split()
                # The installation path is the second word
                install_path = words[1]
                # Return the installation path
                return install_path

        # If no installation path was found, return None
        return None

    def get_dspmqinst_version(self):
        # Run the dspmqinst command with the -n option to get information about the installation
        process = subprocess.Popen(["dspmqinst", "-n", self.installation], stdout=subprocess.PIPE)
        output, error = process.communicate()

        # Check the return code of the dspmqinst command
        if process.returncode != 0:
            logger.error(f"Failed to get information about the MQ installation {self.installation}. The dspmqinst command returned a non-zero exit code.")
            return None

        # Split the output into a list of lines
        lines = output.decode().strip().split('\n')

        # Iterate over the list of lines
        for line in lines:
            # Check if the line starts with "Version"
            if line.startswith("Version"):
                # Split the line into words
                words = line.split()
                # The version is the second word
                dspmqinst_version = words[1]
                # Return the data path
                return dspmqinst_version

        # If no data path was found, return None
        return None


def get_installations():
    # Run the dspmqinst command to get a list of all MQ installations
    process = subprocess.Popen(["dspmqinst"], stdout=subprocess.PIPE)
    output, error = process.communicate()

    # Check the return code of the dspmqinst command
    if process.returncode != 0:
        logger.error("ERROR: Failed to get a list of MQ installations. The dspmqinst command returned a non-zero exit code.")
        return None

    pattern = re.compile(r"^InstName:\s+(.+)$", re.MULTILINE)
    matches = pattern.findall(output.decode().strip())

    installations = {}
    for installation in matches:
        # Run the dspmqinst -n command to get information about the current installation
        process = subprocess.Popen(["dspmqinst", "-n", installation], stdout=subprocess.PIPE)
        output, error = process.communicate()

        # Check the return code of the dspmqinst -n command
        if process.returncode != 0:
            logger.error(f"ERROR: Failed to get information about MQ installation '{installation}'. The dspmqinst -n command returned a non-zero exit code.")
            continue

        # Check for lines starting with "Primary" in the output
        for line in output.decode().strip().split("\n"):
            if line.startswith("Primary"):
                # Split the line into words
                words = line.split()
                # The version is the second word
                primary_value = words[1]
                # Add the installation and its primary value to the dictionary
                installations[installation] = primary_value
                break

    return installations
    

def check_installed_mq_packages(rpm_suffix):
    # Run the rpm command with the -qa option to get a list of all installed packages
    process = subprocess.Popen(["timeout", "-k", "4", "8s", "rpm", "-qa"], stdout=subprocess.PIPE)
    output, error = process.communicate()

    # Check the return code of the rpm command 
    if process.returncode != 0:
        logger.error("ERROR: Unable to communicate with the RPM database. The rpm command returned a non-zero exit code.")
        return []

    # Split the output into a list of package names
    packages = output.decode().strip().split('\n')

    # Filter the list of packages to include only those that contain the string "MQSeries"
    mq_packages = [package for package in packages if "MQSeries" in package]

    # Initialize a list to store invalid MQ packages
    invalid_packages = []

    # Iterate over the list of MQ packages and check if each package name contains the RPM suffix
    for package in mq_packages:
        if rpm_suffix not in package:
            # If the package does not contain the RPM suffix, add it to the list of invalid packages
            invalid_packages.append(package)

    # Return the list of invalid packages
    return invalid_packages

# def remove_invalid_mq_packages(rpm_suffix):
#     # Get the list of invalid MQ packages
#     invalid_packages = check_installed_mq_packages(rpm_suffix)

#     # Check if there are any invalid packages
#     if not invalid_packages:
#         logger.info("No invalid MQ packages found.")
#         return True

#     # Print a list of invalid packages
#     logger.info("The following invalid MQ packages will be removed:")
#     for package in invalid_packages:
#         print(package)

#     # Prompt the user for confirmation
#     confirmation = input("Are you sure you want to proceed? (y/n) ")

#     # Check the user's response
#     if confirmation.lower() != "y":
#         logger.info("Aborting package removal.")
#         return False

#     # Iterate over the list of invalid MQ packages
#     for package in invalid_packages:
#         # Run the rpm command with the -e option to remove the package, using the --noscripts argument to skip scripts
#         process = subprocess.Popen(["rpm", "-e", "--noscripts", package])
#         process.communicate()

#         # Check the return code of the rpm command
#         if process.returncode != 0:
#             logger.error(f"ERROR:Failed to remove the invalid MQ package {package}")
#             return False

#     logger.info("All invalid MQ packages have been removed.")
#     return True

# def delete_unused_installations(installations):
#     for installation, used in installations.items():
#         if used == "No":
#             logger.info(f"Deleting unused installation {installation}...")
#             process = subprocess.Popen(["dltmqinst", "-n", installation])
#             process.wait()
#             if process.returncode != 0:
#                 logger.error(f"ERROR:Failed to delete installation {installation}. The dltmqinst command returned a non-zero exit code.")
#             else:
#                 logger.info(f"Successfully deleted installation {installation}.")

# def delete_mq_directories(primary_install_path):
#     # Get a list of all directories starting with "/opt/mq"
#     directories = glob.glob("/opt/mq*")

#     # Check if the primary installation path is in the list of directories
#     if primary_install_path in directories:
#         # If it is, remove it from the list
#         directories.remove(primary_install_path)

#     # Iterate over the list of directories
#     for directory in directories:
#         # Check if the directory exists
#         if os.path.exists(directory):
#             # If it does, delete it
#             shutil.rmtree(directory)

def main():
    # Construct the full path to the lock file
    lock_file_path = os.path.join("/tmp", "lock.txt")

    # Check if the lock file exists
    if os.path.exists(lock_file_path):
    # Print an error message
        logger.error("ERROR: An existing lock file was found. This script cannot run while the lock file exists.")
        # Exit the script
        sys.exit(1)

    try:
    # Open the lock file in write mode
        with open(lock_file_path, "w") as lock_file:
            # Obtain a lock on the file using the LOCK_EX flag
            fcntl.flock(lock_file, fcntl.LOCK_EX)

            if platform.system() != "Linux":
                logger.info("This script is intended for use on Linux systems. Exiting.")
                sys.exit()

            # Check if the environment variable is set
            if not os.getenv('environment'):
                # If the environment variable is not set, exit the program with an error code
                logger.info("The environment is not set, please set it and re-execute")
                sys.exit(1)
            else:
                # If the environment variable is set, store its value in a variable
                environment = os.getenv('environment')

            # Get the dictionary of all MQ installations
            installations = get_installations()

            # Set the primary_installation variable to the key where the value is 'Yes'
            primary_installation_name = next((key for key, value in installations.items() if value == 'Yes'), None)

            primary_mq_installation = MQInstallation(primary_installation_name)
            primary_dspmqver_version = primary_mq_installation.get_dspmqver_version()
            primary_dspmqinst_version = primary_mq_installation.get_dspmqinst_version()
    

            # Check if the versions match
            if primary_dspmqver_version != primary_dspmqinst_version:
                logger.error("ERROR: The version of MQ reported by dspmqver does not match the version of the primary MQ installation in dspmqinst")
                sys.exit(1)

            primary_install_path = primary_mq_installation.get_install_path()
            major_version = primary_dspmqver_version[:3]
            rpm_suffix = 'mq' + major_version.replace('.', '') 

            # Print the vars
            logger.info(f"Primary Installation: {primary_installation_name}")
            logger.info(f"DSPMQVER MQ Version: {primary_dspmqver_version}")
            logger.info(f"DSPMQINST MQ Version: {primary_dspmqinst_version}")
            logger.info(f"Installation Path: {primary_install_path}")
            logger.info(f"MQ Major Version: {major_version}")
            logger.info(f"RPM Suffix: {rpm_suffix}")

            major_version = float(major_version)
            # Check if the major version is greater than or equal to 9
            if major_version < 9:
                logger.error(f"ERROR:The MQ installation {installation} has a version ({version}) that is less than 9.0. Exiting.")
            sys.exit(1)

            check_installed_mq_packages(rpm_suffix)

            # remove_invalid_mq_packages(rpm_suffix)

            # delete_unused_installations(installations)

            # Delete all directories matching /opt/mq* except for those owned by the primary installation 
            # delete_mq_directories(primary_install_path)

    finally:
        # Remove the lock file if it exists
        if os.path.exists(lock_file_path):
            os.remove(lock_file_path)

if __name__ == "__main__":
    main()
