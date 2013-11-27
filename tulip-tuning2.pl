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
#use strict;
####################################################################
#  Please send comments and/or suggestion to Les Cottrell.
#
# ****************************************************************
# Creater(s): Raja Asad (11/08/13).
# Revision History:
#  1/16/09, improved $USAGE, made use of $debug; Les Cottrell
#  11/29/09, made log analysis on the fly and added -d days option
#  9/18/13, Fixed the script now it works properly and can be used for trscrontab; Raja Asad
# ****************************************************************
#Get some useful variables for general use in code
umask(0002);
#use Sys::Hostname;
#my $ipaddr = gethostbyname(hostname());
use Net::Domain qw(hostname hostfqdn hostdomain);
my $hostname = hostfqdn();
unless(($hostname=~/(([a-z0-9]+|([a-z0-9]+[-]+[a-z0-9]+))[.])+/)){#Name
  print "hostname=$hostname, not a valid IP name\n";
  exit 101;
}
use Socket;
my $ipaddr=inet_ntoa(scalar(gethostbyname($hostname||'localhost')));
#my ($a, $b, $c, $d) = unpack('C4', $ipaddr);
#my ($hostname, $aliases, $addrtype, $length, @addrs) =
#  gethostbyaddr($ipaddr, 2);
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
#my $version="0.2 1/16/09, Qasim Lone & Les Cottrell";
#my $version = "0.3 11/25/09, Les Cottrell & Qasim Lone";
#my $version = "0.4 11/30/09, by Fahad Ahmed Satti";
#my $version = "0.5 5/21/11, by Les Cottrell & Fahad Ahmed Satti";
my $version = "0.6 11/08/13, by Raja Asad & Les Cottrell";
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
   $progname looks at the analysis of the TULIP log that is created
   on the fly by $url&days=days
   going back the number of days given
   in the -d option (default=$days (nb 0 means use all the log)).
   The analysis is saved in $file"."_[enabled|disabled].
   Using this analysis it disables in the tulip database all landmarks that
   have < $threshold% success.
   This script can also, check the nodes that are disabled in the landmarks table,
   against the log file, to see, whether or not, the nodes, have regained the
   ability to be alive again.
  Options:
  \t--help|-h       \tDisplay this help.
  \t--debug|-v      \tSet debug value, to increase or decrease the amount of output.
  \t                \t [default = $debug]
  \t--days|-d       \tSet the number of days to analyze.
  \t                \t [default = $days]
  \t--analyze|-a    \t Set either or one values:
  \t                \t  1|'enabled' to check log file, and disable the enabled nodes.
  \t                \t  0|'disabled' to check database for disabled nodes, and then check the log file, to enable them.
  \t                \t [default = $analyze]
  \t--threshold|t=i \tSet a value for threshold
  \t                \t [default = $threshold]
  \t--log|l         \tSet path for log file
  \t                \t [default = $logFile]
  \t                \t you can also pass 'stdout' to print log data.
Input: 
  Tulip log analysis file created by tulip-log-analyze.pl via web $url
Output:
  The $progname log is written to $logFile
  A copy of the analyzed Tulip log is saved to
  $file"."_[enabled|disabled]
Examples:
   $progname
   $progname --debug 1
   $progname -d 3
   $progname --analyze disabled
   $progname --debug 1 -d 3 -a 0 --threshold 15
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
  . " $progname: started with arguments:\nability=$analyze,debug=$debug,"
  . "days=$days,threshold=$threshold and logFile=$logFile\n";
if ($analyze =~ /enabled/i || $analyze =~ /1/) {
  $url .= "&ability=1";
  if ($debug > 0) {
    $printString .=  localtime()
      . " $progname: starting analysis of $days days of log data for "
      . "enabled nodes "
      . "using $url.\n";
  }
  &analyzeEnabled();
}
elsif ($analyze =~ /disabled/i || $analyze =~ /0/) {
  #$url .= "&ability=0";
  $url .= "&ability=2";#Use the log for both enabled & disabled landmarks 
  if ($debug > 0) {
    $printString .=  localtime()
      . " $progname starting analysis of $days days of log data for disabled nodes "
      . "using $url.\n";
  }
  &analyzeDisabled();
}
if($debug > 0){
  $printString .=  "Script Name - $progname\t Version - $version\n";
}
if($logFile=~/stdout/i){
  print $printString;
}
else{
  open (RLFILE, '<'.$logFile)or die "Can't open RLFILE <$logFile: ".$!;
  my $delLogLine=0;
  my @lines = <RLFILE>;
  for (my $i=0; $i< (scalar(@lines)-1);$i++){
    if($lines[$i] eq ""){
      #delete $lines[$i];
      $lines[$i]="";
      next;
    }
    if($lines[$i]=~/^\-+\d+\-+/){
      my $logBlockTime = $lines[$i];
      $logBlockTime =~ s/^\-+//;#Remove leading --- in front of Linux time
      $logBlockTime =~ s/\-+\s+.*//;
      if($logBlockTime =~ /\d+/){
        if($executeTime - $logBlockTime > $logTimeLimit){
          $delLogLine=1;
          #delete $lines[$i];
          $lines[$i] = "";          
        }
        else{
          last;
        }
      }
      else{
        next;
      }
    }
    elsif($lines[$i] =~ /^__END__$/ && $delLogLine==1){
      #delete $lines[$i];
      $lines[$i] = ""; 
      $delLogLine=0;
    }
    else{
      if($delLogLine==1){
        #delete $lines[$i];
        $lines[$i] = "";
      }
      else{
        next;
      }
    }
  }
  close(RLFILE) or die "Can't close RLFILE <$logFile: $!";
  #$logFile=$logFile."_".$analyze;
  open (WLFILE, ">$logFile") or die "Can't open WLFILE >$logFile: $!";
  my $oldPrintString = join("",@lines);
  print WLFILE "$oldPrintString\n-------".time()."---- ".scalar(localtime())
      . " progname: $0/n for $user on $hostname\n$printString\__END__\n";
  print WLFILE scalar(localtime())
      . " progname: $0 for $user on $hostname\n$printString\__END__\n";
  close (WLFILE) or die "After ".(time()-$t0)."s can't close WLFILE >$logFile: $!"; 
}
if($debug>=0) {
  print "$printString";
  print "Log written to <WLFILE> $logFile\n";
}
exit;
##########################################################
sub analyzeDisabled(){
  ####################################################################
  #Goes through the database to select landmarks that have been disabled
  #then looks at their success rate in the logfile for ability=disabled
  #and enables them if success > $threshold
  my $ua             = LWP::UserAgent->new;
  $ua->timeout( 500 );
  my $match          = 0;
  my $nlandmarks     = 0;
  my $linesProcessed = 0;
  my $foundNodes     = 0;
  my $nodesInDB      = 0;
  my %nremove; $nremove{'PlanetLab'}=0; $nremove{'PingER'}=0;
  my $type="";
  my %ntype;
  #get request to fetch the file and store it with the name of analyzedump:
  my $t0 = time();
  my $response = $ua->get($url, ':content_file' => $file,);
  die "Can't get $url -- ", $response->status_line
    unless $response->is_success;
  die "Page not found, died with response code", $response->content_type
    unless $response->content_type eq 'text/html';
  ###########################################
  my $dt = time() - $t0;
  if ($debug >= 0) {
    my @fstats=stat($file);
    $printString .=  "$progname: downloaded $fstats[7] bytes of "
      . "analyzed data for $days days "
      . "into $file after $dt seconds. It was loaded from $url\n";
  }
  ###########################################
  #Set up database to enable disabled hosts which are active >=$threshold of time.
  my $dbh = DBI->connect($dbi, $db->{user}, $db->{password})
    or die "Could not connect to 'db->{host}': $DBI::errstr";
  my $queryFetchDisabled = "select ipv4Addr,hostname,serviceInterfaceType from landmarks where enabled=\'0\'";
  #   $DisabledRow                   [0],    [1],      [2],                
  my $DisabledNodes = $dbh->prepare($queryFetchDisabled);
  $DisabledNodes->execute();
  ######################################################
  #Looking through the TULIP database for Disabled nodes
  my $nodeMatched = 0;
  my $ncorrupt    = 0;
  my $nunresolved = 0;
  my $ninconsistent=0;
  my $nfound      =0;
  my $nnotfound   = 0;
  my $nunequalip  = 0;
  while (my @DisabledRow = $DisabledNodes->fetchrow_array()) {
    if($DisabledRow[0] eq "133.15.59.1") {
      my $dbug=1;
    }
    $nodesInDB++;
    $ntype{$DisabledRow[2]}++;#PlanetLab, PerfSONAR or PingER
    if($debug>1) {
      print STDERR "Looking for TULIP dB $DisabledRow[2] disabled landmark $DisabledRow[0]($DisabledRow[1]) in analyzed log\n";
    }
    #$file is of the form /afs/slac/package/pinger/tulip/analyzedump_disabled
    #It was created by reflector.cgi?function=analyze&days=1 from /tmp/tulip_log
    # on wanmon.
    open DATAFILE, "< $file" or die "Cannot open file $file: $!\n";
    my @fstats=stat($file);
    $nlandmarks     = 0;
    $linesProcessed = 0;
    ########################################
    # Reading analyzedump file
    while (<DATAFILE>) {
      $linesProcessed++;
      my $line=$_;
      # Starts with line ========Failure types by landmark
      # Landmark,     Success,   100%_loss,connect_fail,    not_sent,     timeout,     refused,      in_use,     no_name,     unknown,    Totals,
      #First we skip forward to the summary table.
      if ($_ =~ m/Landmark,/i and (!$match)) {
        if ($debug >= 1) {
          $printString .=  "Line Matched: found Landmark & match=$match in:\n $_\n";
        }
        $match = 1;
        next;    # Skipping header line
      }
      if ($_ =~ /Executing/i) {
        # $printString .=  "skipping $_\n";
        next;
      }
      if( $_ =~ /<(\/)?[a-z]+>/i){
        next;
      }
      if( $_ =~ /INFO>/){
        next;
      }
      #Needed Records end at  Totals,
      if ($_ =~ m/Landmark/i) {
        $match = 0;
      }
      if ($match) {#We are inside the summary table of the analyzed log
        if ($_ =~ m/Landmarks/i) {
          next;    # Skip   Landmark,     Success,   100%_loss,conn
        }
        #Format of analyze table
        #===============Failure types by landmark =======================
        #                                                Landmark,     Success,   100%_loss,connect_fail,    not_sent,     timeout,     refused,      in_use,     no_name,     unknown,
        #                1.planetlab.iscte.pt_193.136.191.25:3355,       92.5%,        0.0%,        0.6%,        0.0%,        3.4%,        0.0%,        2.9%,        0.0%,        0.6%
        #                        138.96.250.89_138.96.250.89:3355,        0.0%,        0.0%,      100.0%,        0.0%,        0.0%,        0.0%,        0.0%,        0.0%,        0.0%
        my $ip;
        my $hostname_DisabledNode;
        my $hostname_match=0;
        my @data = split(/,/, $_);
        for (my $i=0;$i<2;$i++) {
          if(!defined($data[$i])) {next;}
          $data[$i] =~ s/^\s+//;    #remove leading spaces
          $data[$i] =~ s/\s+$//;    #remove trailing spaces
        }
        $data[0]=~s/^\|//; 			#Remove | at first line
		$data[0]=~s/toolkit//; 		#Remove toolkit in perfsonar urls at first line
        ($hostname_DisabledNode, $ip) =
          split(/_/, $data[0]);  # removing _IPAddr:3335, from hostnames
        #$hostname_DisabledNode=~s/^\|//;
        if($hostname_DisabledNode =~ /pl1.planetlab.ics.tut.ac.jp/i) {
          my $dbug=1;
        }
        if (defined($ip) && $ip !~ /[a-zA-Z]+/i) {
          ($ip, undef)=split(/:/, $ip);     # removing port, from IPAddr
        }
        if($hostname_DisabledNode =~ /$DisabledRow[1]/i || $hostname_DisabledNode =~ /$DisabledRow[0]/i){
          if($hostname_DisabledNode=~/pl1.planetlab.ics.tut.ac.jp/i) {
            my $dbug=1;
          }
          $hostname_match=1;
          if($debug>0){
            $printString .= "Found disabled TULIP landmark $hostname_DisabledNode($DisabledRow[1]) in reflector.cgi log file for Disabled Nodes.\n";
          }
          if (defined($ip) && $ip !~ /[a-zA-Z]+/i) {
            ($ip, undef)=split(/:/, $ip);     # removing port, from IPAddr
          }
          else{
            my $packed_ip = gethostbyname($hostname_DisabledNode);
            if (defined $packed_ip) {
              $ip = inet_ntoa($packed_ip);
            }
            else {
              $nunresolved++;
              #$printString .= "($nunresolved unresolved so far) can't resolve $hostname_DisabledNode, "
              #             .  "found at line $linesProcessed, to a valid "
              #             .  "ip address, skipping this landmark.\n";
              #next;
            }
          }
        }
        $nlandmarks++;
        if($hostname_match==1){
          #if ($ip eq $DisabledRow[0]) {
          my $ipold=$ip;
          #$ip=$DisabledRow[0];
          if (1) {
            $foundNodes++;
            $nodeMatched=1;
            if(!defined($data[1])) {
              print "\$data[1] not defined in ($linesProcessed)$line\n"
                  . " from $file";
              next;
            }
            chop($data[1]);          # Removing % sign
            my $numberOfTimes = $data[9];
            if(!defined($numberOfTimes)) {
              #ncorrupt++;
              $printString .= "($ncorrupt so far) corrupt "
                           .  "line($linesProcessed) "
                           .  "in $file: $line\n";
              next;
            }
            $numberOfTimes =~ s/\d+(\.\d+)?%//;
            $numberOfTimes =~ s/\s+//;
            if ($data[1] !~ /\d+/) {#Make sure the % success is valid.
              next;
            }
            ################################################################################################
            #If the database disabled host has a success rate > threshold in the log then enable it 
            if ($data[1] >= $threshold) {#Candidate above the threshold?
              my $totalrem=&enable_landmark($dbh, $DisabledRow[1]);
              #my $query    = "Update landmarks set enabled = \'1\' where ipv4Addr = \'$DisabledRow[0]\'";
              #my $sth      = $dbh->prepare($query);
              #my $totalrem = $sth->execute()
              #  or die "Could not execute query '$query'";
              if($debug>0) {
                $printString .= "Found and enabled host $DisabledRow[1], "
                             .  "with ip address $DisabledRow[0](actual=$ipold), "
                             .  "with success value of $data[1]% against "
                             .  "threshold of $threshold%, in $numberOfTimes "
                             .  "attempts.\n";
              }
              # If the host
              # /afs/slac/package/pinger/tulip/tuning_log/afs/slac/package/pinger/tulip/tuning_logName 
              # is not consistent with tulip database
              # The log file is big enough to carry the data for  hosts for weeks and
              # in the mean time there might be some hosts which are being disabled by
              # PingER or hosts already deleted by previous run of tulip-tuning.pl.
              # For more see:
              # https://confluence.slac.stanford.edu/display/IEPM/Laundering+Landmarks
              if ($totalrem == 0 && $debug >= 0) {
                $ninconsistent++;
                $printString .=  "($ninconsistent so far) host $ip(actual=$ipold), found at line $linesProcessed, is inconsistent with the tulip database \n";
                last;
              }
              $nremove{$DisabledRow[2]}++;
              $printString .= "Enabled($nremove{$DisabledRow[2]}) $DisabledRow[2] landmark $data[0] "
                           .  "with $data[1]% >= threshold($threshold%)\n";
              last;
            }# end if ($data[1] >= $threshold)
            else {
              if ($debug >=0 && defined($data[1])) {
                $printString .= "For disabled host($nodesInDB) $data[0] of type  $DisabledRow[2], found at line $linesProcessed, success rate of $data[1]% is < threshold($threshold%), in $numberOfTimes attempts\n";
                last;
              }
            }
          }# end if ($ip eq $DisabledRow...
          else{
            $nunequalip++;
            $printString .= "($nunequalip so far) for host $data[0]($nodesInDB) of type  $DisabledRow[2] ip address of $DisabledRow[0] in Tulip database was not equal to the one ($ip), found by resolving.\n";
            $nodeMatched=0;
          }
        }
        else{
          $nodeMatched=0;
        }
        $dt = time() - $t0;
        if ($debug > 1) {
          $printString .=  scalar(localtime())
            . " $progname: found $nlandmarks landmarks in DB. "
            . "Enabled $nremove{'PlanetLab'} PlanetLab landmarks and "
            . "$nremove{'PingER'} PingER landmarks with >=$threshold% success. "
            . "Took $dt seconds\n";
        }
      }    #end match
    }    #end file read
    if($nodeMatched<1){
      $nnotfound++;
      if($debug>=0) {
        $printString .= "($nnotfound so far) host $DisabledRow[1]($DisabledRow[0]) "
          . "of type $DisabledRow[2] from landmarks table was not found, "
          . "in reflector.cgi log for Disabled landmarks\n";
      }
    }
    else {
      $nfound++;
    }
    close DATAFILE or die "Can't close DATAFILE $file: $!";
  }#end disabled nodes from db
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
########################################################################
sub analyzeEnabled(){
  ######################################################
  #Goes through the log file for enabled landmarks and disable 
  #landmarks that have success < $threshold
  my $t0         = time();
  my $ua         = LWP::UserAgent->new;
  $ua->timeout( 500 );
  my $match      = 0;
  my %nremove;   $nremove{'PlanetLab'}=0;    $nremove{'PingER'}=0;	$nremove{'PerfSONAR'}=0;
  my $nlandmarks = 0;
  my $nlost      = 0;
  my %ndisabled; $ndisabled{'PlanetLab'}=0;  $ndisabled{'PingER'}=0;	$ndisabled{'PerfSONAR'}=0;
  my $nline      = 0;
  my $type;
  my %nability; $nability{'PlanetLab'}=0;    $nability{'PingER'}=0;		$nability{'PerfSONAR'}=0;
  ###################################################
  #get request to fetch the file and store it with the name of analyzedump:
  #$file is of form=/afs/slac/package/pinger/tulip/analyzedump_enabled
  my $response = $ua->get($url, ':content_file' => $file,);
  die "Can't get $url -- ", $response->status_line unless $response->is_success;
  die "Page not found, died with response code", $response->content_type
    unless $response->content_type eq 'text/html';
  ###########################################
  my $dt = time() - $t0;
  if ($debug > 0) {
     $printString .= 
      "$progname: successfully downloaded analyzed data for $days days "
      . "into $file after $dt seconds.\n";
  }
  ###########################################
  # Otherwise, process the content somehow:
  open DATAFILE, "< $file" or die "Cannot open file $file: $!\n";
  #Set up database to disable hosts which are active <$threshold of time.
  my $dbh = DBI->connect($dbi, $db->{user}, $db->{password})
    or die "Could not connect to 'db->{host}': $DBI::errstr";
  ############ Reading analyzedump file ##################
  my %type;
  while (<DATAFILE>) {
    $nline++; my $line=$_; chomp($line);
    ######## Skip down to the summary table of successs #####################
    #Starts with line ========Failure types by landmark
    # Landmark,     Success,   100%_loss,connect_fail,    not_sent,     timeout,     refused,      in_use,     no_name,     unknown,    Totals,
    if ($line =~ m/Landmark,/i and (!$match)) {
      if ($debug > 1) {
        $printString .=  "Line Matched: found Landmark & match=$match in:\n $_\n";
      }
      $match = 1;
      next;    # Skipping header line
    }
    #Needed Records ends at  Totals,
    if ($line =~ m/Landmark/i) {
      $match = 0;
    }
    if ($match) {#We have got to the summary table of successes
      if ($line =~ m/Landmarks/i) {
        next;    # Skip   Landmark,     Success,   100%_loss,conn
      }
      #Format of analyze table
      #===============Failure types by landmark =======================
      #                                                Landmark,     Success,   100%_loss,connect_fail,    not_sent,     timeout,     refused,      in_use,     no_name,     unknown,
      #                1.planetlab.iscte.pt_193.136.191.25:3355,       92.5%,        0.0%,        0.6%,        0.0%,        3.4%,        0.0%,        2.9%,        0.0%,        0.6%
      #                        138.96.250.89_138.96.250.89:3355,        0.0%,        0.0%,      100.0%,        0.0%,        0.0%,        0.0%,        0.0%,        0.0%,        0.0%
      $nlandmarks++;
      my @data = split(/,/, $line);
      if(scalar(@data)>=1){
        $data[0] =~ s/^\s+//;    #remove leading spaces
        $data[0] =~ s/\s+$//;    #remove trailing spaces
		
		$data[0] =~ s/\|//;
      }
      if(scalar(@data)>=2){
        $data[1] =~ s/^\s+//;    #remove leading spaces
        $data[1] =~ s/\s+$//;    #remove trailing spaces
      }
      if($data[1] =~ /^\d+/){#Make sure the success token contains a numeral
      }
      else{#
        next;
      }
      if($data[0]=~/206\.117\.37\.7/i){
        my $db=1;
      }
      if($data[0]=~/:3355/) {$type="PlanetLab";}
	  elsif($data[0]=~/toolkit/){$type="PerfSONAR";$data[0] =~ s/toolkit//;}
      else                  {$type="PingER";}  
	  
      my $node_ip="%";
      ($data[0], $node_ip)=split(/_/, $data[0]);#splitting hostname and IPAddr:3335
      if(defined($node_ip)){
        ($node_ip,undef)=split(/:/,$node_ip);#removing :port from hostname
      }
      else{
        $node_ip="%";
      }
      chop($data[1]);          # Removing % sign
      if ($data[1] < $threshold) {
        my $rowCount = $dbh->selectrow_array("SELECT count(*) FROM landmarks where (hostName = \'$data[0]\' or ipv4Addr=\'$data[0]\') and enabled=\'1\'");
        if($rowCount>0) {
          if($debug>0) {
            $printString .= "Found enabled $type host $data[0] with success($data[1]%) < $threshold% "
                         .  "in $line from $file($nline)\n"; 
          }
        }
        else {
          if($debug>0) {
            $printString .= "Can't find un-successful enabled $type host $data[0] "
                         .  "by name in the database.\n query was = ";
            $printString .= "SELECT count(*) FROM landmarks where (hostName = "
                         .  "\'$data[0]\' or ipv4Addr=\'$data[0]\') and enabled=\'1\' \n";
          }
          if($node_ip!~/\%/){#If it has a valid IP address try that
            my $rowCount = $dbh->selectrow_array("SELECT count(*) FROM landmarks where ipv4Addr=\'$node_ip\' and enabled=\'1\'");
            if ($rowCount>0) {
              $printString.="Found ($rowCount) enabled $type IP address = $node_ip "
                          . "with success($data[1]% < $threshold% from ($nline)$line of $file\n";
            }
          }
        }
        if($rowCount>0){#Currently enabled host (also found in DB) is below threshold so disable it
          #my $q_disableHost = "update landmarks set enabled = \'0\' where hostName = \'$data[0]\' or ipv4Addr like \'$node_ip\'";
		  my $q_disableHost = "Update landmarks set enabled = \'0\' where hostName like \'$data[0]\' or ipv4Addr like \'$node_ip\'";
          my $sth           = $dbh->prepare($q_disableHost);
          my $totalrem      = $sth->execute() or die "Could not execute query '$q_disableHost'";
          # If the hostName is not consistent with tulip database
          # The log file is big enough to carry the data for  hosts for weeks and
          # in the mean time there might be some hosts which are being disabled by
          # PingER or hosts already deleted by previous run of tulip-tuning.pl.
          # For more see:
          # https://confluence.slac.stanford.edu/display/IEPM/Laundering+Landmarks
          if ($totalrem == 0) {  
            $nlost++;
            if($debug>=0) {
              $printString .= " ($nlost)can't disable unsuccessful host $data[0]($nline), "
                           .  "with success=$data[1]%(< $threshold%), it's not in tulip DB\n";
            }
          }
          else{
            $nremove{$type}++;
            #$data[9] =~ s/\d+(\.\d+)?%//;
            #$data[9] =~ s/\s+//;
            $printString .= "Disabled($nremove{$type}) $type landmark $data[0] "
                         .  "with success $data[1]% < threshold($threshold%) "
                         .  "using $q_disableHost ";
                        # .  "from (line # $nline)$line\n";
          }#end if scalar(DisabledNodes->fetchrow_array()) > 0
        }#end if-else database update for enabled host
        else {#Enabled host is below threshold but we are unable to Disable it in the DB
          $ndisabled{$type}++;
          $printString.="Can't find enabled $type landmark $data[0] "
                      . "($ndisabled{$type} so far) with "
                      . "success $data[1]% < $threshold% in TULIP DB.\n";
                      #. "From (log line # $nline)$line\n";
        }
      }#end if ($data[1] < $threshold)
      else {#landmark success is >= $threshold, so do not touch, just keep tally
        $nability{$type}++;
        &enable_landmark($dbh, $data[0]);
        $printString .= "Preserved enabled $type landmark $data[0] "
                     .  "($nability{$type} so far) with "
                     .  "success $data[1]% >= $threshold%\n";
                     #.  "line($nline):$line\n"; 
      }
    }#end if ($match)
  }#end while (<DATAFILE>)
  close DATAFILE or warn "Can't close DATAFILE $file: $!";
  $dt = time() - $t0;
  $printString .=  scalar(localtime())
    . " $progname (took $dt secs): read $nline lines from\n"
    . " $url\n"
    . "Found $nlandmarks landmarks in analyzed log for enabled landmarks.\n"
    . "Of these $nability{'PlanetLab'} PlanetLab landmarks & "
    . "$nability{'PingER'} PingER landmarks have success >= $threshold%, "
    . "can't find $ndisabled{'PlanetLab'} PlanetLab and "
    . "$ndisabled{'PingER'} PingER landmarks "
    . "below $threshold% threshold TULIP DB.\n"    
    . "Disabled $nremove{'PlanetLab'} PlanetLab landmarks, $nremove{'PerfSONAR'} PerfSONAR landmarks "
    . "& $nremove{'PingER'} PingER landmarks with <$threshold% success.\n"
    . "See $file for analyzed reflector.cgi log file input and "
    . "$logFile for stanzas of logged output from $progname.\n";     
  if($nlost>0){
    $printString  .= "Can't disable $nlost hosts, they aren't in tulip DB.\n";
  }
} ## end sub analyzeEnabled()

sub get_tulip_pwd{
  #The tulip password is available to group iepm in pinger:/u1/mysql/pws-tulip
  if ($hostname ne "pinger.slac.stanford.edu") {
    die "The Tulip password is only available on pinger\n";
  }
  my $file = "/u1/mysql/pws-tulip";
  unless (-e $file) {
    die "Can't read tulip password file $file: $!";
  }
  my $cmd = "/bin/cat $file";
  my $pwd = `$cmd`;
  if (!defined($pwd) || $pwd eq "") {
    die "Can't read password: $!;";
  }
  chomp $pwd;
  return ($pwd);
} ## end sub get_tulip_pwd
#########################################
#enable_landmark(database_link, landmark)
sub enable_landmark {
  my $query    = "Update landmarks set enabled = \'1\' where hostname = \'$_[1]\'";
  my $sth      = $_[0]->prepare($query);
  my $totalrem = $sth->execute() or die "Could not execute query '$query'";
  return $totalrem;
}
