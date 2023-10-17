#!/usr/bin/env bash
###########################################################################################
:<<'__DOCUMENTATION-BLOCK__'
###########################################################################################

NAME:
    <>
AUTHOR:
    Joe Huck
SYNOPSIS:
    <>
GIT:
    <>
VERSION:
    script_version=0.1.0
       
###########################################################################################
__DOCUMENTATION-BLOCK__
###########################################################################################

#Set environment options
#set -o errexit      # -e Any non-zero output will cause an automatic script failure
set -o pipefail     #    Any non-zero output in a pipeline will return a failure
set -o noclobber    # -C Prevent output redirection from overwriting an existing file
set -o nounset      # -u Prevent use of uninitialized variables
#set -o xtrace      # -x Same as verbose but with variable expansion

# color variables
readonly red='\e[0;31;40m'
readonly yellow='\e[0;93;40m'
readonly green='\e[0;32;40m'
readonly nocolor='\e[0m'

#--------------------------------------------------------------------------
#    FUNCTION       check_root
#    DESCRIPTION    ensure script is executed as root
#--------------------------------------------------------------------------
function check_root(){
    if [[ $(whoami) != "root" ]] ; then
            echo -e "${red}This script must be ran as root${nocolor}"
            return 2;
    fi
}

#--------------------------------------------------------------------------
#    FUNCTION       check_prereqs
#    SYNTAX         check_prereqs <system util to be checked>
#    DESCRIPTION    This function checks the availability of program that is to
#                   be used within the function its called
#                   0=Success
#                   1=Failure
#--------------------------------------------------------------------------
function check_prereqs(){
    if [[ $# -le 0 ]]
    then
        #Invalid number of arguments
        >&2 echo "Received an invalid number of arguments"
        return 1
    fi
 
    local return_code=0
 
    programs=(${@})
    for program in ${programs[@]}
    do
        which ${program} > /dev/null 2>&1 || local return_code=1
    done
 
    return ${return_code}
}

#--------------------------------------------------------------------------
#    FUNCTION       check_execution
#    SYNTAX         check_execution <PID_FILE>
#    DESCRIPTION    This function identifies if there is already an instance of this script running
#                   0=Success
#                   1=Failure
#                   2=Error
#--------------------------------------------------------------------------
function check_execution(){
    #Validate the number of passed variables
    if [[ $# -ne 1 ]];then
        #Invalid number of arguments
        >&2 echo "Received an invalid number of arguments"
        return 2
    fi

    #Assign variables passed
    declare pid_file="${1}"; shift

    #Determine if we're locking or unlocking the passed file
    if [[ "${pid_file:0:4}" = "STOP" ]];then
        #Remove any locks to prevent child processes from holding onto them
        flock -u 9 1>/dev/null 2>&1 || (rc=$? && >&2 echo "File ${pid_file} could not be unlocked" && return $rc)

        #Remove the lock file
        rm "${pid_file:4}" 1>/dev/null 2>&1 || (rc=$? && >&2 echo "Lock file ${pid_file:4} could not be removed" && return $rc)
    else
        #Use a file descriptor to track a file for locking so we can utilize flock
        exec 9>"${pid_file}" || (rc=$? && >&2 echo "File descriptor redirection to ${pid_file} failed" && return $rc)

        #Acquire an exclusive lock to file descriptor 9 or fail
        flock -n 9 1>/dev/null 2>&1 || (rc=$? && >&2 echo "An instance of ${script_name} is already locked to ${pid_file}" && return $rc)
    fi
}

#--------------------------------------------------------------------------
#    FUNCTION       script_exit
#    SYNTAX         script_exit <exitCode>
#    DESCRIPTION    Cleans up logs, traps, flocks, and performs any other exit tasks
#--------------------------------------------------------------------------
function script_exit(){
    #Validate the number of passed variables
    if [[ $# -gt 1 ]];then
        #Invalid number of arguments
        #We're just echoing this as a note, we still want the script to exit
        >&2 echo "Received an invalid number of arguments"
    fi

    #Define variables as local first
    declare exit_code="$1"; shift

    #Reset signal handlers to default actions
    trap - 0 1 2 3 15

    #Remove any file descriptor locks
    check_execution "STOP${pid_file}" || >&2 echo "Removing file descriptor locks failed"

    #Exit
    exit "${exit_code}"
}

#--------------------------------------------------------------------------
#    FUNCTION       setup_directory
#    SYNTAX         setup_directory <DirectoryName>
#    DESCRIPTION    Accepts full directory path and verifies if it can be written to
#                   0=Success
#                   1=Failure
#                   2=Error
#--------------------------------------------------------------------------
function setup_directory(){
    #Validate the number of passed variables
    if [[ $# -ne 1 ]];then
        #Invalid number of arguments
        >&2 echo "Received an invalid number of arguments"
        return 2
    fi

    #Assign variables passed
    declare directory=$1; shift

    #Check for the directory
    if [[ ! -a "${directory}" ]];then
        #The directory doesn't exist, try to create it
        mkdir -p "${directory}" 1>/dev/null 2>&1 || (rc=$? && >&2 echo "The directory ${directory} does not exist and could not be created" && return $rc)
    fi

    #Check if the direcotory is writeable
    if [[ ! -w "${directory}" ]];then
        #The directory is not writeable, lets try to change that
        chmod ugo+w "${directory}" 1>/dev/null 2>&1 || (rc=$? && >&2 echo "The directory ${directory} can not be written to and permissions could not be modified" && return $rc)
    fi

    #No Error
    return 0
}

#--------------------------------------------------------------------------
#    FUNCTION       setup_file
#    SYNTAX         setup_file <file_name>
#    DESCRIPTION    Accepts full file path and verifies if it can be written to
#                   0=Success
#                   1=Failure
#                   2=Error
#--------------------------------------------------------------------------
function setup_file(){
    #Validate the number of passed variables
    if [[ $# -ne 1 ]];then
        #Invalid number of arguments
        >&2 echo "Received an invalid number of arguments"
        return 2
    fi

    #Assign variables passed
    declare file_path=$1; shift
    typeset directory="${file_path%/*}"

    setup_directory "${directory}" || return $?

    #Check if the file already exists
    if [[ -a "${file_path}" ]];then
        #The file already exists, is it writable?
        if [[ ! -w "${file_path}" ]];then
            #The file exists but is NOT writeable, lets try changing it
            chmod ugo+w "${file_path}" 1>/dev/null 2>&1 || (rc=$? && >&2 echo "File ${file_path} exists but is not writeable and permissions could not be modified" && return $rc)
        fi
    else
        #The file does not exist, lets touch it
        touch "${file_path}" 1>/dev/null 2>&1 || (rc=$? && >&2 echo "File ${file_path} does not exist and could not be created" && return $rc)
    fi

    #No Error
    return 0
}

#--------------------------------------------------------------------------
#    FUNCTION       main 
#    DESCRIPTION    This function will call necessary functions
#--------------------------------------------------------------------------

function main(){
    check_root

    #clean log files from previous execution
    find "${log_path}" -type f | while read -r line
    do
        rm "${line}" || >&2 echo "Removing old log file ${line} failed"
    done

    #exit script
    script_exit "${exit_code:-0}"
}

#--------------------------------------------------------------------------
#     MAIN
#--------------------------------------------------------------------------

#Save information about our script
readonly script_file="${0##*/}"
readonly script_name="${script_file%.*}"
readonly script_extension="${script_file##*.}"
readonly script_path=$(readlink -f "$0")
readonly script_dir="${script_path%/*}"
readonly script_flags="$@"

#See if this script is already running/
pid_file="/var/run/${script_name}.pid"
check_execution "${pid_file}" || script_exit $?


#Set signal handlers to run our script_exit function
trap 'rc=$?; script_exit $rc' 0 1 2 3 15

#Timestamp
readonly time_stamp=$(date +"%Y.%m.%d.%H.%M.%S")

#Various log files
readonly log_dir="/var/log"
readonly log_path="${log_dir}/${script_name}"
readonly log_file="${log_path}/${script_name}.${time_stamp}.log"

#Setup Logs
setup_file "${log_file}" || (rc=$? && >&2 echo "Validating logfile ${log_file} failed" && script_exit $rc)

#Execute main
main "$@"> >(tee "${log_file}") 2>&1

#This exist only exists as a fail safe. Always exit from your main function
script_exit 0
