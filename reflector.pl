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
# Copyright (c) 2009    
# The Board of Trustees of          
# the Leland Stanford Junior University. All Rights Reserved.       
#####################################################################
#The following code is placed at the top to ensure we are able to use perl -d
#and stop things before they call other things.
my $debug; #For cronjobs use -1, for normal execution from command line use 0, 
           #for debugging information use > 0, max value = 3.
if (-t STDOUT) {$debug=0;}
else           {$debug=-1;} #script executed from cronjob
####################################################################
use strict;
#my $version="0.2, 10/13/2010";#Enclosed URL in single quotes ('')
my $version="0.3, 5/21/2011";#Concatenated the enabled and disabled log files
#  ....................................................................
(my $progname = $0) =~ s'^.*/'';#strip path components, if any
my $url="'http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?target=www.slac.stanford.edu";
my $timeout=360;
my $logfn="/tmp/reflector.log";
my $cmd="/usr/bin/wget --no-verbose --tries=1 --timeout=$timeout --quiet ";
my $USAGE = "Usage:\t $progname [opts] 
        Opts:
        -v print this USAGE information
        -D debug_level (default=$debug)
        -u url
Purpose: uses wget:
  $cmd
  to execute:
  $url  
  The wget url command is executed twice, once to use enabled landmarks
  and once to use disabled landmarks. It also concatenates the log files.
  The default timeout is $timeout secs.
Output:
  There are logs at $logfn-enabled, $logfn-disabled and $logfn-all
  Note that though reflector.cgi runs as a web service on wanmon via wget 
  the logs are local to the host running reflector.pl.
Examples:
 $progname
 $progname -v -D 1
Version=$version
";
####################################################################
#  Please send comments and/or suggestion to Les Cottrell.
#
# **************************************************************** 
# Owner(s): Les Cottrell (12/18/09).                                
# Revision History:                                                
# **************************************************************** 
#Get some useful variables for general use in code
umask(0002);
use Sys::Hostname; 
my $ipaddr=gethostbyname(hostname());
my ($a, $b, $c, $d)=unpack('C4',$ipaddr);
my ($hostname,$aliases, $addrtype, $length, @addrs)=gethostbyaddr($ipaddr,2);
use Date::Calc qw(Add_Delta_Days Delta_Days Delta_DHMS);
use Date::Manip qw(ParseDate UnixDate);
use Time::Local;
my $user=scalar(getpwuid($<));
##############################################################
#Process options
require "getopts.pl";
our ($opt_u, $opt_v, $opt_D);
&Getopts('u:D:v');
if($opt_v) {
  print "$USAGE"; 
  exit 1;
}
if(!$opt_u) {
  $opt_u=$url;
}
if($opt_D)  {$debug=$opt_D;}
my $time=localtime();
my $t0=time();
########################################################
#Execute something of the form:
#/usr/bin/wget --no-verbose --tries=1 --timeout=360 --quiet --output-document=/tmp/reflector.log http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?target=www.slac.stanford.edu&
my $log="$logfn-enabled";
my $cmd1="$cmd --output-document=$log $opt_u&debug=$debug'";
my @ans=`$cmd1`;
my $dt;
if ($debug>=0 || scalar(@ans)>0) {
  my @stat=stat($log);
  $dt=time()-$t0;
  print scalar(localtime())." $progname took $dt secs to execute $cmd1, returned $log with $stat[7] Bytes: (".scalar(@ans).")@ans: $!, $?\n";
}
$log="$logfn-disabled";
$cmd1="$cmd --output-document=$log $opt_u&ability=0&debug=$debug'";#takes 35 mins
@ans=`$cmd1`;
if ($debug>=0) {
  my @stat=stat($log);
  $dt=time()-$t0-$dt;
  print scalar(localtime())." $progname took $dt secs to execute $cmd1, returned $log with $stat[7] Bytes: (".scalar(@ans).")@ans: $!, $?\n";
}
#concatenate the two files
$log="$logfn-all";
@ans=`cat $logfn-enabled>$log`;
@ans=`cat $logfn-disabled>>$log`;
if($debug>=0) {
  print scalar(localtime()), " $progname concatenated $logfn-enabled and $log-disabled to create $log\n";
}
$dt=time()-$t0;
if ($debug>=0) {print scalar(localtime())." $progname: took $dt seconds\n";}
exit 0;
__END__
