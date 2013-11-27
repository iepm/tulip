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
use DBI;
use strict;
my $version="0.1, 5/13/07";
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
# Owner(s): Les Cottrell (7/13/04).                                
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

#use Net::DNS::RR;

##############################################################
#Process options
require "getopts.pl";
our ($opt_f, $opt_c, $opt_v, $opt_D)=("", "", "", "");
&Getopts('f:c:D:v');

if($opt_v) {
  print "$USAGE"; 
  exit 1;
}
if(!$opt_f) {$opt_f="/afs/slac/package/pinger/tulip/Results.txt";}
if($opt_D)  {$debug=$opt_D;}
my $time=localtime();
my $t0=time();
print "$progname: $time=$t0\n";
#config db
our $db = {
                'user' => 'tulip',
                'host'  => 'pinger.slac.stanford.edu',
                'password' => 'fl0wErz3',
                'port' => '1000',
                'dbname' => 'tulip',
        };
#connect
my $dbi = 'DBI:mysql:host=' . $db->{host} . ';port=' . $db->{port} . ';database=' . $db->{dbname};
my $dbh = DBI->connect($dbi, $db->{user}, $db->{password} )
        or die "Could not connect to 'db->{host}': $DBI::errstr";



open (FILE, "$opt_f") || die "Can't open '$opt_f': $!\n";
while( <FILE> ) {
 chomp($_);
 my ( $ipv4Name_f,$ipv4Addr_f, $ipv4Name_t, $ipv4Addr_t, $rtt, $dist ) = split(/ \t/);
 my @records =  split(/\t+/);
 my $query = "Insert into rttCalc values (\'$records[1]\',\'$records[3]\',\'$records[4]\',\'$records[5]\')";    
 print "$query\n";
 my $sth = $dbh->prepare( $query );
 $sth->execute() or die "Could not execute query '$query'";

}
my $dt=time()-$t0;
print scalar(localtime())." $progname: too $dt seconds\n";
__END__
