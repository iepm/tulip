#!/usr/local/bin/perl -wT
#--------------------------------------------------------------#
#                                                              #
#                      DISCLAIMER NOTICE                       #
#                                                              #
# This  document  and/or portions  of  the  material and  data #
# furnished herewith,  was developed under sponsorship  of the #
# U.S.  Government.  Neither the  U.S. nor the U.S.D.O.E., nor #
# the Leland Stanford Junior  University, nor their employees, #
# nor their  respective contractors, subcontractors,  or their #
# employees,  makes  any  warranty,  express  or  implied,  or #
# assumes  any  liability   or  responsibility  for  accuracy, #
# completeness  or usefulness  of any  information, apparatus, #
# product  or process  disclosed, or  represents that  its use #
# will not  infringe privately-owned  rights.  Mention  of any #
# product, its manufacturer, or suppliers shall not, nor is it #
# intended to, imply approval, disapproval, or fitness for any #
# particular use.   The U.S. and  the University at  all times #
# retain the right to use and disseminate same for any purpose #
# whatsoever.                                                  #
#--------------------------------------------------------------#
#Copyright (c) 2007, 2008, 2009, 2010, 2011
#  The Board of Trustees of the Leland
#  Stanford Junior University. All Rights Reserved..
#----------------------------------------------------------------
###################Debugging###############################
#$debug = -1 gives the minimum needed by TULIP
#$debug =  0 gives a normal minimum human readable output
#$debug =  1 gives status progress messages
#$debug =  2 gives heavy debugging
#The following code is placed at the top to ensure we are able to use perl -d
#and stop things before they call other things.
my $debug; #For cronjobs use -1, for normal execution from command line use 0,
           #for debugging information use > 0, max value = 3.
if (-t STDOUT) {$debug=0;}
else           {$debug=-1;} #script executed from cronjob
#$debug=2;
##############Security####################################
use strict;
$|=1; #Unbuffer output
$ENV{PATH} = '/usr/local/bin:/bin:/usr/bin';#Untaint the path
#Reduce the ENV variable so that the system command should not complain 
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'}; 
#############Web stuff#################################
if($debug>-2){
  print "Content-type: text/html\n\n<html>\n<head>\n";
  #print "<title>Hello</title></head><body>\nHello, debug=$debug<br>\n";
}
use XML::LibXML;
my $xmldir = "http://www.slac.stanford.edu/comp/net/wan-mon/tulip";
my $xmlfile= "$xmldir/sites.xml";#Default for $ability=1 
#open(STDERR, '>&STDOUT');# Redirect stderr onto stdout
########################Documentation#################################
#my $version="1.5, Cottrell 9/21/08";
#my $version="1.6, Cottrell 11/28/09";
#my $version="1.7, Cottrell 12/12/09";
# Added version to output, & ability & log to parameters
#my $version="1.8, Fahad & Cottrell 12/30/09";
# Added TULIP landmarks DB function
#my $version="1.9, Cottrell & Fahad 7/24/10";
# Added landmark parameter & PerfSONAR landmarks
#my $version="2.1, Cottrell & Faisal 8/31/10";
# Added logic to handle PerfSONAR nodes
#my $version="2.2, Cottrell & Zafar 9/4/10";
# Added logic to handle tsv format
#my $version="2.3, Cottrell & Zafar 12/27/10";
#Enable setting of debug=-2 to remove extraneous INFO tulip-log-analyze.pl 
#output.
#Removed STDERR output since it was being scrambled with STDOUT
#Enable landmark parameter to be a comma separated list
#my $version="2.4, Cottrell & Faisal 5/13/2011";
#Fixed up the cookie.
#my $version="2.5, Cottrell & Zafar 6/01/2011";
# Added logic to handle timeouts for unresponsive nodes.
# $pua->timeout() doesn't work without first registering the request $pua->register($req)
# and calling wait $pua->wait()
#my $version="2.6, Cottrell & Zafar 07/12/2011";
# Added support for Parallel::Loops, converted serial for loops to parallel while loops
# for PingER, PerfSONAR and PlanetLab landmarks
# documentation on Parallel::Loops (http://search.cpan.org/~pmorch/Parallel-Loops-0.03/lib/Parallel/Loops.pm)
#my $version="2.7 Cottrell & Zafar 07/12/2011";
# After adding support for parallel loops, the reflector could not run more than 2 instances
# in parallel. This is because Parallel::Loops executes loops using parallel forked subprocesses.
# I changed $max_processes to 80 from 20 and now 8 instances can be run in parallel.
# $max_processes can be increased more to cater for more instances in paralllel.
#my $version="2.8 Zafar & Cottrell 8/27/2011";
# Identified problem with open socket permission
#my $version="2.9 Cottrell 10/2/2013";
#Sped up PingER and perfSONAR landmarks with version>=.3 by factor of 4 using
#the traceroute.pl &options=-i 0.2
#my $version="3.0 Raja Asad & Cottrell 10/15/2013";
#Fixed problems with parallel processing script. Now Code works much faster (about 5 times) and landmarks don't timeout.
my $version="3.1 Raja Asad & Cottrell 11/03/2013";
#Fixed bugs and improved landmarks function
(my $progname = $0) =~ s'^.*/'';#strip path components, if any
my $scriptfn="/afs/slac/package/pinger/tulip/tulip-log-analyze.pl";
my $logconfn="/afs/slac/www/comp/net/wan-mon/tulip/log.conf";
my $lib_log4perl="/var/www/cgi-bin/Log-Log4perl-1.14/lib";
if($lib_log4perl =~ /(^[\/\w+\-\.])+$/) {$lib_log4perl=($1);}#Untaint
#############################################################
my $USAGE = "
This script calls PlanetLab, PerfSONAR and SLAC Landmarks host to get them to
ping a target. It provides the PlanetLab landmarks with a script 
that is executed on each PlanetLab site.
-
Target parameter:
It has one mandatory argument target (specified as an IP address).

It normally has six optional arguments: region, tier, type, ability, 
landmark and domain.
The default for all of these except domain and ability is 'all' 

Region parameter:
Region Examples: Africa        | Balkans     | Europe       | East Asia  
               | Latin America | Middle East | North America
               | Oceania       | Russia      | South Asia   | S.E. Asia 
-
Tier parameter:
 0 use one or two central landmarks (tier 0) per region to indicate roughly 
   where (which region) the target is located in
 1 use the tier 1 landmarks in the selected regions
 2 use all Landmarks in the selected regions
-
Type parameter:
  Type can be equal to PingER, PlanetLab, PerfSONAR or all (default = all)
-
Domain Parameter:
Domain can be equal to domain or node. If domain then only one landmark at
  a site will be used, if node then all landmarks at a site are used. 
  In the case of nodes that have only an IP address the TULIP DB inserts
  the domain as the 1st 2 octets of the address.
  Default = domain.
-
Ability parameter:
 This can be either 1 (enabled) or 0 (disabled) or all. The default is 1.
 This specifies where to find the xml file of landmark sites. The
 default (enabled) file is $xmlfile. The disabled file is:
 $xmldir/sites-disabled.xml. 
-
Function parameter:
  There is also a function parameter with possible values of 
  help, log, analyze and landmarks that can be used to request
  $progname to return help, the log file, to analyze 
  and return the analysis of the log file or to print a list
  of all the landmarks from TULIP db.

  If function=analyze then one can also specify days=n, e.g.
  http://www-lanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=analyze&days=3
  where days is the number of days from the current time
  to go back into the logs. One can also specify the ability = [0|1].

  If the function is landmarks then the ability parameter
  may be provided to select the display of just enabled (ability=1)
  or  disabled (ability=0) landmarks. The default is to display
  both. 
  
  If the type parameter is PingER then just PingER landmarks
  are displayed, if the type parameter is PlanetLabs then just
  PlanetLabs landmarks are displayed.  The default if type
  is not specified is to display both types of landmarks.   
  An additional parameter, when function=landmarks is out. 
  This parameter, defines the output format, which currently 
  can be one of html, csv or tsv. The default value is html. 
  If however, you want your data in csv or tsv format
  set the parameter out accordingly: 
  (i.e. out=csv or out=tsv).
-
Landmark parameter
  if provided it specifies to only use the specified landmarks. 
  If not defined (default)
  then all landmarks are used. It can be a comma delimited list of landmarks
  to use, e.g. landmark=pinger.slac.stanford.edu,pinger.stanford.edu
-
Debug parameter:
There is also a debug feature.
  debug = -2 is usually used with function analyze to remove most of the INFO> output
  debug = -1 gives the minimum needed by TULIP, default for unattended
  debug =  0 gives a normal minimum human readable output, default for command line
  debug =  1 gives status progress messages, can be set from the arguments.
-
The log is created using Log4Perl, the configuration is at:
 $logconfn
It calls: LibXML, EventHandler, $lib_log4perl, Log4Perl
          $scriptfn
-
Input:
  See ability paramter to see what files are used to specify the landmarks.
  $xmlfile contains the Tulip database information
- 
Externals:
 use XML::LibXML;
 use Log::Log4perl;
 use Net::Domain qw(hostname hostfqdn hostdomain);
 use lib /var/www/cgi-bin/Log-Log4perl-1.14/lib;
 use CGI qw/:standard/;
 use HTTP::Request;
 use lib /var/www/cgi-bin/ParallelUserAgent-2.57/lib;
 use LWP::UserAgent;
 use lib /afs/slac.stanford.edu/g/www/cgi-wrap-bin/net/shahryar/smokeping/;
 #See http://search.cpan.org/~marclang/ParallelUserAgent-2.57/lib/LWP/Parallel.pm
 require LWP::Parallel::UserAgent;
 use EventHandler;
 use Parallel::Loops;
 use DBI;
 
Examples of testing from command line use:
 setenv REMOTE_ADDR 134.79.18.134; setenv QUERY_STRING 'target=www.stanford.edu&ability=0'; perl -dT bin/reflector.cgi 'target=www.stanford.edu&ability=0'
 setenv REMOTE_ADDR 134.79.18.134; setenv QUERY_STRING 'target=www.stanford.edu&landmark=206.117.37.7,pinger.slac.stanford.edu&ability=1'; perl -dT bin/reflector.cgi 'target=www.stanford.edu;landmark=206.117.37.7'
 setenv REMOTE_ADDR 134.79.18.134; perl -dT bin/reflector.cgi 'region=North America&target=134.79.18.188;tier=all'
 setenv REMOTE_ADDR 134.79.18.134; perl -dT bin/reflector.cgi 'function=help'
 setenv REMOTE_ADDR 134.79.17.134; perl -dT bin/reflector.cgi 'function=landmarks&out=csv&ability=1&type=PingER'
 setenv REMOTE_ADDR 134.79.17.134; perl -dT bin/reflector.cgi 'function=landmarks&out=csv&ability=all&type=PingER'
 setenv REMOTE_ADDR 134.79.18.134; setenv QUERY_STRING 'target=www.stanford.edu'; perl -dT bin/reflector.cgi 'target=www.stanford.edu;debug=2;type=PerfSONAR;ability=0' | tee junk
 setenv REMOTE_ADDR 134.79.18.134; setenv QUERY_STRING 'target=www.pieas.edu.pk' perl -dT bin/reflector.cgi 'target=www.pieas.edu.pk;type=PingER,perfSONAR' 
-
However unless you have a PlanetLab cookie for your host it will not fully work
You can use  ssh to partially overcome this, e.g.
  ssh www-wanmon /afs/slac/g/www/cgi-wrap-bin/net/shahryar/smokeping/reflector.cgi 'target=www.slac.stanford.edu'
-
To test from the web use:
 http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi/?function=log
 http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?target=www.slac.stanford.edu&ability=0&type=Planetlab
 http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?region=North America&target=www.bnl.gov&tier=1
 e.g. wget 'http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?region=North America&target=134.79.18.188&tier=0'
-
For more documentation see https://confluence.slac.stanford.edu/display/IEPM/TULIP+Central+Reflector
History:
 Written by Shahryar on 16/8/2007  shahryar2001\@slac.stanford.edu for TULIP Project
 Modifed by Cottrell 9/2/07
  Add Log4Perl, reformatted messages, addded HTML header for dies, 
  provide STDERR to user, add use strict, redid indentation
  Add tier, allow commenting, added use of SLAC & Planetlab landmarks
  See ~cottrell/tulip-log-analyze.pl for a analysis of log.
 Modified by Shahryar 5/10/2008
  Added support for parsing the new sites.xml file . The script will no 
  longer fetch the data from the text files
 Modified by Cottrell 7/16/08
  enabled declaration of Log4perl logging file to be only set in the config file
  enabled testing from command line.
 Modified by Cottrell 7/19/08
  enabled getting the log and analysis of the log, also added -w
  added duration etc. to the log at the end.
 Modified by Cottrell 9/21/08
  Added help.
 Modified by Cottrell 11/28/09
  Added ability
 Modified by Fahad Satti 12/26/09
  Added function to print all landmarks.
 Modified by Cottrell 7/24/2010
  to remove STDERR since getting jumbled up with STDOUT, and
  to untaint debug URL parameter and use a value of -2 with tulip-log-analyze.pl 
  to eliminate INFO output
 Modified by Cottrell and Zafar Gilani 9/4/2010
  to add the landmark parameter (which can be a comma delimited list), 
  and perfSONAR monitors
 Modified by Raja Asad 10/15/2013
  to fix parallel processing script, code works 5 times fasters and
  landmarks don't timeout now.
Version=$version
";
#################Get host information###################
#use Sys::Hostname;
#my $ipaddr=gethostbyname(hostname());
#my ($hostname,$aliases, $addrtype, $length, @addrs)=gethostbyaddr($ipaddr,2);
my $addr = $ENV{'REMOTE_ADDR'};
use Net::Domain qw(hostname hostfqdn hostdomain);
my $hostname = hostfqdn();
my $ipaddr=gethostbyname($hostname);
my @addrs;
if(!defined($addr)) { 
  @addrs=unpack('C4',$ipaddr);
  $addr="$addrs[0].$addrs[1].$addrs[2].$addrs[3]";#For debugging from cmd line
  $ENV{'REMOTE_ADDR'}=$addr;
}
####################################################################
#######Set up log file, create if necessary, truncate if too long ##
use lib "/var/www/cgi-bin/Log-Log4perl-1.14/lib";
#use lib $lib_log4perl;
umask(0000);#World write access, so I can erase it even though created by nobody
my $maxfilesize= 25000000;
use Log::Log4perl;
Log::Log4perl->init("$logconfn");
my $tuliplogfile=getlogfn($logconfn);
if($tuliplogfile eq "") {die "Can't find TULIP Log4Perl log file\n";}
use Fcntl;
my $LINES   = ($maxfilesize*80)/100; # Getting the last 20% of file
my $TMP     = "/tmp/tmpFile" ;
my $BAK     = "$tuliplogfile.bak.gz" ;
my $LOG_open=0;
if(!(-e $tuliplogfile)){
  sysopen(LOG, $tuliplogfile, O_WRONLY | O_CREAT | O_TRUNC) #Worried about race conditions
    or my $logger->logdie(&printerror("Landmark=all, Client=$addr, can't truncate LOG $tuliplogfile: $!"));
  my $LOG_open=1;
}
#If size greater than $maxfilesize strip the last valid portion of file and 
#trucate the remaining
if (-s $tuliplogfile > $maxfilesize) {#Truncate file if too long
  #locating last valid record
  my $readvalid = 0;
  # UnTaint file name $TMP;
  if ($TMP =~ /^([-\@\w.\/]+)$/){$TMP = $1;}
  else {die "Bad data in $TMP";}
  sysopen (TMPFILE,"$TMP",O_WRONLY | O_CREAT | O_TRUNC) or die "an error occured: $!"; 
  open (DATA, "$tuliplogfile") or die "an error occured opening $TMP: $!";
  seek  DATA, $LINES, 0; 
  while(<DATA>){ # Start Reading file untill reflector.cgi for start of test
    if($_ =~ m/reflector.cgi/o){
      $readvalid = 1;
    }
    # Read till end and put the output in tempFile
    if($readvalid) {
      print TMPFILE $_; 
    }
  }
  close DATA;
  close TMPFILE;
  my  ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,
       $mtime,$ctime,$blksize,$blocks) = stat($tuliplogfile) ;
  if($tuliplogfile=~/^([-\.\w\/]+)$/){#Untaint argument
    $tuliplogfile=$1;
    rename($TMP, $tuliplogfile) ; # Rename the file to tuliplogfile
  }
  else {die "Unable to rename $TMP to $tuliplogfile\n";}
}
#############Get QUERY_STRING values and process##############
#typical URL:
#http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?region=North America&target=134.79.18.188&tier=0
#target is mandatory, region, type and tier are all optional and default to all,
#debug is also optional and defaults to -1.
#Function may be help, log or analyze, default is null. Log returns the log file, 
#  analyze analyses the log file and returns the analysis, and help returns help.
my $msg="";
use CGI qw/:standard/;
use HTTP::Request;
my $data = new CGI;
#############debug###############################
my $temp            = $data->param('debug');
if(defined($temp))    {
  if($temp=~/^([-\d]+)$/) {
    $debug=$1;#untaint 
  }
  else {print "Invalid debug parameter=$temp specified in the URL, will use default value=$debug\n";}
}
#############ability############################
my $ability         = $data->param('ability');
if(defined($ability)){
  if($ability eq "0"){
    $xmlfile="$xmldir/sites-disabled.xml";
  }
  elsif($ability eq '1') {
    $xmlfile="$xmldir/sites.xml";
  }
  elsif($ability eq '2') { 
    #$xmlfile="$xmldir/sites-all.xml";
    $xmlfile="$xmldir/sites-disabled.xml";
  }
  else {   
    die "Invalid setting for parm ability=$ability, "
      . "possible values 0(disabled landmarks), "
      . "1(enabled landmarks, default), 2(all landmarks)";
  }
}
else {$ability = '1';}#Default if parm not provided
###############type################################
my $typeparameter = $data->param('type');
if (!defined($typeparameter) || $typeparameter eq "") {
  $typeparameter='PlanetLab';
  $typeparameter="PingER,PerfSONAR";
  $typeparameter="all";
}
elsif ($typeparameter !~ /^[\w+|,]+$/){#Must consist of characters with possible commas 
  $msg.="Invalid type value = $typeparameter. "
      . "Must consist of alphanumberic characters and possibly commas";;
}
elsif ($typeparameter=~/^[PingER|SLAC|PlanetLab|PerfSONAR|,]+$/i) {
  my $dbug=1;
}
else {
  $msg.="Invalid type value=$typeparameter. "
      . "Possible typse are PingER, PlanetLab, perfSONAR, case is ignored";
}
if ($msg ne "") {
  printerror("Error: $msg<br><h3>Usage</h3>\n<pre>$USAGE</pre>\n");
  exit 106;
}
###############landmark########################
my $landmarkparameter=$data->param('landmark');
if(!defined($landmarkparameter)) {$landmarkparameter="all";}
else {$landmarkparameter=~s/\s+//g;}#Remove any spaces
###############function########################
my $function        = $data->param('function');
if(defined($function)){
  if($function eq "log"){&get_file($tuliplogfile);    exit 0;}
  elsif($function eq "analyze") {
    my $days=$data->param('days');
    if(!defined($days))         {$days=0;}
    &analyze_log($tuliplogfile, $days); 
    exit 0;
  }
  elsif($function eq "help"){print "<pre>$USAGE</pre>\n"; exit 0;}
  elsif($function eq "landmarks"){
    my $sort = $data->param('sortBy');
    if(!defined($sort) || $sort eq ""){
      $sort = 'serviceInterfaceType,enabled,hostName';
    }
    my $out=$data->param('out');
    if(!defined($out) || $out eq "" || !($out =~ /tsv|csv|html/i)){
      $out = 'html';
    }
    my $PSE = $data->param('PSE');
    if(!defined($PSE) || $PSE eq "" || !($PSE =~ /set/i)){
      $PSE = 'not';
    }
    my $PSD = $data->param('PSD');
    if(!defined($PSD) || $PSD eq "" || !($PSD =~ /set/i)){
      $PSD = 'not';
    }
    my $PLE = $data->param('PLE');
    if(!defined($PLE) || $PLE eq "" || !($PLE =~ /set/i)){
      $PLE = 'not';
    }
    my $PLD = $data->param('PLD');
    if(!defined($PLD) || $PLD eq "" || !($PLD =~ /set/i)){
      $PLD = 'not';
    }
    my $PE = $data->param('PE');
    if(!defined($PE) || $PE eq "" || !($PE =~ /set/i)){
      $PE = 'not';
    }
    my $PD = $data->param('PD');
    if(!defined($PD) || $PD eq "" || !($PD =~ /set/i)){
      $PD = 'not';
    }
    #checking type and ability parameters, and setting GUI variables accordingly
    if(defined($data->param('ability')) && $ability eq "0"){
      if(defined($data->param('type'))){
        if($typeparameter eq "all"){
          $PD  = 'set';
          $PLD = 'set';
          $PSD = 'set';
        }
        else {
          if($typeparameter =~ /PingER/i){
            $PD='set';
          }
          elsif($typeparameter =~ /PlanetLab/i){
            $PLD = 'set';
          }
          elsif($typeparameter =~ /PerfSONAR/i){
            $PSD = 'set';
          }
        }
      }
    }
    elsif(defined($data->param('ability')) && $ability eq "1"){
      if(defined($data->param('type'))){
        if($typeparameter eq "all"){
          $PE  = 'set';
          $PLE = 'set';
          $PSE = 'set';
        }
        elsif($typeparameter =~ /PingER/i){
          $PE='set';
        }
        elsif($typeparameter =~ /PlanetLab/i){
          $PLE = 'set';
        }
        elsif($typeparameter =~ /PerfSONAR/i){
          $PSE = 'set';
        }
      }
    }
    elsif(defined($data->param('ability')) && $ability eq "all"){
      if(defined($data->param('type'))){
        if($typeparameter eq "all"){
          $PD  = 'set';
          $PLD = 'set';
          $PLE = 'set';
          $PE  = 'set';
          $PSE = 'set';
          $PSD = 'set';
        }
        elsif($typeparameter eq "PingER"){
          $PD  = 'set';
          $PE = 'set';
        }
        elsif($typeparameter eq "PlanetLab"){
          $PLD = 'set';
          $PLE = 'set';
        }
        elsif($typeparameter eq "PlanetLab"){
          $PSD = 'set';
          $PSE = 'set';
        }
      }
    }
    ##setting values for type and ability parameters, incase they were not set earlier  
    if($PD=~/set/ || $PLD =~/set/ || $PSD=~/set/){
      if($PE=~/set/ || $PLE =~/set/ || $PSE=~/set/){
        $ability = "all";
      }
      else{
        $ability = "0";
      }
    }
    elsif($PE=~/set/ ||$PLE=~/set/ || $PSE=~/set/){
      $ability = "1";
    }
    if($PD=~/set/ || $PE =~/set/){
      if($PLD=~/set/ || $PLE =~/set/){
        if($PSD=~/set/ || $PSE =~/set/){
          $typeparameter = "all";
        }
        else{
          $typeparameter = "PingER,PlanetLab";
        }
      }
      elsif($PSD=~/set/ || $PSE =~/set/){
        if($PLD=~/set/ || $PLE =~/set/){
          $typeparameter = "all";
        }
        else{
          $typeparameter = "PingER,PerfSONAR";
        } 
      }
      else{
        $typeparameter = "PingER";
      }
    }
    elsif($PLD=~/set/||$PLE=~/set/){
      $typeparameter = "PlanetLab";
    }
    elsif($PSD=~/set/||$PSE=~/set/){
      $typeparameter = "PerfSONAR";
    }
    &show_landmarks($out,$PLE,$PLD,$PE,$PD,$PSE,$PSD,$sort);
    exit 0;
  }
  else {&printerror("Error: invalid function=$function"); exit 101;}
}
################target#############################
#Default (get landmarks to ping the target) so 1st check the target is OK.
my $target          = $data->param('target');
if(!defined($target)) {
  $msg="Target not defined in URL. ";
  printerror("Error: $msg<br><h3>Usage</h3><pre>$USAGE</pre>\n");
  exit 105;
}
$ipaddr=getaddr($target);
if($ipaddr=~/^Invalid/) {$msg=$ipaddr;}
elsif($ipaddr !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/){
  $msg="Invalid target=$target($ipaddr). ";
}
$target=$ipaddr;
###############region#############################
my $regionparameter = $data->param('region');
if(!defined($regionparameter) || $regionparameter eq "") {#default value
  $regionparameter="all";
}
if($regionparameter!~/[\w+,]+/){$msg.="Invalid region=$regionparameter. "}
###############tier###############################
my $tierparameter   = $data->param('tier');
if (!defined($tierparameter)  
 || $tierparameter eq "")      {$tierparameter = "all";}#default
elsif($tierparameter!~/\w+/)   {$msg.="Invalid tier value = $tierparameter. ";}
###############domain#############################
my $domain          = $data->param('domain');
if (!defined($domain)){$domain='domain';}
elsif(!($domain eq 'node' || $domain eq 'domain')){
  $msg="Invalid domain parameter=$domain, must = node or domain. ";
} 
if ($msg ne "") {
  printerror("Error: $msg\n");
  exit 102;
}
my $errStr="";
################Set up asynchronous IO##############
use lib "/var/www/cgi-bin/ParallelUserAgent-2.57/lib";
use LWP::UserAgent;
use lib "/afs/slac.stanford.edu/g/www/cgi-wrap-bin/net/shahryar/smokeping/"; # current directory 
#See http://search.cpan.org/~marclang/ParallelUserAgent-2.57/lib/LWP/Parallel.pm
require LWP::Parallel::UserAgent;
use lib "/afs/slac.stanford.edu/u/sf/rajaasad/bin";
use EventHandler;
use Parallel::Loops;
################Initialize things for threads####################
#The cookie below is for www-wanmon.slac.stanford.edu (134.79.18.134)
#A decoded copy of the interpretive script below can be found at /afs/slac/www/comp/net/wan-mon/tulip/reflector.int
#my $cookie= "189%3Bv1%3Bshahryar%40slac%2Estanford%2Eedu%3B134%2E79%2E18%2E134%2F32%3B1188397267%3B%28s%20%234400068691019A78D1DB0763D073EE462020CE13B0D02DD0F05E9386BEA682A4%23%29";
#my $cookie="251;v1;kalim\@slac.stanford.edu;134.79/16;1256421401;(s #32FFDF5C5DCB7F8F8149EF12532E244548A3166D0DA478888B05ABE1CA654CE0#)";
my $cookie="251%3Bv1%3Bkalim%40slac%2Estanford%2Eedu%3B134%2E79%2F16%3B1256421401%3B%28s%20%2332FFDF5C5DCB7F8F8149EF12532E244548A3166D0DA478888B05ABE1CA654CE0%23%29";
my $pings = 10;        #This is the number of pings sent to the target, needed for PlanetLab $script
my $script= "%23%21+%2Fusr%2Flocal%2Fbin%2Fsrinterpreter%0D%0A%0D%0ADestination+%3D+%22$target%22%0D%0AProbes+%3D+ARGV.length%3E1+%3F+ARGV%5B1%5D.to_i+%3A+$pings%0D%0AAvgIntervalSec+%3D+10.0%2FProbes.to_f%3B+%23+hmm%2C+didn%27t+get+this+right.%0D%0Axprobe+%3D+Scriptroute%3A%3AIcmp.new%2816%29+%0D%0Axprobe.ip_dst+%3D+Destination%0D%0A%0D%0Apackets+%3D+%0D%0A++Scriptroute%3A%3Asend_train%28+%28+1..Probes+%29.map+%7B+%7Crep%7C+++%0D%0A++++++++++++++++++++++++++++probe+%3D+Scriptroute%3A%3AIcmp.new%2816%29+%0D%0A++++++++++++++++++++++++++++probe.ip_dst+%3D+xprobe.ip_dst%0D%0A++++++++++++++++++++++++++++probe.icmp_type+%3D+Scriptroute%3A%3AIcmp%3A%3AICMP_ECHO%0D%0A++++++++++++++++++++++++++++probe.icmp_code+%3D+0%0D%0A++++++++++++++++++++++++++++probe.icmp_seq+%3D+rep%0D%0A++++++++++++++++++++++++++++Struct%3A%3ADelayedPacket.new%28+%28rep%3E1%29+%3F+-Math.log%28rand%29*AvgIntervalSec+%3A+0%2C+%0D%0A++++++++++++++++++++++++++++++++++++++++++++++++++++++probe+%29+%7D+%29%0D%0A%0D%0Apackets.each+%7B+%7Ctuple%7C%0D%0A++if%28+tuple.response+%29+then%0D%0A++++response+%3D+tuple.response.packet%0D%0A++++rtt+%3D+%28response%29+%3F+%28%28tuple.response.time+-+tuple.probe.time%29+*+1000.0%29+%3A+%27*%27%0D%0A++++if+tuple.response.packet.icmp_type+%21%3D+Scriptroute%3A%3AIcmp%3A%3AICMP_ECHOREPLY+then%0D%0A++++++puts+%22Received%3A+%22+%2B+tuple.response.packet.to_s%0D%0A++++else%0D%0A++++++puts+tuple.response.packet.ip_len.to_s+%2B+%27+bytes+from+%27+%2B%0D%0A++++++++tuple.response.packet.ip_src+%2B+%0D%0A++++++++%27%3A+icmp_seq%3D%27+%2B+tuple.probe.packet.icmp_seq.to_s+%2B+%0D%0A++++++++%27+ttl%3D%27+%2B+tuple.probe.packet.ip_ttl.to_s+%2B+%0D%0A++++++++%27+time%3D%255.3f+ms%27+%25+rtt%0D%0A++++end%0D%0A++else%0D%0A++++puts+%22To+%23%7Bxprobe.ip_dst%7D+timed+out%22%0D%0A++end%0D%0A%7D%0D%0A%0D%0A";
my $max_processes = 80;#max simultanously running copies of reflector.cgi
#my $max_processes = 20;#max simultanously running copies of reflector.cgi
my $noofrequests =  80;#Max number of landmarks simltaneously being used
my $t0=time();
my @pservers;          #PlanetLab Servers
my @sservers;          #SLAC/PingER Servers
my @psservers;         #PerfSONAR Servers
########################################################
# Black Listing suspicious client IP addresses
my @denies=("134.78.24.194");
foreach my $deny (@denies) {
  if($deny eq $addr) {
    $msg="Landmark=all, Client=$addr, has been blocked please contact cottrell\@slac.stanford.edu to re-enable<br>";   
    print &printerror("Error: $msg");  
    my $logger->fatal($msg);
    exit 103;   
  }
}
##########################################################
# Check to ensure there are not already too many reflector
# processes running. This is trying to prevent the script from being abused
my $processes=grep(/reflector/, `ps -u $>`);
my $slacs=0; my $planetlabs=0; my $perfsonars=0;
if($processes > $max_processes){# If more than max processing running
  $msg="Landmark=all, Client=$addr, sorry $max_processes TULIP "
     . "reflector processes already running please try later.\n";
  print "Error: &printerror($msg)";
  my $logger->fatal($msg);
  exit 104;
}
##########################################################
#Number of processes running is OK so probe landmarks
else {# else probe the landmarks
  my $landmarks=0;
  # Read the data from sites.xml
  my $parser = new XML::LibXML;
  my $struct = $parser -> parse_file($xmlfile) 
     or my $logger->logdie(&printerror("Landmark=all, Client=$addr, "
             . "could not open file $xmlfile")); 
  my $rootel = $struct -> getDocumentElement;
  my @kids=$rootel -> getElementsByTagName("nmtb:$domain");# nmtb:domain
  @pservers=();
  my %hash = ();
  if($debug>=0) {
    print " Client=$addr probing landmarks in region=$regionparameter,",
          " tier=$tierparameter, type=$typeparameter, ability=$ability,",
          " debug=$debug<br>\n";
  }
  my $nchild=0;
  foreach my $child (@kids){
    $nchild++;
    my ($server,$type,$region,$tier,$city);
    my @nodes = $child->getElementsByTagName('nmtb:node');
    foreach my $node (@nodes){
        my @s   = $node -> getElementsByTagName('pinger:tracerouteURL');
        if($s[0] eq "") {next;}
        $server = $s[0]  -> getFirstChild->getData;
#        if($landmarkparameter ne "all" && ($server ne "$landmarkparameter")) {
        if($server=~/sesame/i) {
          my $dbug=1;
        }
        if($landmarkparameter ne "all") {
          my @landmarks=(split/,/,$landmarkparameter);
          my $use=0; #Identify if we are to use this server as a landmark
          my $servername="";
          if($server=~/%2F([\w\.\d-]+)%2F/) {$servername=$1;}
          else                              {$servername=$server;}
          foreach my $landmark(@landmarks) {
            if($servername eq $landmark) {
              $use=1;
              if($debug>0) {
                print "Found server for requested landmark=$landmark\n";
              }
              next;#Found match, no need to keep looking, use this server
            }
          }
          if($use == 0) {
            if($debug>1) {
              print "Skipped landmark $server since landmarkparameter=$landmarkparameter\n";
            }
             next;
          }
        } 
        my @t   = $node -> getElementsByTagName('pinger:serviceInterface');
        $type   = $t[0] -> getAttribute('type');
        my @r   = $node -> getElementsByTagName('nmtb:continent');
        if(scalar(@r)<1){
          $errStr .= "No nmtb:continent found for $type landmark $server<br/>\n";
        }
        else{
          $region = $r[0]  -> getFirstChild->getData;
        }
        my @c   = $node -> getElementsByTagName('nmtb:city');
        if(defined($c[0])){
          $city   = $c[0]->getFirstChild->getData;
          chomp($city);
          $hash{$server} = $city;
        }
        chomp($region);
        my @tiers   = $node -> getElementsByTagName('pinger:tulipTier');                                                                                                                        
        if(@tiers){
          $tier = $tiers[0]->getFirstChild->getData;
        }
        if(!defined($tier) || $tier eq "")      {$tier="all";}
        if(!defined($region) || $region eq "")  {$region="all";}
        if ($debug>1) {
          print " Probing $type landmark $server($nchild/"
            . scalar(@kids)
            . ") in region=$region(tier=$tier) for $regionparameter($tierparameter), "
            . "so far found landmarks=$landmarks (pl=$planetlabs, sl=$slacs, ps=$perfsonars)<br>\n";
        }
        if($regionparameter eq "all" || $regionparameter =~ /$region/){
          if($tierparameter eq "all" || $tierparameter eq $tier) {
            $landmarks++; 
            if(($type =~ /PlanetLab/i) 
             &&(($typeparameter =~ /PlanetLab/i)||($typeparameter eq "all"))) {
              $planetlabs++;
              push(@pservers,$server);
            }
            if (($type =~ /PingER/i)
              &&(($typeparameter =~ /PingER/i)||($typeparameter eq "all"))) {
              if ($debug>0) {
                print "Debug adding $server to sservers[$slacs]\n";
              }
              $slacs++;
              push(@sservers,$server);
            }
            if(($type =~ /PerfSONAR/i)
             &&(($typeparameter =~ /PerfSONAR/i)||($typeparameter eq "all"))) {
              $perfsonars++;
              push(@psservers,$server);
            }
          }  
        }
    }#End foreach @child
  }#End foreach @kids	
  if ($debug>1) {
    print "Done with kids\n";
  }
  my $pua = EventHandler->new();
  #my $pua = LWP::Parallel::UserAgent->new();
  $pua->in_order  (0); # handle requests in order of registration
  $pua->duplicates(0); # ignore duplicates
  $pua->timeout   (10);# when a server does not respond in 10 seconds timeout otherwise the script will halt
  $pua->max_hosts($noofrequests);# max parallel servers accessed      
  $pua->max_req   (5); # max parallel requests per server, Increasing this number increases the speed of the script
  $pua->redirect  (1);  # follow redirects
  my $log = Log::Log4perl->get_logger("reflector");
  $log->info("Reflector.cgi---- starting for client=$addr "
       . "target=$target, ability=$ability "
       . "in region=$regionparameter, tier=$tierparameter\n"); 
  if($debug>-2) {
    print "<title>Tulip</title></head><body>\n$errStr\nTotal landmark domains (=$domain) in "
        . "$xmlfile = $nchild, PlanetLab servers = "
        . scalar(@pservers ). ", Pinger servers = "
        . scalar(@sservers).  ", PerfSONAR servers = "
        . scalar(@psservers). ", landmark=$landmarkparameter, "
        . "type=$typeparameter, target=$target, "
        . "tier=$tierparameter, region=$regionparameter, "
        . "ability=$ability, debug=$debug, version=$version<br>\n";	
  }
  my %dupnodes;
  my $ndupnode=0;
  ##########################################################
  #Execute the PingER landmarks
  my $maxProcs = 10;
  my $pl = Parallel::Loops->new($maxProcs);
  #for(my $s=0; $s<$#sservers+1; $s++){
  my $s=-1;
  $pl->share(\@sservers);
  while( $s++ < $#sservers ) {
    # URL needs to be decoded   
    my $decode =URLDecode($sservers[$s]);
    if($debug>0){print "Debug decoded $decode from sservers[$s]\n";}
    if($decode eq "") {
      print "Null decoded URL for PingER landmark($s)$sservers[$s]<br>\n";
      next;
    }
    if(defined($dupnodes{$decode})) {
      $ndupnode++;
      print "Duplicate entry # $ndupnode for landmark $decode found at index $s and $dupnodes{$decode}\n<br>";
    } 
    $dupnodes{$decode}=$s;
    #my $res = $pua->register (HTTP::Request->new(GET => "$decode"
    #        . "target=$target"."&function=ping"));
    my $req = HTTP::Request->new(GET => "$decode"."target=$target&function=ping&options=-i 0.2");
    my $t1=time();
    my $res = $pua->register($req);
    my $city = $hash{$sservers[$s]};
    if(defined($city)){
      $log->info("Reflector.cgi -- Executing Landmark(-1) "
           . "for Server=$sservers[$s] City=$city, ability=$ability\n");
    }
    else {$city="";}
    if($debug>0) {
      print "Executed PingER landmark (". ($s+1) ."/"
          . scalar(@sservers).", debug=$debug), URL=$decode, target=$target, "
          . "ability=$ability, "
          . "&function=ping, city=$city, took ".(time()-$t1)."secs.<br>\n";
      print "Status: " . $res->status_line . "\n";
    }
    #print "<br>We're at ", __FILE__, ' line ', __LINE__, "<br>\n";
    #print "city=$city, decode=$decode"."target=$target&function=ping<br>";
  }#End for(my $s=0; $s<$#sservers+1; $s++){
  #$pua->wait();
  #############################################################
  #Execute the PerfSONAR landmarks
  #for(my $s=0; $s<$#psservers+1; $s++){
  $s=-1;
  #$pl->share(\@psservers);
  
  while($s++ < $#psservers)
  {
    # URL needs to be decoded
    #my $decode =URLDecode($psservers[$s]);
    my $decode=$psservers[$s];
	#print "$s\n";
    if(defined($dupnodes{$decode})) {
      $ndupnode++;
      print "Duplicate entry # $ndupnode for landmark $decode found at index $s and $dupnodes{$decode}\n<br>";
    }
    $dupnodes{$decode}=$s;
    if($decode eq "") {
      print "Null decoded URL for perfSONAR landmark($s)$sservers[$s]<br>\n";
      next;
    }
    #Kludge to fix up bad URLs in database
    unless($decode=~/toolkit/) {
      $decode=~s'http://'';
      $decode=~s'/cgi-bin/traceroute.pl'';
      $decode=~s/\/?//;
    }
    unless($decode=~/http:/) {
      $decode="http://$decode/toolkit/gui/reverse_traceroute.cgi?";
    }
    #the HTTP::Request statement (below inside else block)
    #is  modified as below to include a check to validate
    #certificates for hostname
    #my $ua = LWP::UserAgent->new();
    my $t1=time();
    my $req = HTTP::Request->new(GET => "$decode"
            . "target=$target"."&function=ping&options=-i 0.2");
    $req->header('If-SSL-Cert-Subject' => '/CN=make-it-pass.tld');
    my $res  = $pua->register( $req );
    my $city = $hash{$psservers[$s]};
    if(defined($city)){
      $log->info("Reflector.cgi -- Executing Landmark(-1) "
           . "for Server=$psservers[$s] City=$city, ability=$ability\n");
    }
    else {$city="";}
    if($debug>0) {
      print "Executed PerfSONAR landmark (". ($s+1) ."/"
          . scalar(@psservers).", debug=$debug) URL=$decode,"."target=$target, "
          . "ability=$ability, function=ping, city=$city, took "
          . (time()-$t1)."secs.<br>\n";
      print "Status: " . $res->status_line . "<br>\n";
    }
  }
  #$pua->wait();
  ##################################################
  #Execute the PlanetLabs landmarks
  #for (my $s=0; $s<$#pservers+1; $s++){
  $s=-1;
  $pl->share(\@pservers);
  while( $s++ < $#pservers ){
    
    my $decode =URLDecode($pservers[$s]);
    if(defined($dupnodes{$decode})) {
      $ndupnode++;
      print "Duplicate entry # $ndupnode for landmark $decode found at index $s and $dupnodes{$decode}\n<br>";
    } 
    $dupnodes{$decode}=$s;
    if($decode eq "") {
      print "Null decoded URL for PlanetLabs landmark($s)$sservers[$s]\n";
      next;
    }
    my $t1=time();
    $pua->register(HTTP::Request->new(GET => "http://$pservers[$s]:3355/cgi-bin/srrubycgi?script=$script&credentials=$cookie"));
    
    if($debug>2) {
      print "Run ($s/"
          . scalar(@pservers).") on $hostname($ipaddr)<br>\n";
                  }
     if($debug>1) {
       print "\$pua->request(HTTP::Request->new(GET => \"http://$pservers[$s]:3355/cgi-bin/srrubycgi?<br>\n"
          . "script=$script&<br>\n"
          . "credentials=$cookie<p>\n";
    }
    my $city = $hash{$pservers[$s]};
    if(defined($city)){
      $log->info("Reflector.cgi -- Executing Landmark(-1) for "
           . "Server=$pservers[$s] City=$city, ability=$ability\n");
     } 
    else {$city="";}
    if($debug>0) {
      print "Executed PlanetLab landmark (".($s+1)."/"
          . scalar(@pservers).", debug=$debug) URL=$decode, target=$target, "
          . "ability=$ability,function=ping, city=$city, "
          . (time()-$t1)."secs<br>\n";
      #print "Status: " . $res->status_line . "<br>\n";
    }
  }
  my $entries = $pua->wait();# wait for 100 seconds
  my $dt=time()-$t0;
  $msg="$progname: processed $xmlfile($nchild), client=$addr, target=$target, "
     . "region=$regionparameter, tier=$tierparameter, type=$typeparameter, "
     . "ability=$ability, landmark = $landmarkparameter, "
     . "landmarks available=$landmarks, landmarks used PL=$planetlabs, SLAC=$slacs, PS=$perfsonars, dupes=$ndupnode, "
     . "parallel=$noofrequests, threads=$max_processes, duration=$dt secs<br>\n";
  print "<p>$msg\n";
  if($debug>-2) {print "</body></html>\n";}
  $log->info("$msg\n"); 
}#else probe landmarks End
if ($LOG_open) {close LOG or die "Can't close LOG Filehandle: $!";}
exit 0;

###############################################################
#Subroutine to print out error header plus message in 1st arg $_[0]
#Example printerror("Invalid target=$target\n");
sub printerror {
  if($debug>-2) {
    print "<title>Tulip error</title></head><body><font color='red'>",
          "<b>$_[0]</b></font></body></html>\n";
  }
  else {print "$_[0]<br>\n";}
} 

##############################################################
sub URLDecode {
    my $theURL = $_[0];
    $theURL =~ tr/+/ /;
    $theURL =~ s/%([a-fA-F0-9]{2,2})/chr(hex($1))/eg;
    $theURL =~ s/<!--(.|\n)*-->//g;
    return $theURL;
} 

##############################################################
#Subroutine to get the filename for the Log4perl logging
#by looking in the Log4perl configuration file passed in the 
#argument.
#Example:
#  $filename=getlogfn($conf_filename)
#On return $filename contains the log file name or "" if it fails
sub getlogfn {
  my $fn=$_[0];
  my $name='';
  open(CONFIG, "<$fn") or die "Can't find Log4perl configuration file=$fn: $!"; 
  my @lines=<CONFIG>;
  foreach my $line (@lines) {
    my ($pre, undef)=split(/#/,$line);
    if($pre eq "") {next;}
    $line =~ s/\s+//g;
    if ($line=~/log4perl.appender.LOGFILE.filename/) {
      ($pre,$name)=split(/=/,$line);
    }
  }
  close(CONFIG) or die "Can't close $fn: $!/$?";
  return $name;
}

##############################################################
#Subroutine to print landmarks in an html, csv or tsv table
sub show_landmarks{
  my $out  = $_[0];
  my $PLE  = $_[1];
  my $PLD  = $_[2];
  my $PE   = $_[3];
  my $PD   = $_[4];
  my $PSE  = $_[5];
  my $PSD  = $_[6];
  my $sort = $_[7];
  my $enabledColour  = "#00ff00";
  my $disabledColour = "#ff3232";
  use DBI;
  my $pwd;
  require "/afs/slac/g/scs/net/pinger/bin/admin.pl";
#  our $pwd = &gtpwd('tulipro');
  our $pwd = &gtpwd('tulipro');
  our $db = {
          'user'  => 'scs_tulip_uro',
          'host'  => 'mysql-node01',
          'port'  => '3307',
          'dbname'=> 'scs_tulip',
        };
  $db->{password} = $pwd;
  my $dbi = 'DBI:mysql:mysql_socket=/var/lib/mysql/mysql.sock;host='
          . $db->{host}.';port='.$db->{port}.';database='.$db->{dbname};
  my $dbh = DBI->connect($dbi, $db->{user}, $db->{password})
            or die "<title>Tulip Reflector</title>\n</head>\n<body>\n<h1>Tulip reflector erro</h1>\n"
                 . "Reflector could not connect to 'db->{host}': $DBI::errstr";
  my $queryFetchAll = "SELECT enabled,serviceInterfaceType,hostName,".
                      "ipv4Addr,latitude,longitude,tracerouteURL,pingURL,".
                      "city,continent,tuliptier,pingURL".
                      " FROM landmarks";
  my $whereSet=0;
  my $PLESelectStatus = '';
  my $PLDSelectStatus = '';
  my $PESelectStatus = '';
  my $PDSelectStatus = '';
  my $PSESelectStatus = '';
  my $PSDSelectStatus = '';
  if($PLE=~/set/){
    $queryFetchAll .= " WHERE (enabled=1 and serviceInterfaceType like 'PlanetLab')";
    $whereSet=1;
    $PLESelectStatus = ' checked="checked" ';
  }
  if($PLD=~/set/){
    if($whereSet==1){
      $queryFetchAll .= " or (enabled=0 and serviceInterfaceType like 'PlanetLab')";
    }
    else{
      $queryFetchAll .= " WHERE (enabled=0 and serviceInterfaceType like 'PlanetLab')";
      $whereSet=1;
    }
    $PLDSelectStatus = ' checked="checked" ';
  }
  if($PD=~/set/){
    if($whereSet==1){
      $queryFetchAll .= " or (enabled=0 and serviceInterfaceType like 'PingER')";
    }
    else{
      $queryFetchAll .= " WHERE (enabled=0 and serviceInterfaceType like 'PingER')";
      $whereSet=1;
    }
    $PDSelectStatus = ' checked="checked" ';
  }
  if($PE=~/set/){
    if($whereSet==1){
      $queryFetchAll .= " or (enabled=1 and serviceInterfaceType like 'PingER')";
    }
    else{
      $queryFetchAll .= " WHERE (enabled=1 and serviceInterfaceType like 'PingER')";
      $whereSet=1;
    }
    $PESelectStatus = ' checked="checked" ';
  }
  if($PSE=~/set/){
    if($whereSet==1){
      $queryFetchAll .= " or (enabled=1 and serviceInterfaceType like 'PerfSONAR')";
    }
    else{
      $queryFetchAll .= " WHERE (enabled=1 and serviceInterfaceType like 'PerfSONAR')";
      $whereSet=1;
    }
    $PSDSelectStatus = ' checked="checked" ';
  }
  if($PSD=~/set/){
    if($whereSet==1){
      $queryFetchAll .= " or (enabled=0 and serviceInterfaceType like 'PerfSONAR')";
    }
    else{
      $queryFetchAll .= " WHERE (enabled=0 and serviceInterfaceType like 'PerfSONAR')";
      $whereSet=1;
    }
    $PSDSelectStatus = ' checked="checked" ';
  }
  $queryFetchAll .= " ORDER BY ".$sort;
  
  
  
  my $allNodes = $dbh->prepare($queryFetchAll) or die "unable to prepare $!";
  $allNodes->execute() or die "unable to execute $queryFetchAll: $!";
  if($out =~ /html/i){
    my $temp=$typeparameter;
    if($typeparameter eq 'all') {$temp="PingER and PlanetLabs";}
    my $enabled="enabled";
    if($ability eq "0")     {$enabled="disabled";}
    elsif ($ability eq "all")  {$enabled="enabled and disabled";}
    print "<style type='text/css'> 
             body {
               background-color:#eaebfb;
               color:#00009c;
             }
             th {
               border:1px solid blue;
               width:150px;
             }
             td {
               border:1px solid blue;
               width:150px;
               font-size:12px;
             }
             div#head-banner{
               #background:#91ba93;
               color:#00009c;
               float:center;
               text-align:center;
               width:100%;
             }
             ul#list-nav {
             list-style:none;
             margin:20px;
             padding:0;
             width:100%;
             }
             ul#list-nav li {
             display:inline
             }
             ul#list-nav li a {
             text-decoration:none;
             padding:5px 0;
             width:150px;
             background:#91ba93;
             color:#00009c;
             float:left;
             text-align:center;
             border-left:1px solid #fff;
             }
             ul#list-nav li a:hover {
             background:#a2b3a1;
             color:#000;
             }</style>";   
    print "</head><body>";
    print "<ul id='list-nav'>
           <li><a href='http://confluence.slac.stanford.edu/display/IEPM/TULIP+Central+Reflector'>Reflector Wiki</a></li>
           <li><a href='?function=log'>Reflector Log</a></li>
           <li><a href='?function=analyze'>Reflector Analyse log</a></li>
           <li><a href='http://www.slac.stanford.edu/comp/net/wan-mon/viper/tulipmap.html'>Tulip Landmarks Map</a></li>
           <li><a href='?function=help'>Help</a></li> 
           </ul>";
    print "<br/>";
    print "<div id='head-banner'><h3>$temp landmarks from Tulip DB for ability=$enabled</h3></div>\n";
    print "<div id='settings' align='center'>";
    print "<input type='button' value='Toggle Settings'" .
          " onclick='javascript:if(document.getElementById(\"selectNodes\").style.display==\"none\"){" .
          " document.getElementById(\"selectNodes\").style.display=\"\";" .
          " } else{ document.getElementById(\"selectNodes\").style.display=\"none\";}'>";
    print "<div id='selectNodes' style='display:none;'>";
    print '<form name="form1" id="form1" method="get" action="">
             <table width="70%" border="0" align="center" cellpadding="1" cellspacing="5">
               <tr> 
                 <td width="25%" class="selectNodeType" style="background-color:'.$disabledColour.'">
                   <input type="checkbox" name="PLD" id="PLD" value="set"' . $PLDSelectStatus . ' />
                   <label>Planet Lab Disabled Sites</label>
                 </td>
                 <td width="25%" class="selectNodeType" style="background-color:'.$disabledColour.'">
                   <input type="checkbox" name="PD" id="PD" value="set"' . $PDSelectStatus . ' />
                   <label>Pinger Disabled Sites</label>
                 </td>
                 <td width="25%" class="selectNodeType" style="background-color:'.$disabledColour.'">
                   <input type="checkbox" name="PSD" id="PSD" value="set"' . $PSDSelectStatus . ' />
                   <label>PerfSONAR Disabled Sites</label>
                 </td>
                 <td width="25%" class="selectNodeType" style="background-color:'.$enabledColour.'">
                   <input type="checkbox" name="PLE" id="PLE" value="set"' . $PLESelectStatus . ' />
                     <label>Planet Lab Enabled Sites</label>
                 </td>
                 <td width="25%" class="selectNodeType" style="background-color:'.$enabledColour.'">
                   <input type="checkbox" name="PE" value="set"' . $PESelectStatus . ' />
                   <label>Pinger Enabled Sites</label>
                 </td>
                 <td width="25%" class="selectNodeType" style="background-color:'.$enabledColour.'">
                   <input type="checkbox" name="PSE" id="PSE" value="set"' . $PSESelectStatus . ' />
                     <label>PerfSONAR Enabled Sites</label>
                 </td>
              </tr>
              <tr>
              <td colspan="4" align="center" style="border:0px;">
                <input type="hidden" id="function" name="function" value="landmarks" /><input type="submit" value="Refine Landmarks" />
              </td>
              </tr>
            </table>
          </form>';
    print "</div>";
    print "<div id='tulip_map' align='center'>";
#   print "<a href='http://www.slac.stanford.edu/comp/net/wan-mon/viper/tulip_map.htm'>Tulip Landmarks Map</a><br/>";
#   print "<a href='reflector.cgi?function=landmarks&out=csv'>".
    print "<a href='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks&PLD=$PLD&PD=$PD&PSD=$PSD&PLE=$PLE&PE=$PE&PSE=$PSE&out=csv'>".
          "Comma Separated Value (CSV)format for Excel etc</a>";
    print "</div>";
    print "</div>";
    print "<div>\n";
    print "<table style='background-color:#91ba93;border: 0px;'>\n";
    print "<thead>\n";
    print "<th><a href='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks&PLD=$PLD&PD=$PD&PSD=$PSD&PLE=$PLE&PE=$PE&PSE=$PSE&sortBy=serviceInterfaceType'>Type</a></th>";
    print "<th><a href='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks&PLD=$PLD&PD=$PD&PSD=$PSD&PLE=$PLE&PE=$PE&PSE=$PSE&sortBy=hostName'>Host Name</a></th>";
    print "<th><a href='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks&PLD=$PLD&PD=$PD&PSD=$PSD&PLE=$PLE&PE=$PE&PSE=$PSE&sortBy=ipv4addr'>IPv4 Address</a></th>";
    print "<th><a href='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks&PLD=$PLD&PD=$PD&PSD=$PSD&PLE=$PLE&PE=$PE&PSE=$PSE&sortBy=latitude'>Latitude</a></th>";
    print "<th><a href='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks&PLD=$PLD&PD=$PD&PSD=$PSD&PLE=$PLE&PE=$PE&PSE=$PSE&sortBy=longitude'>Longitude</a></th>";
    print "<th><a href='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks&PLD=$PLD&PD=$PD&PSD=$PSD&PLE=$PLE&PE=$PE&PSE=$PSE&sortBy=tracerouteURL'>Traceroute URL</a></th>";
    print "<th><a href='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks&PLD=$PLD&PD=$PD&PSD=$PSD&PLE=$PLE&PE=$PE&PSE=$PSE&sortBy=pingURL'>Ping URL</a></th>";
    print "<th><a href='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks&PLD=$PLD&PD=$PD&PSD=$PSD&PLE=$PLE&PE=$PE&PSE=$PSE&sortBy=city'>City</a></th>";
    print "<th><a href='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks&PLD=$PLD&PD=$PD&PSD=$PSD&PLE=$PLE&PE=$PE&PSE=$PSE&sortBy=continent'>continent</a></th>";
    print "<th><a href='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks&PLD=$PLD&PD=$PD&PSD=$PSD&PLE=$PLE&PE=$PE&PSE=$PSE&sortBy=tuliptier'>tier</a></th>";
    print "<th><a href='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks&PLD=$PLD&PD=$PD&PSD=$PSD&PLE=$PLE&PE=$PE&PSE=$PSE&sortBy=pingURL'>URL</a></th>";
    print "</thead>\n";
    print "<tbody style='width:100%;height:300px;overflow-y:auto;'>\n";
  }
  elsif($out =~ /csv/i){
    print "<pre>enabled,serviceInterfaceType,name,hostName,"
        . "ipv4Addr,latitude,longitude,tracerouteURL,pingURL,city,continent,tier,URL\n";
  }
  elsif($out =~ /tsv/i){
    print "<pre>enabled \t serviceInterfaceType \t name \t hostName \t"
        . "ipv4Addr \t latitude \t longitude \t tracerouteURL \t pingURL \t city \t continent \t tier \t URL\n";
  }
  else{
    print "<pre>enabled \t serviceInterfaceType \t name \t hostName \t"
        . "ipv4Addr \t latitude \t longitude \t tracerouteURL \t pingURL \t city \t continent \t tier \t URL\n";
  }
  my $thisRow=0;
  my $planetlabEnabledNodes=0;
  my $planetlabDisabledNodes=0;
  my $perfsonarEnabledNodes=0;
  my $perfsonarDisabledNodes=0;
  my $pingerDisabledNodes=0;
  my $pingerEnabledNodes=0;
  while (my @row = $allNodes->fetchrow_array()) {
    if(  (($row[0]==0) && ($ability eq "1")) 
      || (($row[0]==1) && ($ability eq "0"))) {
      next;
    }
    if(  (($typeparameter eq "PingER")    && ($row[1] =~ /PlanetLab/))
      || (($typeparameter =~ /PlanetLab/) && ($row[1] eq "PingER"))  ) {
      #next;
    }
    if($out =~ /html/i){
      $thisRow++;
      my $color='#ffffff';
      if($row[0]==1){
        $color = $enabledColour;
      }
      else{
        $color = $disabledColour;
      }
      print "<tr style='background-color:".$color.";'>";
      if($row[1] =~ /pinger/i){
        if($row[0]==1){
          $pingerEnabledNodes++;
        }
        else{
          $pingerDisabledNodes++;
        }
      }
      elsif($row[1] =~ /planetlab/i){
        if($row[0]==1){
          $planetlabEnabledNodes++;
        }
        else{
          $planetlabDisabledNodes++;
        }
      }
      elsif($row[1] =~ /perfsonar/i){
        if($row[0]==1){
          $perfsonarEnabledNodes++;
        }
        else{
          $perfsonarDisabledNodes++;
        }
      }
    }
    else{
    }
    my $count=0;#Column counter 
    foreach my $col (@row){
      $count++;
      if($count==1){
        if($out=~/html/i){
          next;
        }
      }
      if(!defined($col) || $col eq ""){
        if($out =~ /html/i){
          print "<td>NULL</td>";
        }
        else{
          print "NULL,";
        }
      }
      else{
        if($out =~ /html/i){
          if($col =~ /^http/i){
            if($col =~ /ping$/i){
              print "<td><a href='$col' target='_blank'>Ping URL</a></td>";
            }
            else{
              print "<td><a href='$col' target='_blank'>Trace URL</a></td>";
            }
 
          }
          else{
            print "<td>$col</td>";
          }
        }
        elsif($out =~ /csv/i){
          print "$col,";
        }
        elsif($out =~ /tsv/i){
          print "$col \t ";
        }
        else{
          print "$col \t ";
        }
      }
    }
    if($out =~ /html/i){
      print "</tr>\n";
    }
    else{
      print "\n";
    }
  }
  if($out =~ /html/i){
    print "</TBODY>\n";
    print "</table>\n";
    print "</div>\n";
    print "<label>Total number of landmarks = ".$thisRow.";</label>\n";
    print "<label>Enabled Pinger Landmarks = ".$pingerEnabledNodes.";</label>\n";
    print "<label>Disabled Pinger Landmarks = ".$pingerDisabledNodes.";</label>\n";
    print "<label>Enabled PerfSONAR Landmarks = ".$perfsonarEnabledNodes.";</label>\n";    
    print "<label>Disabled PerfSONAR Landmarks = ".$perfsonarDisabledNodes.";</label>\n";    
    print "<label>Enabled Planet Lab Landmarks = ".$planetlabEnabledNodes.";</label>\n";    
    print "<label>Disabled Planet Lab Landmarks = ".$planetlabDisabledNodes.";</label><br>\n";
	
	#print"$queryFetchAll\n";
	
    print "</body></html>\n";
  }
} 

##############################################################
#Subroutine to return the file
#Prints the file and returns the number of lines in the file
sub get_file {
  my $fn=$_[0];
  if($fn=~/^([-\.\w\/]+)$/){#Untaint argument
    $fn=$1;
  }
  open(FN, "<$fn") or die "Can't open $fn: $!";
  my @fnlines=<FN>;
  print "<title>Tulip Log on $hostname</title></head><body>\n"
        . "<h1>Tulip Log on $hostname</h1>\n<pre>";  
  if(scalar(@fnlines)==0) {
    print "<font color='red'><b>Tulip log $fn on $hostname has 0 lines</b></font>\n";
  }
  foreach my $fnline (@fnlines) {
    $fnline=~s/<\/pre>//g;
    print "$fnline";#fnline has the newlines already in there.
  }
  if($debug>=0) {
    print "</pre>\n<hr>".scalar(@fnlines)
        . " lines found on $hostname in the Tulip log at $fn.</body></html>\n";
  }
  return scalar(@fnlines);
}

#############################################################
#Analyze the Tulip log
sub analyze_log {
  my $logfn=$_[0];
  my $days =$_[1];
  if($logfn=~/^([-\.\w\/]+)$/){#Untaint argument
    $logfn=$1;
  }
  print "<title>Tulip Log Analyzed for $logfn on $hostname</title>\n"
      . "</head></body>\n"
      . "<h1>Tulip Log Analyzed for $logfn on $hostname</h1>\n<pre>";
  #############################################################
  # The following system call to analyze the tulip reflector logs
  # avoids shell expansions so we do not
  # worry about checking the $logfn for shell meta-characters. 
  if($scriptfn     =~ /^([-\/\w.]+)$/) {$scriptfn=$1;}#untaint
  if($logfn        =~ /^([-\/\w.]+)$/) {$logfn   =$1;}#untaint
  if($days         =~ /^(\d+)/)        {$days=$1;}    #untaint
  if($ability      =~ /^(\d+)/)        {$ability=$1;} #untaint
  system($scriptfn, '-f', $logfn, '-d', $days, '-D', $debug, '-a', $ability);
  return;
}

############################################################
#Given an IP name or IP address of a host, validates the input 
#and returns an error or the host's IP address.
# To use:
# $ipadr=getaddr('www.slac.stanford.edu')
#or
# $ipadr=getaddr('134.79.18.163');
# if($ipadr =~ /^Invalid/) {die $ipadr;}
# 
sub getaddr{
  my $name=$_[0];
  if($name=~/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/) {
    return $name;#Input is a valid IP address
  }
  elsif($name !~ /[\w\.\-]+/) {#Valid characters in name
    return "Invalid target=$name is not an IP address or name. ";
  }
  else {#Input is a valid IP name
    my $ipaddr=gethostbyname($name);
    if(!defined($ipaddr)) {
      return "Unknown name=$name. ";
    }
    my ($a, $b, $c, $d)=unpack('C4',$ipaddr);
    $ipaddr=$a.".".$b.".".$c.".".$d;
    return $ipaddr;
  }
}  
__END__
