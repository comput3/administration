#!/bin/ksh
USAGE="usage: $0 /path/to/tnsfile.ora"
clear
# INPUT VERIFICATION #
if [[ -z $1 ]]; then
   echo -e $USAGE
   exit 1;
fi
tns_path_file=$1
tmp_tns_dir=/tmp/tns_check_$$
tns_loc=${tmp_tns_dir}/tnsnames.ora
if [[ ! -d ${ORACLE_HOME} ]];
then
  until [[ -d ${ORACLE_HOME} ]];do read ORACLE_HOME?"Enter ORACLE_HOME: "; done
fi

# Main
mkdir ${tmp_tns_dir}
cp ${tns_path_file} ${tns_loc}
if [[ ! -f ${tns_loc} ]];then echo "Could not copy file to temp!"; exit; fi
export TNS_ADMIN=/tmp/tns_check_$$/
printf "%-30s %-30s\n" "TNSName" "Test"
printf "%-30s %-30s\n" "------------------------------" "------------------------------"

for i in $(grep ^[a-z,A-Z] ${tns_loc} | grep = | awk '{print $1}')
do
  if [[ `$ORACLE_HOME/bin/tnsping ${i} | grep TNS-` != "" ]]
  then
    printf "%-30s %-30s\n" "$i" "--------------Fail--------------"
  else
    printf "%-30s %-30s\n" "$i" "Pass"
  fi
done
unset TNS_ADMIN
chk_space=$(egrep "\(|\)" ${tns_loc} | grep -v ^# | awk -F'[^ ]' '{print length($1)}' | sort -u | head -n 1)
if [[ ${chk_space} -lt 2 ]];
then
  printf "%-30s %-30s\n" "Double space check." "--------------Fail--------------"
else
  printf "%-30s %-30s\n" "Double space check." "Pass"
fi
if [[ -d ${tmp_tns_dir} ]]; then rm -rf /tmp/tns_check_$$; fi
