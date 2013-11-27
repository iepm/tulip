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
# Copyright (c) 2009, 2010, 2011
# The Board of Trustees of
# the Leland Stanford Junior University. All Rights Reserved.
####################################################################
#The following code is placed at the top to ensure we are able to use perl -d
#and stop things before they call other things.
my $debug
  ;  #For cronjobs use -1, for normal execution from command line use 0,
     #for debugging information use > 0, max value = 3.
if (-t STDOUT) { $debug = 0; }
else { $debug = -1; }    #script executed from cronjob
my $t0=time();
use strict;
####################################################################
#  Please send comments and/or suggestion to Raja Asad Khan
#
# ****************************************************************
# Creater(s): Raja Asad (09/25/13).
# Revision History:
#
# ****************************************************************
#Get some useful variables for general use in code
umask(0002);
use Sys::Hostname;
my $ipaddr = gethostbyname(hostname());
my ($a, $b, $c, $d) = unpack('C4', $ipaddr);
my ($hostname, $aliases, $addrtype, $length, @addrs) =
  gethostbyaddr($ipaddr, 2);
use Date::Calc qw(Add_Delta_Days Delta_Days Delta_DHMS);
use Date::Manip qw(ParseDate UnixDate);
use Time::Local;
use LWP 5.64;    # Loads all important LWP classes, and makes
                 #  sure your version is reasonably recent.
use Socket;
(my $progname = $0) =~ s'^.*/'';    #strip path components, if any
my $user        = scalar(getpwuid($<));
my $analyze     = 'enabled';
my $help;
my $threshold   = 20;
my $days        = 3;
my $executeTime = time();
my $logTimeLimit=2592000;    #Keep log for a month
my $dir         = "/afs/slac/package/pinger/tulip/";
my $file        = $dir . "analyzedump";
my $logFile     = $dir . "tuning_log";
my $printString = "";
my $url = "http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=analyze";
my $version = "0.1 9/25/13, by Raja Asad";
##############################################################
use Getopt::Long;
my $ok = GetOptions(
  'debug|v=i'     => \$debug,
  'help|?|h'      => \$help,
  'days|d=i'      => \$days,
  'analyze|a=s'   => \$analyze,
  'threshold|t=i' => \$threshold,
  'log|l=s'       => \$logFile,
  );
if ($help) {
  my $USAGE="Usage: $0 options\n
  Purpose:
   $progname looks at the tulip database and disables landmarks that
   have the same geographic location such that only one is enabled at any time.
   
  Options:
  \t--help|-h       \tDisplay this help.
  \t--debug|-v      \tSet debug value, to increase or decrease the amount of output.
  \t                \t [default = $debug]

Version=$version
";
  print $USAGE;
  exit 1;
} ## end if ($help)
###########################################################
#Set up TULIP database access
use DBI;
our $db = {
  'user'  => 'scs_tulip_u',
  'host'  => 'mysql-node01',
  'port'  => '3307',
  'dbname'=> 'scs_tulip',
};
my $pwd;
my $dbi;
require "/afs/slac/g/scs/net/pinger/bin/admin.pl";
our $pwd = &gtpwd('tulip');
$db->{'password'} = $pwd;
$dbi              =
    'DBI:mysql:mysql_socket=/var/lib/mysql/mysql.sock;host='
  . $db->{host}
  . ';port='
  . $db->{port}
  . ';database='
  . $db->{dbname};
######################################################
if (!defined($days) || $days < 0) {
  $days = 0;
}
#Get name to make a copy of the log file used as input by this script
$file=$file."_".$analyze;#e.g. /afs/slac/package/pinger/tulip/analyzedump_disabled
$url .= "&days=$days";
$printString .= localtime()
  . " $progname: started ";

if($debug > 0){
  $printString .=  "Script Name - $progname\t Version - $version\n";
}
&RemoveDuplicate();
if($debug>=0) {
  #print "$printString";
}
exit;
##########################################################
sub RemoveDuplicate(){
  ####################################################################
  #Goes through the database to select landmarks that are enabled
  #then looks at their lat lon
  #and disables others with same lat lon
  my $ua             = LWP::UserAgent->new;
  $ua->timeout( 500 );
  my $match          = 0;
  my $nlandmarks     = 0;
  my $linesProcessed = 0;
  my $foundNodes     = 0;
  my $nodesInDB      = 0;
  my %nremove; $nremove{'PlanetLab'}=0; $nremove{'PingER'}=0;$nremove{'PerfSONAR'}=0;
  my $type="";
  my %ntype;
  #get request to fetch the file and store it with the name of analyzedump:
  my $t0 = time();
  #my $response = $ua->get($url, ':content_file' => $file,);
  #die "Can't get $url -- ", $response->status_line
  #  unless $response->is_success;
  #die "Page not found, died with response code", $response->content_type
  #  unless $response->content_type eq 'text/html';
  ###########################################
  my $dt = time() - $t0;
  #if ($debug >= 0) {
  #  my @fstats=stat($file);
  #  $printString .=  "$progname: downloaded $fstats[7] bytes of "
  #    . "analyzed data for $days days "
  #    . "into $file after $dt seconds. It was loaded from $url\n";
  #}
  ###########################################
  #Set up database 
  my $dbh = DBI->connect($dbi, $db->{user}, $db->{password})
    or die "Could not connect to 'db->{host}': $DBI::errstr";
  my $queryFetchEnabled = "select ipv4Addr,hostname,serviceInterfaceType,latitude,longitude from landmarks where enabled=\'1\'";
  #   $DisabledRow                   [0],    [1],      [2],                
  my $EnabledNodes = $dbh->prepare($queryFetchEnabled);
  $EnabledNodes->execute();
  ######################################################
  #Looking through the TULIP database for Enabled nodes
  my $nodeMatched = 0;
  my $ncorrupt    = 0;
  my $nunresolved = 0;
  my $ninconsistent=0;
  my $nfound      =0;
  my $nnotfound   = 0;
  my $nunequalip  = 0;
  while (my @EnabledRow = $EnabledNodes->fetchrow_array()) {
    #if($DisabledRow[0] eq "133.15.59.1") {
    #  my $dbug=1;
    #}
    $nodesInDB++;
    $ntype{$EnabledRow[2]}++;#PlanetLab, PerfSONAR or PingER
    #if($debug>1) {
    #  print STDERR "Looking at TULIP dB $EnabledRow[2] Enabled landmark $EnabledRow[0]($EnabledRow[1])\n";
    #}
	my $lati=int($EnabledRow[3]*100)/100;
	my $longi=int($EnabledRow[4]*100)/100;
	my $queryFetchDuplicate = "select ipv4Addr,hostname,serviceInterfaceType from landmarks where (enabled=\'1\' and latitude like \'$lati%\' and longitude like \'$longi%\');";
	#print $queryFetchDuplicate."\n";
    #my $queryFetchDuplicate = "select ipv4Addr,hostname,serviceInterfaceType from landmarks where (enabled=\'1\' and latitude like \'$EnabledRow[3]\' and longitude like \'$EnabledRow[4]\')";
	my $DupNodes = $dbh->prepare($queryFetchDuplicate);
	$DupNodes->execute();
	
    $nlandmarks     = 0;
    $linesProcessed = 0;
    ########################################
    # Reading analyzedump file
    while (my @DupRow = $DupNodes->fetchrow_array()) {
      
	  if ($linesProcessed>0)
	  {
		
		#print "@DupRow\n"; 
		$nfound++;
		my $queryDisable = "update landmarks SET enabled=\'0\' where (ipv4Addr like \'$DupRow[0]\')";
		#print $queryDisable."\n";
		my $RemoveNodes = $dbh->prepare($queryDisable);
		$RemoveNodes->execute();
		$RemoveNodes->finish;
      }
	  $linesProcessed++;
    }
    $DupNodes->finish;
  }#end disabled nodes from db
  #print "$nfound";
  $printString .="Pinger_landmarks=$ntype{'PingER'}, "
               . "PlanetLab_landmarks=$ntype{'PlanetLab'}, "
               . "Disabled_DB_landmarks=$nodesInDB\n" 
               . "Found_landmarks=$foundNodes in log "
               . "that have already been disabled in the DB.\n"
               . "Matched $nodeMatched landmarks, $ncorrupt log entries, "
               . "can't resolve IP address for $nunresolved landmarks, "
               . "$ninconsistent inconsistent landmarks, "
               . "$nunequalip uneqal IP addresses, "
               . "$nfound found in reflector.cgi log, "
               . "$nnotfound not found landmarks in reflector.cgi log by "
               . "/afs/slac/package/pinger/tulip/tulip-tuning.pl -d 1 -a disabled.\n" 
               . "PlanetLab_landmarks_enabled=$nremove{'PlanetLab'}, "
               . "PingER_landmarks_enabled=$nremove{'PingER'}, "
               . "Threshold=$threshold%\n";
}#end sub analyzeDisabled

