#!/usr/bin/env perl

# Many things are done in this in an effort to improve performance.
use strict;
use utf8;
use Time::Local;

my $path = '/proc/';

# This method finds all the processes on the box. 
# We check each process at the time of split to avoid having 
# to access the array 1000 times.
sub _find_all_processes
{
	my %mon2num = qw(  Jan 0  Feb 1  Mar 2  Apr 3  May 4  Jun 5  Jul 6  Aug 7  Sep 8  Oct 9 Nov 10 Dec 11);
	my $version = $_[0];
	my @xml_string;
	my @process_arr;
	my @processes = `ps --no-headers -eo "pid,nlwp,lstart,cmd" `;
	# do the check outside of the loop and duplicate the loop,
	# so we are not checking 1000s of times.
	if ($version > 5.9)
	{
		foreach my $line (@processes)
		{
			# we split into 8 because this will get all the spaces with the date formatting
			# and leave the entire process command intact.
			@process_arr = split ' ', $line, 8;
			my $start_date = timelocal(substr($process_arr[5],6,2),substr($process_arr[5], 3,2), substr($process_arr[5], 0,2), $process_arr[4], $mon2num{ $process_arr[3] },  $process_arr[6]);
			
			# Add all xml lines to an array so we only write to the console all at once.
			# Parameters being passed in order: pid,threads,start_time(long form),cmd
			push (@xml_string, _read_smaps_file_ver_greater_6($process_arr[0], $process_arr[1], $start_date * 1000, $process_arr[7]));
		}
	}
	else
	{
		foreach my $line (@processes)
		{
			# we split into 8 because this will get all the spaces with the date formatting
			# and leave the entire process command intact.
			@process_arr = split ' ', $line, 8;
			my $start_date = timelocal(substr($process_arr[5],6,2),substr($process_arr[5], 3,2), substr($process_arr[5], 0,2), $process_arr[4], $mon2num{ $process_arr[3] },  $process_arr[6]);
			
			# Add all xml lines to an array so we only write to the console all at once.
			# Parameters being passed in order: pid,threads,start_time(long form),cmd
			push (@xml_string, _read_smaps_file_ver_less_6($process_arr[0], $process_arr[1], $start_date * 1000, $process_arr[7]));
		}
	}
	return @xml_string  
}

# Try and get the OS version, on RHEL and FEDORA(test box) this works.
sub _determine_OS_version
{
	my $version = `cat /etc/redhat-release`;
	# check for version in the form of #.#
	(my $ver_num) =  $version =~ /(\d+.\d)/;
	return $ver_num;
}

# Print the string in xml format. Each entry is on its own line.
# This version has fields for linux version 6 and HIGHER.
sub _create_xml_string_6_higher
{
	return "<PID>" . $_[12] . "</PID><THREADS>" . $_[13] . "</THREADS><START_TIME>" . $_[14] . "</START_TIME><CMD>" . $_[15] . "</CMD><RSS>" . $_[0] . "</RSS><PSS>" . $_[1] . "</PSS><SHARED_CLEAN>" . $_[2] . "</SHARED_CLEAN><SHARED_DIRTY>" . $_[3] . "</SHARED_DIRTY><PRIVATE_CLEAN>" . $_[4] . "</PRIVATE_CLEAN><PRIVATE_DIRTY>" . $_[5] . "</PRIVATE_DIRTY><REFERENCED>" . $_[6] . 	"</REFERENCED><ANONYMOUS>" . $_[7] . "</ANONYMOUS><ANONHUGEPAGES>" . $_[8] . "</ANONHUGEPAGES><SWAP>" . $_[9] . "</SWAP><KERNELPAGESIZE>" . $_[10] . "</KERNELPAGESIZE><MMUPAGESIZE>" . $_[11] . "</MMUPAGESIZE>\n";
}

# This version has fields for linux version 6 and LOWER
sub _create_xml_string_6_lower
{
	return "<PID>" . $_[7] . "</PID><THREADS>" . $_[8] . "</THREADS><START_TIME>" . $_[9] . "</START_TIME><CMD>" . $_[10] . "</CMD><RSS>" . $_[0] . "</RSS><PSS>" . $_[1] . "</PSS><SHARED_CLEAN>" . $_[2] . "</SHARED_CLEAN><SHARED_DIRTY>" . $_[3] . "</SHARED_DIRTY><PRIVATE_CLEAN>" . $_[4] . "</PRIVATE_CLEAN><PRIVATE_DIRTY>" . $_[5] . "</PRIVATE_DIRTY><SWAP>" . $_[6] . "</SWAP>\n";
}


sub _read_smaps_file_ver_less_6
{
	my $pid = $_[0];
        my $threads = $_[1];
	my $start_time = $_[2];
	my $cmd = $_[3];
	chomp $cmd;
	my $rss = 0;
	my $pss = 0; 
	my $shared_clean = 0;
	my $shared_dirty = 0;
	my $private_clean = 0;
	my $private_dirty = 0;
	my $swap = 0;


	my $next_line = '';

	if (open ("smapps", '</proc/' . $pid . '/smaps'))
	{
		# Unroll the loop (peformance)
		# this has the drawback of not being to dynamically check,
		# if files change order they are in the data will be put into the wrong fields.
		while ($next_line = <smapps>)
		{
			if ($next_line =~ 'Rss:\s+\d')
			{
				my ($memory_value) = $next_line =~ /(\d+)/;
				$rss += $memory_value;
				$next_line = <smapps>;	

				my ($memory_value2) = $next_line =~ /(\d+)/;
				$shared_clean += $memory_value2;
				$next_line = <smapps>;

				my ($memory_value3) = $next_line =~ /(\d+)/;
				$shared_dirty += $memory_value3;
				$next_line = <smapps>;

				my ($memory_value4) = $next_line =~ /(\d+)/;
				$private_clean += $memory_value4;
				$next_line = <smapps>;

				my ($memory_value5) = $next_line =~ /(\d+)/;
				$private_dirty += $memory_value;
				$next_line = <smapps>;

				my ($memory_value9) = $next_line =~ /(\d+)/;
				$swap += $memory_value9;
				$next_line = <smapps>;

				my ($memory_value1) = $next_line =~ /(\d+)/;
				$pss += $memory_value1;
				$next_line = <smapps>;
			}
		}
		# returns each entry as a string.
		return _create_xml_string_6_lower($rss, $pss, $shared_clean, $shared_dirty, $private_clean, $private_dirty, $swap, $pid, $threads, $start_time, $cmd);

	}
}


# Reads the smaps file for RHEL 6 and greater and does regex matches to get the values that we need.
sub _read_smaps_file_ver_greater_6
{
	my $pid = $_[0];
        my $threads = $_[1];
	my $start_time = $_[2];
	my $cmd = $_[3];
	chomp $cmd; 
	my $rss = 0;
	my $pss = 0;
	my $shared_clean = 0;
	my $shared_dirty = 0;
	my $private_clean = 0;
	my $private_dirty = 0;
	my $referenced = 0;
	my $anonymous = 0;
	my $anonHugePages = 0;
	my $swap = 0;
	my $KernelPageSize = 0;
	my $mmuPageSize = 0;
	
	my $line_counter = 0;
	my $next_line;
	if(open ("smapss", '</proc/' . $pid . '/smaps'))
	{
		# Unroll the loop for performance.
		# this has the drawback of not being to dynamically check,
		# if files change order they are in the data will be put into the wrong fields.
		while ($next_line = <smapss>)
		{
			if ($next_line =~ 'Rss:\s+\d')
			{
				my ($memory_value) = $next_line =~ /(\d+)/;
				$rss = $rss + $memory_value;
				$next_line = <smapss>;

				my ($memory_value1) = $next_line =~ /(\d+)/;
				$pss = $pss + $memory_value1;
				$next_line = <smapss>;

				my ($memory_value2) = $next_line =~ /(\d+)/;
				$shared_clean = $shared_clean + $memory_value2;
				$next_line = <smapss>;

				my ($memory_value3) = $next_line =~ /(\d+)/;
				$shared_dirty = $shared_dirty + $memory_value3;
				$next_line = <smapss>;

				my ($memory_value4) = $next_line =~ /(\d+)/;
				$private_clean = $private_clean + $memory_value4;
				$next_line = <smapss>;

				my ($memory_value5) = $next_line =~ /(\d+)/;
				$private_dirty = $private_dirty + $memory_value5;
				$next_line = <smapss>;

				my ($memory_value6) = $next_line =~ /(\d+)/;
				$referenced = $referenced + $memory_value6;
				$next_line = <smapss>;

				my ($memory_value7) = $next_line =~ /(\d+)/;
				$anonymous = $anonymous + $memory_value7;
				$next_line = <smapss>;

				my ($memory_value8) = $next_line =~ /(\d+)/;
				$anonHugePages = $anonHugePages + $memory_value8;
				$next_line = <smapss>;

				my ($memory_value9) = $next_line =~ /(\d+)/;
				$swap = $swap + $memory_value9;
				$next_line = <smapss>;

				my ($memory_value0) = $next_line =~ /(\d+)/;
				$KernelPageSize = $KernelPageSize + $memory_value0;
				$next_line = <smapss>;

				my ($memory_value11) = $next_line =~ /(\d+)/;
				$mmuPageSize = $mmuPageSize + $memory_value11;
				$next_line = <smapss>;
			}
		}
		# returns each entry as a string.
		return _create_xml_string_6_higher($rss, $pss, $shared_clean, $shared_dirty, $private_clean, $private_dirty, $referenced, $anonymous, $anonHugePages, $swap, $KernelPageSize, $mmuPageSize, $pid, $threads, $start_time, $cmd);
	}
}

my @xml_string;
my $version = _determine_OS_version();

# do everything in this function to avoid having to iterate through the array again.
@xml_string = _find_all_processes($version);
print @xml_string;
exit 0;
