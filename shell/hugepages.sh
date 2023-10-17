#!/bin/bash
kernel=`uname -r | awk -F. '{ printf("%d.%d\n",$1,$2); }'`

# Find out the HugePage size
hp_sz=`grep Hugepagesize /proc/meminfo | awk {'print $2'}`

# Start from 1 pages to be on the safe side and guarantee 1 free HugePage
num_pg=1

# Cumulative number of pages required to handle the running shared memory segments
for seg_bytes in `ipcs -m | awk {'print $5'} | grep "[0-9][0-9]*"`
do
   min=`echo "$seg_bytes/($hp_sz*1024)" | bc -q`
   if [ $min -gt 0 ]; then
      num_pg=`echo "$num_pg+$min+1" | bc -q`
   fi
done

case $kernel in
   '2.4') HUGETLB_POOL=`echo "$num_pg*$hp_sz/1024" | bc -q`;
          echo "Recommended setting: vm.hugetlb_pool = $HUGETLB_POOL" ;;
   '2.6' | '3.8' | '3.10' | '4.1' ) echo "Recommended setting: vm.nr_hugepages = $num_pg" ;;
    *) echo "Unrecognized kernelel version $kernel. Exiting." ;;
esac

exit 0
