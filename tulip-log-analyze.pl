#!/usr/local/bin/perl -wT
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
# Copyright (c) 2007, 2008, 2009, 2010    
# The Board of Trustees of          
# the Leland Stanford Junior University. All Rights Reserved.       
#############################################################################
#The following code is placed at the top to ensure we are able to use perl -d
#and stop things before they call other things.
my $debug; #For cronjobs use -1, for normal execution from command line use 0, 
           #for debugging information use > 0, max value = 3.
if (-t STDOUT) {$debug=0;}
else           {$debug=-1;} #script executed from cronjob
##################Usage information################################
use strict;
#my $version="0.2, 5/27/08, Cottrell";
my $version="0.3, 7/17/2010, Cottrell";#Fixed /gui/ types landmarks
my $infile="/tmp/tulip_log";
my $ability=1;
(my $progname = $0) =~ s'^.*/'';#strip path components, if any
my $USAGE = "Usage:\t $progname [opts] 
        Opts:
        -v print this USAGE information
        -d # days to go back into log (default = 0 = all days in log)
        -D debug_level (default=$debug)
        -f filename    (default=$infile)
        -a ability     (default=$ability=1}
Purpose:
  Analyzes Tulip log, default=$infile, may be over-ridden with -f option.
  The analysis looks at the log files going back -d days. If the ability
  is specified as disabled (-a 0) then only log records with ability=0
  are selected for analysis. 
  Similarly if ability is not specified or
  specified as 0 (enabled) then disabled records are not included in the 
  analysis.
  If the ability is specified as 2 (all) then both enabled and disabled
  records are included in the analysis.
Input:
  file (default=$infile)
Examples:
 $progname
 $progname -v -D 1
 $progname -f /scratch/tulip_log
 $progname -a 0 -d 3
Version=$version
";
########################################################################
#  Please send comments and/or suggestion to Les Cottrell.
#
# **************************************************************** 
# Owner(s): Les Cottrell (7/13/08).                                
# Revision History:                                                
# **************************************************************** 
#Get some useful variables for general use in code
umask(0002);
use Sys::Hostname; 
use Socket;
my $ipaddr=gethostbyname(hostname());
my ($hostname,$aliases, $addrtype, $length, @addrs)=gethostbyaddr($ipaddr,2);
use Date::Calc qw(Add_Delta_Days Delta_Days Delta_DHMS);
use Date::Manip qw(ParseDate UnixDate);
use Time::Local;
my $user=scalar(getpwuid($<));
my $flag = 1; # This would help in ignoring the values for on_connect 
my %delayAnalysis = ();  # A hash which would contain the list of delays
#######################Get and process options#######################
require "getopts.pl";
our ($opt_a, $opt_f, $opt_d, $opt_v, $opt_D);
#$opt_d=0; #Default analyze all the log
&Getopts('va:f:D:d:');
if($opt_v) {
  print "$USAGE"; 
  exit 1;
}
if(!defined($opt_d))                     {$opt_d=0;}
if(defined($opt_a) && $opt_d!=0)         {$ability=$opt_a;}
if(!$opt_f)                              {$opt_f=$infile;}
my $epoch0=0;
if(defined($opt_d) && $opt_d!=0)         {$epoch0=time()-$opt_d*24*3600;}
else {
  $opt_d=0;
  $epoch0=0;
}
if( $opt_D)         {$debug=$opt_D;}

######Timing######################################################
my %start = ();#A hash of hash containing start time for landmark request
my %finish= ();
my %delay = ();#Time taken for given landmark and request number
my $time=localtime();
my $t0=time();
my $dir="/tmp/";
if($dir=~/(\/tmp\/)/) {$dir=$1;}
else {
  print "$0 unable to Untaint $dir on $hostname\n";
  exit 100;
}
if(! (-e $opt_f)) {
  print "$0 can't find log file $opt_f on $hostname: $!\n";
  exit 101; 
}
my @stats=stat($opt_f);
if($stats[7]<=0) {
  my $badhost="";
  if($hostname ne "www-wanmon.slac.stanford.edu") {
    $badhost=" (you may want to run on www-wanmon.slac.stanford.edu)";
  }
  print "$0 file $opt_f has length <= 0 runnning on $hostname$badhost\n";  
  exit 102;
}
print scalar(localtime($t0))
    . " $progname: analyzing (on $hostname for $user with debug=$debug) "
    . "$stats[7] Bytes (-d $opt_d = $epoch0, now="
    . time().") "
    . "from $opt_f ability=$ability, last written "
    . scalar(localtime($stats[9]))."\n";
open(STDERR, '>&STDOUT');# Redirect stderr onto stdout
#############################################################
my %reasons; my %types; my %landmarks;
my %cache;
my $nl=0;
my $nanalyzed=0;
my @errors=("Success", "100%_loss", "connect_fail", "not_sent", "timeout", "refused", "in_use",
            "no_name", "unknown",
           );#heading labels
my $requests=0;
my $tulip_request=0;
my $landmark;
my $nlandmark=0;
my $client_name;
my $target_name;
my %tgt_unreach;
my %tgt_reach;
my $Landmarks=0;
open(IN,'<',"$opt_f") or die "Can't open log file IN<$opt_f: $!";
my %projects;
LINE:
while (<IN>) {#Analyse next log file line
  my $line=$_;
  $nl++; 
  chomp $line;
  if($line eq "") {next;}
  if($line!~/^2/) {next;} #Skip if not this millenium
  if($ability==1) {
    if($line=~/ability=0/)     {next LINE;}
  }
  elsif($ability==0) {
    unless($line=~/ability=0/) {next LINE;}
  }
  ########Get client information from lines of form#######
  #2007/09/05 11:41:20 ERROR> reflector.cgi:135 main:: - Reflector.cgi starting for client=134.79.117.20
  #or
  #2010/06/10 02:38:46 INFO> EventHandler.pm:69 EventHandler::on_connect - Landmark(0)=http://129.237.161.193:3355/cgi-bin/srrubycgi?target=115.186.131.79, , ability=1,script=...
  #or
  #2010/06/10 02:43:17 INFO> EventHandler.pm:69 EventHandler::on_connect - Landmark(0)=https://146.83.188.16/gui/reverse_traceroute.cgi?target=115.186.131.79&function=ping?, ability=1,script=...
  #or
  #2010/06/10 02:43:19 INFO> EventHandler.pm:69 EventHandler::on_connect - Landmark(0)=http://adl-a-ext1.aarnet.net.au/cgi-bin/traceroute.pl?target=115.186.131.79&function=ping?, ability=1,script=...
  #or
  #2010/07/07 00:40:01 INFO> reflector.cgi:550 main:: - Reflector.cgi -- Executing Landmark(-1) for Server=143.225.229.236 City ..
  #2008/08/11 20:19:47 INFO> reflector.cgi:281 main:: - reflector.cgi: processed http://www.slac.stanford.edu/comp/net/wan-mon/tulip/sites.xml(239), client=134.79.240.30, target=140.105.28.117, region=all, tier=all, type=PlanetLab,landmarks=239, PL=194, SLAC=45, parallel=20, duration=306 secs
  my @tokens=split(/\s+/,$line);
  my ($year, $month, $mday)    = split(/\//,$tokens[0]);
  my ($hour, $minute, $second) = split(/:/, $tokens[1]);
  $year=$year-1900; 
  $month=$month-1;
  my $epoch=timelocal($second,$minute,$hour,$mday,$month,$year);
  unless($epoch>$epoch0) {#skip older lines
    if($debug>=1) {
      print "Skipping ($epoch<$epoch0) line($nl): $line\n";
    }
    #Note the	 log is not necessarily in chronological order
    #since it may a concatenation of enabled and disabled logs
    #so we must keep going.
    next LINE;
  }
  if($line=~/starting for client/) {$tulip_request++; $nlandmark=0;}
  if($line=~/Executing/)           {$nlandmark++;}
  if($line=~/Reflector/  || $line=~/processed/) {
    $client_name="unk";
    $target_name="unk";
    if($line=~/client=(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
      $client_name=get_name($1);
      if($client_name eq "unk") {
        $client_name=$1;
        print "Can't find client name for $1\n";
      }
    }
    if($line=~/target=(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
      $target_name=get_name($1);
      if($target_name eq "unk") {
        $target_name=$1;
        print "Can't find target name for $1\n";
      }
    }
    if($line=~/Reflector/) {$requests++;;}
    if($debug>=-1) {print "(record=$requests/landmark=$nlandmark/request=$tulip_request):$line\n";}
    next;
  }
  ###############Typical data line  appears as:##########
  #2007/09/03 18:00:47 ERROR> EventHandler.pm:141 EventHandler::parseData - Landmark(1)=http://152.14.92.58, Client=134.79.117.29, 10 packets transmitted, 0 received, 100% packet loss, rtt min/avg/max = 0/0/0:
  @tokens=split(/\s+/,$line);
  if(!defined($tokens[6]) || $tokens[6] eq "") {next;}
  #####Get landmark information#########################
  my $landmark_addr=$tokens[6];
  if($landmark_addr!~/Landmark\(\d+\)=/) {next;}
  $landmark_addr=~s/Landmark\(\d+\)=http(s)?:\/\///;#Strip off leding stuiff before the IP addr/name
  ######Stripping off :3355/cgi-bin for PlanetLab landmarks###
  my $port="";
  my $project="unk";
  if($landmark_addr =~/:3355/){
    $port=":3355";
    ($landmark_addr,undef) = split(/:3355/,$landmark_addr);
    $project="PlanetLab";
  }
  ###########Getting rid off cgi-bin or cgi-ping etc.. from Pinger hosts or /gui/ from other hosts##
  elsif($landmark_addr =~/\/gui\//) {
    ($landmark_addr,undef)=split(/\/gui\//,$landmark_addr);
    $project="PerfSONAR";
  }
  elsif($landmark_addr =~ /traceroute.pl/) {
    ($landmark_addr,undef) = 
       split(/\/cgi-\w+\/(nph-)?traceroute.pl/,$landmark_addr);
    $project="PingER";
  }
  ######################################################### 
  $landmark_addr=~s/,//;
  $landmark_addr=~s/\///;  
  #if($landmark_addr =~ /wanmon\.slac/i)
  #  {
  #      print $landmark."\n";
  #  }
  if($landmark_addr=~/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {
    $landmark=get_name($landmark_addr);
    if($landmark eq "unk"){
      if($debug>1){   
        print "Can't find landmark name for $landmark_addr\n";
      }
      $landmark="$landmark_addr"."_"."$landmark_addr$port";
    }
    else {
      $landmark.="_$landmark_addr$port"; 
      #$landmark="$landmark_addr"."_"."$landmark$port";#switch name and addr
    }
  }
  elsif($landmark_addr=~/^((\w+|\.+|-)+)/) {
    $landmark=$1;
  }    
  else {
    print "Unable to parse landmark $landmark($landmark_addr) in $tokens[6] in $line\n";
    next;
  }
  $nanalyzed++;
  ###########Checking for the delay#########################
  ###########Get the connect time###########################
  #EventHandler::on_connect - Connecting to http://x.y.z.a    
  #2010/09/17 16:26:33 INFO> EventHandler.pm:69 EventHandler::on_connect - Landmark(0)=https://66.117.203.141/gui/reverse_traceroute.cgi?target=134.79.18.188&function=ping?, ability=1,script=...
  if($line=~/on_connect/) {
     if($debug>1) {
       print "Connecting $landmark request=$target_name($requests) "
           . "from: $line\n";
     }
     my @times=split(/\s+/,$line);
     if(!defined($target_name)) {
       if($line=~/target=(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})&function=/) {
         $target_name=$1;
       }
     }
     $start{$landmark}{"$target_name, $requests"}= "$times[0] $times[1]"; 
     my $dbug=1;
  }
  ####Next get the response time###########################
  if($line=~/parseData/ || $line=~/on_return/ || $line=~/on_failure/) {
    my @times=split(/\s+/,$line);
    if(!defined($target_name)) {
      print "Target not defined for finish($landmark)(? $requests)=$times[0] $times[1]\n";
    }
    else {
      $finish{$landmark}{"$target_name, $requests"}= "$times[0] $times[1]";
      if(defined($start{$landmark}{"$target_name, $requests"})) {
        $delay{$landmark}{"$target_name, $requests"} =
          "$times[1]-".$start{$landmark}{"$target_name, $requests"};
        if($debug>0) {
          print "delay($landmark)($target_name, $requests)="
              . $delay{$landmark}{"$target_name, $requests"}."\n";
        }
      }
      else {
        if($debug>0) {
          print "No startime for $landmark target=$target_name request=$requests\n";
        }
      } 
    }
  }

  ############Categorize errors############################
  my $client=$tokens[7];
  $client=~s/,//;
  if($client eq  "") {$client="unk";}
  my $error="";
  if($line =~ /on_connect/) {$flag = 0; $tgt_reach{$target_name}++;}
  elsif($line =~/100%/) {$error="100%_loss";}
  elsif($line=~/% packet/)          {$error="Success";}
  elsif($line=~/failed to connect/) {$error="connect_fail";} 
  elsif($line=~/didn't see/)        {$error="not_sent";}
  elsif($line=~/timed out/ 
     || $line=~/Request Timeout/)   {$error="timeout";}
  elsif($line=~/refused/)           {$error="refused";}
  elsif($line=~/already/)           {$error="in_use";}
  elsif($line=~/resolve/)           {$error="no_name";}
#  elsif($line=~/exceeded in-transit/) {$error="transit_exc";}
  else                              {
    $error="unknown";
    if($line=~/unreachable/) {$tgt_unreach{$target_name}++;}
    else {
      print "UNKNOWN error for landmark=$landmark, client=$client, target=$target_name. Analyzing log line($nl):"
                     . "$line\n";
    }
  }
  if ($flag){
    $reasons{"$error,$landmark,$landmark_addr"}++;
    $types{"$error"}++;
    $landmarks{$landmark}=$landmark_addr;
    $projects{$landmark}=$project;
    if($landmark =~ /Landmark/) {
      my $dbug=1;
      $Landmarks++;
      print "__Invalid landmark: $landmark/$landmark_addr($Landmarks/$nl)=$line\n;"
    }
  }
  $flag = 1;
}

my %failinghosts; my %success; my %fail;
foreach my $key (sort keys %reasons) {
  my @tokens=split(/,/,$key);
#  print "$key=$reasons{$key}\n";
  $failinghosts{$tokens[0]}++;
  if($tokens[0] eq "Success") {$success{$tokens[1]}++;}
  else                        {$fail{$tokens[1]}++;}
}
foreach my $key (sort keys %types) {
#  print "$key=$types{$key}\n";
}
#print "===============Number of landmarks for failure pattern ========\n";
#foreach my $key (sort keys %failinghosts) {
#  print "$key had $failinghosts{$key} landmarks\n";
#}
#print "===============How landmarks fared (Successes) ================\n";
my $successes=0;
foreach my $key (sort keys %success) {
  $successes++;
#  print "Successes ($successes)for $key $success{$key} times\n";
}
#print "===============How landmarks fared (Failures) =================\n";
my $failures=0;
foreach my $key (sort keys %fail) {
  $failures++;
#  print "Failures ($failures) for $key $fail{$key} times\n";
}
print "===============Failure types by landmark =======================\n";
my @sum=(); 
for (my $i=0; $i<9; $i++) {$sum[$i]=0; }
my $gtotal=0;
my @count=();
for (my $i=0; $i<9; $i++) {$count[$i]=0; }
my $ctotal=0;
#print heading
printf "%58s,%12s,%12s,%12s,%12s,%12s,%12s,%12s,%12s,%12s,%12s",
       "|Landmark",
       $errors[0], $errors[1], $errors[2], $errors[3], $errors[4],
       $errors[5], $errors[6], $errors[7], $errors[8], "Totals,\n";
my $planetlabs=0; my $plsuccess=0;
my $slacs=0;      my $slsuccess=0;
my %good;
foreach my $key (sort keys %landmarks) {
  if($key=~/Landmark/) {
    my $dbug=1;
    next;
  }
  #Not clear why there is a | in front of $key, it appears deliberate 
  #Won't reomove since something may depend on it.
  #It did cause problems in tuning_log.pl which I bypassed (Les 8/5/2012)
  printf "%58s","|$key";
  if($key=~/_/) {$planetlabs++;}
  else          {$slacs++;}
  my $i=0;
  my $total=0;
  foreach my $error (@errors) {
    if(!defined($reasons{"$error,$key,$landmarks{$key}"})) {
      $reasons{"$error,$key,$landmarks{$key}"}=0;
    }
    $total+=$reasons{"$error,$key,$landmarks{$key}"};
    $sum[$i]+=$reasons{"$error,$key,$landmarks{$key}"};
    $i++;
    $gtotal+=$reasons{"$error,$key,$landmarks{$key}"};
  }
  if($total<=0) {$total=1;}    
  my $percent=100*$reasons{"$errors[0],$key,$landmarks{$key}"}/$total;
  $good{$key}=sprintf("%6.2f",$percent);
  if($percent==100) {
    if($key=~/_\d+\./) {$plsuccess++;}
    else               {$slsuccess++;}
  }
  $i=0;
  foreach my $error (@errors) {
    $percent=100*$reasons{"$error,$key,$landmarks{$key}"}/$total;
    printf "%3s%9.1f%1s",",  ",$percent,"%";
    if($percent>0) {
      $count[$i]++;
      $ctotal++;
    }
    $i++;
  }
  printf "%11d,", $total; 
  print "\n";    
}
printf "%58s,%12s,%12s,%12s,%12s,%12s,%12s,%12s,%12s,%12s,%12s",
       "Landmark",
       $errors[0], $errors[1], $errors[2], $errors[3], $errors[4],
       $errors[5], $errors[6], $errors[7], $errors[8], "Totals,\n";

printf "%58s,%12d,%12d,%12d,%12d,%12d,%12d,%12d,%12d,%12d,%11d",
       "Totals",
       $sum[0], $sum[1], $sum[2], $sum[3], $sum[4],
       $sum[5], $sum[6], $sum[7], $sum[8], $gtotal,"\n";
print "\n";
printf "%58s,%12d,%12d,%12d,%12d,%12d,%12d,%12d,%12d,%12d,%11d",
       "Counts > 0%",
       $count[0], $count[1], $count[2], $count[3], $count[4],
       $count[5], $count[6], $count[7], $count[8], $ctotal,"\n";

##################################################################
# Printing out information about the RTT   #######################
##################################################################
foreach $landmark(sort keys %delay) { 
  for my $request (sort keys %{$delay{$landmark}}) {                                                                                                                                 
    my $startEpoch = get_epoch($start{$landmark}{$request});
    my $endEpoch = get_epoch($finish{$landmark}{$request});
    my $delayTime = $endEpoch-$startEpoch ;
    push @{ $delayAnalysis{$landmark} }, $delayTime;
    if($debug >1)
    {
      my $msg="$landmark($request): $start{$landmark}{$request} - $finish{$landmark}{$request} - delay:$delayTime"; 
      print "$msg\n";
    }  
  }                        
}
close(IN) or die "Can't close IN $opt_f: $!";
###########Printing all the values from the hash####
my ($delays,$i);
print "\n";
for $delays ( keys %delayAnalysis ) {
    my $count=scalar(@{$delayAnalysis{$delays}});
    print "$delays($count),$projects{$delays},";
    my $min=9999999999999; 
    my $max=0;
    my $avg=0;
    for $i (0 .. $#{$delayAnalysis{$delays}}) {
       my $y=$delayAnalysis{$delays}[$i];
       if($y<$min) {$min=$y;}
       if($y>$max) {$max=$y;} 
       if($debug>0){print "$delayAnalysis{$delays}[$i],";}
       $avg+=$y;
    }
    if($count<=0) {$count=1;}
    $avg=sprintf "%6.2f",$avg/$count;
    print "success=$good{$delays}\%,min=$min,max=$max,avg=$avg\n";
}
$i=0;
foreach my $key(sort keys %tgt_unreach) {
  $i++;
  if(!exists $tgt_reach{$key}){
    $tgt_reach{$key}=0;
  }
  print "Target($i)=$key unreachable $tgt_unreach{$key} times, reached=$tgt_reach{$key} times\n";
} 
print "Number of targets=".scalar(keys %tgt_reach)."\n";
####################################################
my $dt=time()-$t0;
print "\n".scalar(localtime())." $progname: took $dt seconds "
    . "to analyze $nl ability=$ability records for $requests requests."
    . " Successful hosts=$successes, Failing hosts=$failures, "
    . "PlanetLabs=$planetlabs(100\% success=$plsuccess), "
    . "SLACs=$slacs(100\% success=$slsuccess).\n"
    . "Log read from $nl records file $opt_f & analyzed "
    . "$nanalyzed ability=$ability records\n";
exit 0;

###########################################################
sub get_name {
  #Given the IP address it gets the name of the landmark
  #Uses gethostbyaddr unless the name is already cached.
  #Example: $name=get_name('134.79.16.9')
  my $srcaddr=$_[0];
  ($srcaddr,undef)=split(/:/,$srcaddr);
  if(defined($cache{$srcaddr}) && $cache{$srcaddr} ne "") {
    return $cache{$srcaddr};
  } 
  my $ipaddr=inet_aton($srcaddr);#Convert IP dot adddress to network address
  my $srcname="";
  if(!defined($ipaddr) || $ipaddr eq "") {
    print "Can't get packed ipaddr from inet_aton($srcaddr) for $srcaddr\n";
    $srcname="unk";
  }
  else {$srcname=gethostbyaddr($ipaddr,AF_INET);}
  if(!defined($srcname) || ($srcname eq "")) {
#    print "Can't find name for $srcaddr in $srcaddr\n";
    $srcname="unk";
  }
  $cache{$srcaddr}=$srcname;
  return $srcname;
}

###################################################
##Given the yyyy/mm/dd hh:mm:ss it returns the Unix epoch time
sub get_epoch{
  my $localTime = shift;
  my($date, $time) = split(/\s+/,$localTime);
  #removing spaces 
  $date =~ s/\s+//g;
  $time =~ s/\s+//g;
  my($year,$month,$day) = split(/\//,$date);  
  $month=$month-1;
  my($hours,$min,$sec) = split(/:/,$time);
  $time = timelocal($sec,$min,$hours,$day,$month,$year); 
  return $time;
}
__END__
