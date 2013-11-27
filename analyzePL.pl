#!/usr/local/bin/perl -w
#See https://confluence.slac.stanford.edu/display/IEPM/IEPM+Perl+Coding+Styles
#for version of perl to use.

# /*---------------------------------------------------------------*/
# /*          STANFORD UNIVERSITY NOTICES FOR SLAC SOFTWARE        */
# /*               ON WHICH COPYRIGHT IS DISCLAIMED                */
# /*                                                               */
# /* AUTHORSHIP                                                    */
# /* This software was created by <insert names>, Stanford Linear  */
# /* Accelerator Center, Stanford University.                      */
# /*                                                               */
# /* ACKNOWLEDGEMENT OF SPONSORSHIP                                */
# /* This software was produced by the Stanford Linear Accelerator */
# /* Center, Stanford University, under Contract DE-AC03-76SFO0515 */
# /* with the Department of Energy.                                */
# /*                                                               */
# /* GOVERNMENT DISCLAIMER OF LIABILITY                            */
# /* Neither the United States nor the United States Department of */
# /* Energy, nor any of their employees, makes any warranty,       */
# /* express or implied, or assumes any legal liability or         */
# /* responsibility for the accuracy, completeness, or usefulness  */
# /* of any data, apparatus, product, or process disclosed, or     */
# /* represents that its use would not infringe privately owned    */
# /* rights.                                                       */
# /*                                                               */
# /* STANFORD DISCLAIMER OF LIABILITY                              */
# /* Stanford University makes no representations or warranties,   */
# /* express or implied, nor assumes any liability for the use of  */
# /* this software.                                                */
# /*                                                               */
# /* STANFORD DISCLAIMER OF COPYRIGHT                              */
# /* Stanford University, owner of the copyright, hereby disclaims */
# /* its copyright and all other rights in this software.  Hence,  */
# /* anyone may freely use it for any purpose without restriction. */
# /*                                                               */
# /* MAINTENANCE OF NOTICES                                        */
# /* In the interest of clarity regarding the origin and status of */
# /* this SLAC software, this and all the preceding Stanford       */
# /* University notices are to remain affixed to any copy or       */
# /* derivative of this software made or distributed by the        */
# /* recipient and are to be affixed to any copy of software made  */
# /* or distributed by the recipient that contains a copy or       */
# /* derivative of this software.                                  */
# /*                                                               */
# /* SLAC Software Notices, Set 4 (OTT.002a, 2004 FEB 03)          */
# /*---------------------------------------------------------------*/
# Copyright (c) 2006, 2007    
# The Board of Trustees of          
# the Leland Stanford Junior University. All Rights Reserved.       

#The following code is placed at the top to ensure we are able to use perl -d
#and stop things before they call other things.
my $debug; #For cronjobs use -1, for normal execution from command line use 0, 
           #for debugging information use > 0, max value = 3.
if (-t STDOUT) {$debug=0;}
else           {$debug=-1;} #script executed from cronjob

#$debug=6;

use strict;
my $version="0.1, 07/03/08, Qasim Lone";
#  ....................................................................
(my $progname = $0) =~ s'^.*/'';#strip path components, if any

my $USAGE = "Usage:\t $progname [opts] 
        Opts:
        -v print this USAGE information
        -D debug_level (default=$debug)
        -f filename
Examples:
 $progname
 $progname -v -D 1

Version=$version
";

#  Please send comments and/or suggestion to Les Cottrell.
#
# **************************************************************** 
# Owner(s): Les Cottrell (6/15/08).                                
# Revision History:                                                
# **************************************************************** 
#Get some useful variables for general use in code
umask(0002); #First 0 is for octal system and each of the other octal number represent permission read write exe. this means --- --- rw-
use Sys::Hostname; 
my $ipaddr=gethostbyname(hostname()); #It will provide the Ipaddress of the current system
my ($a, $b, $c, $d)=unpack('C4',$ipaddr);#It will unpack the Ip address in 4 unsigned char (8 bits) because of C & 4
my ($hostname,$aliases, $addrtype, $length, @addrs)=gethostbyaddr($ipaddr,2);#Simply provides all these information
use Date::Calc qw(Add_Delta_Days Delta_Days Delta_DHMS);#Do date calculation using Gregorian calender like 01-Jan-1970 00:00:00 GMT $Dd = Delta_Days($year1,$month1,$day1,$year2,$month2,$day2)means total days between these dates and dhms include hrs,mins and secs as well.
use Date::Manip qw(ParseDate UnixDate);#To extract date from string and write back to string functions
use Time::Local;#efficiently compute local and GMT time
my $user=scalar(getpwuid($<));

#use Net::DNS::RR;

##############################################################
#Process options
require "getopts.pl";
our ( $opt_v, $opt_D)=( "", "");
&Getopts('vD:');

if($opt_v) {
  print "$USAGE"; 
  exit 1;
}

if($opt_D)  {$debug=$opt_D;}

my $time=localtime();
my $t0=time();
print "#".scalar(localtime())." $progname running on $user\@$hostname\n"; #Scalar forces a single piece of information, because output of localtime may be an array of strings.

my $cmd      = "ls -t  /afs/slac.stanford.edu/package/pinger/tulip/sitesxml";
my @ans      = `$cmd`;#This letter at tilda button '`' forces to execute DOS command inside cmd;
my $firstTime= 1; 
my $prevFile = "";
my %dataHash = ();
my $totalFiles= -1;
my  ($city,$country, $ip, $lat, $lng, $node, $region, $counter) = "";

foreach my $line (@ans){
        chomp $line;#Either read from file or any dos command data mostly they contain an enter in the end so must chomp to remove it
        my $file="/afs/slac.stanford.edu/package/pinger/tulip/sitesxml/$line";
	open DataFile, "< $file" or die $!. "Cannot open file $file: $!\n"; #'<' Operator is only used for reading purpose, you can also open a file in read mode without using this. These are just two conventions for a same task.
	$totalFiles++;	
        my @stats=stat($file);#stat calculate some statistics of file e.g.check this link http://perldoc.perl.org/functions/stat.html
        if($stats[7] < 1000) {
          print STDERR "Skip $file for "
              . scalar(getpwuid($stats[4]))." has only $stats[7] bytes\n";
          next;
        }
	if($debug >2){
		print "Opening $file  for reading\n\n\n\n";
	}
	while (<DataFile>) 
	{       #For more detail about $_ see this link http://www.wellho.net/mouth/969_Perl-and-.html 
		if ($_ =~ /#/) # Checking for comments and ignoring them 
		{
			if ($debug > 2)
			{
			print " Neglecting the comments \n";
			}
		} 
		else 
		{
			($city,$country, $ip, $lat, $lng, $node, $region) = split(/,/, $_);
			if($firstTime) # Putting the values in the hash so that when we check for the IP it should 
				      # not give is empty hash exception
			{
				
				$dataHash{ $ip }{ 'city' } = $city;
				$dataHash{ $ip }{ 'country' } = $country;
				$dataHash{ $ip }{ 'lat' } = $lat;
				$dataHash{ $ip }{ 'lng' } = $lng;
				$dataHash{ $ip }{ 'node' } = $node;
                                $dataHash{ $ip }{ 'region' } = $region;
				$dataHash{ $ip }{ 'counter' } = 0;      # Count total number of nodes in all files 
				$dataHash{ $ip }{ 'fileName' } = $line; # This value keep track of multiple entries in a file
                                
				if ( $debug > 2)
				{ 
					print "$city, $country,$ip, $lat, $lng, $node, $region" ;
				}


				$firstTime = 0;
			    } # end of first time
			else 
			{
				if (defined  ($dataHash{$ip})) #Check for valid reference see http://perldoc.perl.org/functions/defined.html
				{
					if ( $debug > 5)
                                        {

						print "The IP address ($ip) exists defined for value and file name is $line comparing with $dataHash{$ip}->{'fileName'} \n";
					}	
					if ((($dataHash{$ip}->{'fileName'}) =~ /$line/))
					{
						if ( $debug > 5)
						{
							print "There is some problem with parsing for ip address  $dataHash{$ip}->{'node'} \n"
						}
					}
					else
					{
						$dataHash{$ip}->{'counter'} =  $dataHash{$ip}->{'counter'} + 1; 
					
					}
				}
				else 
				{
					$dataHash{ $ip }{ 'city' } = $city;
                                	$dataHash{ $ip }{ 'country' } = $country;
					$dataHash{ $ip }{ 'lat' } = $lat;
                                	$dataHash{ $ip }{ 'lng' } = $lng;
                                	$dataHash{ $ip }{ 'node' } = $node;
                                	$dataHash{ $ip }{ 'region' } = $region;
                                	$dataHash{ $ip }{ 'counter' } = 0;      # Count total number of nodes in all files 
                                	$dataHash{ $ip }{ 'fileName' } = $line; 
				}

			
			}
			
		} 
	}
        close(DataFile);
} # end of foreach 

printData(\%dataHash,$totalFiles);

sub printData {
  my(%HoH) = %{(shift)}; #%HoH is creating Hash of Hash see http://docstore.mik.ua/orelly/perl/prog3/ch09_04.htm
  my $total = shift; # shift has the total number of files read
  my $val = "counter";
  #my $HoH =  shift;
  my $nhosts=0;
  my %sites;
  my %msgs;
  print "#$progname: total number of input files are: $total using $cmd\n";
  foreach my $ip ( sort keys %HoH ) {
#    if($HoH{$ip}{$val} < $totalFiles) {}
#    else {
      #print "$ip: \n ";
      $nhosts++;
      my @octets=split(/\./,$ip);
      $sites{"$octets[0]\.$octets[1]\.$octets[2]"}++;
      #print "$ip,";
      my $msg="$ip,";
      for my $properties ( sort keys %{ $HoH{$ip}} ) {
	$msg.="$HoH{$ip}{$properties}";
	if(!($properties =~ /region/)){$msg="$msg,";}
       	else{print "$msg";}
        $msgs{"$octets[0]\.$octets[1]\.$octets[2]"}=$msg;       
      }
#    }
  }
  my $nsites=0;
  foreach my $key (keys %sites) {
    $nsites++;
    print STDERR "($sites{$key})$msgs{$key}";
  }
  print "#".scalar(localtime())
      . " $progname: found $nhosts reliable hosts at $nsites unique sites for PlanetLabs\n";
} 

 


