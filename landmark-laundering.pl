#!/usr/local/bin/perl -w
#--------------------------------------------------------------*/       
#                      DISCLAIMER NOTICE                       */       
#                                                              */       
# This  document  and/or portions  of  the  material and  data */       
# furnished herewith,  was developed under sponsorship  of the */       
# U.S.  Government.  Neither the  U.S. nor the U.S.D.O.E., nor */       
# the Leland Stanford Junior  University, nor their employees, */       
# nor their  respective contractors, subcontractors,  or their */       
# employees,  makes  any  warranty,  express  or  implied,  or */       
# assumes  any  liability   or  responsibility  for  accuracy, */       
# completeness  or usefulness  of any  information, apparatus, */       
# product  or process  disclosed, or  represents that  its use */       
# will not  infringe privately-owned  rights.  Mention  of any */       
# product, its manufacturer, or suppliers shall not, nor is it */       
# intended to, imply approval, disapproval, or fitness for any */       
# particular use.   The U.S. and  the University at  all times */       
# retain the right to use and disseminate same for any purpose */       
# whatsoever.                                                  */       
#--------------------------------------------------------------*/       
# Copyright (c) 2006, 2007    
# The Board of Trustees of          
# the Leland Stanford Junior University. All Rights Reserved.       
#################################################################
#The following code is placed at the top to ensure we are able to use perl -d
#and stop things before they call other things.
my $debug; #For cronjobs use -1, for normal execution from command line use 0,
           #for debugging information usr > 0, maximum value=3.
if (-t STDOUT) {$debug=0;}
else           {$debug=-1;} #script executed from cronjob
################################################################
use strict;
use DBI;
use Data::Dumper;
umask(0002);
my $version="0.1, 08/21/08, lonex";
my $count="";
my $landmarkUpdateQuery="";
############ connecting to tulip database ################################
our $db = {                                                                                                                                                                            
                'user'     => 'tulip',                                                                                                                                                     
                #'host'     => 'pinger.slac.stanford.edu',
                'host' => 'localhost',
                'port'     => '1000',                                                                                                                                                      
                'dbname'   => 'tulip',                                                                                                                                                   
        };   
#################Set up some variables for the USAGE documentation########
(my $progname = $0) =~ s'^.*/'';   # strip path components, if any
#22=ssh, 80=www, 7=tcp echo, 53=ns, 23=telnet, 25=smtp, 21=FTP, 37=time, 79=finger
my @ports=(80);#80,7,53,23,25,21,37,79); 
################Usage information#########################################
#Documentation
my $USAGE = "Usage:\t $progname [opts] 
        Opts:
	[-D debug]
        [-c column]
        [-p ports]
        [-v]
Where:
        debug is the debug level (debug output goes to STDERR), 
          range 0..2, higher values give more debug output, default = $debug
        ports are the ports to use when testing with synack, 
          special case  of -1 means no synacks at all, 
          = 0 means only synack nodes with names starting www (port 80)
          or ns, default=@ports.
        -v provides this output.
Function:
	Analyze the list of ping nodes provided to see if they are known
	(i.e. the name resolves and there is a path to the host),
	whether they respond to a ping, and whether the IP address given
        matches that found by ping. If the host name is not known then it 
        will try the address. If the host name is known but does not
        respond to a ping, the script will try the IP address, if this also
        fails then  the script will try and see if the host
        is reachable by synack on some common ports. The common ports
        are @ports. N.b. ntp (123/tcp) and tcp echo (7/tcp) are blocked
        the usual successes are on 80, 22 and 53.
Input:
        From mysql database $db->{'dbname'}.
Output (STDOUT):
  NoResponse: jlab7.jlab.org(192.70.245.99/192.70.245.99):235/1/1/0/0/1/0
  Not Found: orgwy-fw.ornl.gov(192.31.96.161/unknown): 240/2/1/1/0/1/0
OK(name): ping.slac.stanford.edu*(134.79.18.21/134.79.18.21):243/3/2/1/1/1/0
OK(addr): fnal.fnal.gov*(131.225.111.1/131.225.111.1):248/4/3/1/2/1/0#* after name = Beacon
OK: www.bnl.gov(130.199.3.21/130.199.3.21):252/5/4/1/3/1/0
  NoResponse: dns1.arm.gov(192.148.93.23/unknown):269/10/8/2/6/2/2
   Blocked: pings but synack works for dns1.arm.gov:53
OK: pinger.bnl.org(192.203.218.43/192.203.218.43):254/6/5/1/4/1/0
OK: www.llnl.gov(134.9.217.160/198.128.246.160):256/7/6/1/5/1/0
  Mismatch: for www.llnl.gov(134.9.217.160/198.128.246.160) ne 198.128.246.160 (1)
...
# Summary: Wed Feb 28 05:54:56 2007 /afs/slac/g/scs/net/pinger/bin/ping-beacons.pl found nodes=533(beacons=58)
#  founds=530, not_founds=3
#  respond=489(addrs=2), no_responses=29, mismatch=11, blocks=12, no_names=16, AMPs=0, bad_ips=0, satellite_links=78,
#  clusters=5, dbaddrs=2, redirects=1, TTL exceeds=0, Unreachable=3, Filtered=0
#  in 533 lines of input file=/tmp/ping-beacons.txt
#  Wed Feb 28 05:54:56 2007 this file was created by /afs/slac/g/scs/net/pinger/bin/ping-beacons.pl
#  for pinger
#  on pinger.slac.stanford.edu(linux) from column 0 of /tmp/ping-beacons.txt

Version=$version
";
##################################################################
#  Please send comments and/or suggestion to Les Cottrell.
#
# **************************************************************** 
# Owner(s): Les Cottrell,lonex (3/12/06).                                
# Revision History: (08/12/2008)
# This script is based on script ping-beacons, changes made are:
# Inclusion of another parameter named opt_t which would tune
# Tulip, It would connect itself with tulip database get all the
# hosts which are disabled and check if someone is up, if it finds
# host up it would increment days up                                              
# **************************************************************** 
use Sys::Hostname; 
use Socket;
my $ipaddr=gethostbyname(hostname());
my ($a, $b, $c, $d)=unpack('C4',$ipaddr);
my ($hostname,$aliases, $addrtype, $length, @addrs)=gethostbyaddr($ipaddr,2);
use Date::Calc qw(Add_Delta_Days Delta_Days Delta_DHMS);
use Date::Manip qw(ParseDate UnixDate);
use Time::Local;
my $user=scalar(getpwuid($<));
$|=1; #Do not buffer output
#open(STDERR, '>&STDOUT');# Redirect stderr onto stdout
my $pwd=get_tulip_pwd();
$db->{'password'}=$pwd;

###############Process Options####################################
#Process options
my @argv=@ARGV;
our ($opt_c, $opt_d, $opt_v, $opt_p, $opt_D)=("","","","","");
require "getopts.pl";
&Getopts('c:d:D:p:v');
if($opt_v) {
  print "$USAGE"; 
  exit 1;
}
if($opt_D ne "")    {$debug=$opt_D;} 
if($opt_c eq "")    {$opt_c=0;}
if($opt_p eq "-1")  {@ports = (-1);}
elsif($opt_p eq "0"){@ports = (0);}
elsif($opt_p ne "") {
  @ports=split(/,/, $opt_p);
}
##################################################
if($debug>=0) {
  print STDERR " ".scalar(localtime())
      . " starting $0\n  using col $opt_c from file tulip database on $hostname($^O) for $user\n"
      . "  using synack ports @ports\n";
}
my $n=0; my $finds=0; my $notfounds=0; my $goods=0; my $amps=0; my $badips=0;
my $noresponses=0; my $nodes=0; my $mismatch=0; my $blocks=0; my $dbaddrs=0;
my $nonames=0; my $addrs=0; my $satellites=0; my $temporarys=0;
my $nclusters=0; my $nredirect=0; my $nunreach=0; my $nfilter=0; my $nexceed=0; 
my $temp_fn="/tmp/ping-beacons.txt"; my $nlines=0;
#########################################
# Header information 
print "#Status of PingER hosts, created:"
    . scalar(localtime())
    . " from tulip database for "
    . scalar(getpwuid($<))
    . " on $hostname.\n";
#####################################################################
#Process nodes list line by line.
if($debug>0) {
  print STDERR "line_no/nodes/found/not_found/respond/no_response/mismatch/temporaries\n";
}
my (@tokens, $minrtt, $amp);
my ($address, $name, $target, $upDays, $downDays)=("","","","",""); 
my $found=0; my $noresponse; 
my $actual_addr="unknown";#IP addresss returned by ping
######################################################################
#Known clusters that return different IP addresses for given IP name
my @clusters=("indix.cdacmumbai.in",  "ccali.in2p3.fr",  "www.sify.com",  
              "h-st2-7.aspn.net", 
              "www.utpl.edu.ec",      "www.ams.ac.ir",   "www.camnet.cm", 
              "www.infn.it",          "ns.fpf.br",       "www.maurifemme.mr",
              "www.inima.al",         "www.ioe.edu.np",  "www.uma.rnu.tn",
              "www.ahome.tg",         "www.ecnu.edu.cn");
my $noresp_type="unknown";
my $mismatch_type="unknown";
#######################################################################
#Connect to database and fetch all the records which are disabled
# setup db
#connect
my $dbi = 'DBI:mysql:mysql_socket=/var/lib/mysql/mysql.sock;host=' 
        . $db->{host} . ';port=' . $db->{port} . ';database=' . $db->{dbname};
my $dbh = DBI->connect($dbi, $db->{user}, $db->{password} )
        or die "Could not connect to 'db->{host}': $DBI::errstr";
#my $query = 'SELECT * FROM landmarks where enabled = \'0\''; // by Fida on 11/19/09 to just see the effect of code on PingER nodes
my $query = 'SELECT * FROM landmarks where serviceInterfaceType = \'PingER\'';
#my $query = 'SELECT * FROM landmarks';
my $sth = $dbh->prepare( $query );
$sth->execute() or die "Could not execute query '$query'";

########################################################################
#Getting updays and downdays information from database
$query = 'SELECT * FROM maintenance';
my $st = $dbh->prepare( $query );
$st->execute() or die "Could not execute query '$query'";
########################################################################
PROCESSNEXTLINE:
while( my $row = $sth->fetchrow_hashref ) {
  $n++;
  $name    = $row->{hostName};
  $address = $row->{ipv4Addr};
  #Getting updays and downdays information from database
  $query = "SELECT * FROM maintenance where ipv4Addr = \'$address\'";
  my $st = $dbh->prepare( $query );
  $st->execute() or die "Could not execute query '$query'";
  my $result = $st->fetchrow_hashref;
  $upDays   = $result->{upDays};
  $downDays = $result->{downDays};
  my $line = "$row->{hostName} $row->{ipv4Addr}"; 
  if(!defined($name)) {next;}
  if((($name !~ /\./) || ($name =~ /^\./)) && ($name !~ /^amp/)) {
    print STDERR "  !!Bad IP name/address $name in ($n): $line\n";
    $badips++;
    next;
  }
  if(!defined($address)) {
    $address=$name;
  }
  my $oktype="(name)";
  if($name=~/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
    $target=$1;#Using $1 instead of $name gets rid of extraneous spaces 
    $name=gethostbyaddr(inet_aton($target),2);#try & get a name for the address
    if(!defined($name)) {$name=$target; $nonames++;}
    else {
      $oktype="(dbaddr)";
      $dbaddrs++;
    }
  }
  else {$target=$name;}
  $nodes++;
  ##################################################################
  #Try to ping the remote host, if it is not found (e.g. not in DNS),
  #then try and re-ping with the IP address if available.
  $actual_addr="unknown";
  $found=0; my $found1=0;
  my $oktoping=0;
  $noresp_type="unknown";
  $oktoping="1";
  if($name eq "adl-a-ext1.aarnet.net.au") {
    $a=1;#Test here for debug special case
  }
  if($oktoping) {
    $found1=&pingit($target);
    if(!$found1) {#Host not found. Ping IP address, if there is one & not already tried
      if($target!~/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {#is target already the address
        if($address=~/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {#Do we have an IP address?
          $found=&pingit($address);
          if($found == 1) {$found=2;} #Note that this host worked with address but not name
          #Host found but no response, however found has no meaning for IP address, so
          #so mark it as NOT found by name. 
          elsif($found == -1){$found=0;} 
        }
      }
    }
    else {$found=1;}
  }
  ##################################################################
  #Analyze the results of the pings
  if ($found) {
    $finds++; 
    if(!$noresponse) {#Node responded to at least some pimgs
      $goods++; 
      if($found == 2 && $oktype ne "(dbaddr)") {$oktype="(addr)"; $addrs++;}
      $upDays++;
      $count=$dbh->prepare("UPDATE maintenance SET comments='OK $oktype',downDays ='0',upDays=$upDays where ipv4Addr = \'$address\'");
      $count->execute();
      if($debug>0){
        print "updating landmark table for $address. enabled=1\n";
      }
      $landmarkUpdateQuery = $dbh->prepare("UPDATE landmarks SET enabled=1 where ipv4Addr=\'$address\'");
      $landmarkUpdateQuery->execute();
      $upDays--;
      print STDERR "OK".$oktype.":Disabled host $name responded its been up for past $upDays days\n";
      if($oktype eq "(addr)") {
        print STDERR "OK".$oktype.": $name($address/$actual_addr)$minrtt, $n/$nlines:$line\n------------------\n";
      }
      if($address=~/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {#is $address an IP address
        if($actual_addr ne $address) {
          foreach my $cluster (@clusters) {
            if($cluster eq $name) {
              $nclusters++;
             # $count=$dbh->prepare("UPDATE downsites_new SET beacon_status='Cluster$beacon' where remote_node ='$name'"); 
             # $count->execute();
              print "  Cluster: for $name($address/$actual_addr) ne $actual_addr ($mismatch)\n";
              next PROCESSNEXTLINE;
            }
          }
          $mismatch++; 
         # $count=$dbh->prepare("UPDATE downsites_new SET beacon_status='MisMatch$beacon' where remote_node ='$name'"); 
         # $count->execute();
         # print "  Mismatch($mismatch_type): for $name$beacon(was=$address/now=$actual_addr) ($mismatch)\n";
        }
      }
    }
    ##############################################################
    #If the host is known (found) but does not respond to ping then
    #try to synack it on most common ports, otherwise write off as not responding
    else {
      my $synack=synack(@ports);
      if ($synack > 0) {
        $blocks++;
        my $temp=": $synack";
        $upDays++; 
        print "UPDATE maintenance SET comments='Block$temp',downDays ='0',upDays=\'$upDays\' where ipv4Addr = \'$address\'\n";
        $count=$dbh->prepare("UPDATE maintenance SET comments='Block$temp',downDays ='0',upDays=$upDays where ipv4Addr = \'$address\'"); 
        $count->execute();
        if($debug>0){
          print "updating landmark table for $address. enabled=1\n";
        }
        $landmarkUpdateQuery = $dbh->prepare("UPDATE landmarks SET enabled=1 where ipv4Addr=\'$address\'");
        $landmarkUpdateQuery->execute();
        print "   Blocked:($nodes) pings, but synack works for $name($address):$synack\n";
      }
      else {
        $noresponses++;
        $downDays++;
        $count=$dbh->prepare("UPDATE maintenance SET comments='No Response',downDays =\'$downDays\',upDays=0 where ipv4Addr = \'$address\'");
        $count->execute();
        #$count=$dbh->prepare("UPDATE downsites_new SET beacon_status='No Response$beacon' where remote_node ='$name'"); 
        #$count->execute();
        if($debug>0){
          print "updating landmark table for $address. enabled=0\n";
        }
        $landmarkUpdateQuery = $dbh->prepare("UPDATE landmarks SET enabled=0 where ipv4Addr=\'$address\'");
        $landmarkUpdateQuery->execute();
        if($debug>0) {
          print "  NoResponse($noresp_type):\n"
              . "    $name($address/$actual_addr),$n/$nlines:$line\n";       
        }
      }
    }
  }
  else {
    $notfounds++;
    print "UPDATE maintenance SET comments='Not Found',downDays=($downDays+1),upDays=0 where ipv4Addr like '$address'\n";
    $downDays++;
    $count=$dbh->prepare("UPDATE maintenance SET comments='Not Found',downDays =\'$downDays\',upDays=0 where ipv4Addr = \'$address\'");
    $count->execute();
    if($debug>0){
      print "updating landmark table for $address. enabled=0\n";
    }
    $landmarkUpdateQuery = $dbh->prepare("UPDATE landmarks SET enabled=0 where ipv4Addr=\'$address\'");
    $landmarkUpdateQuery->execute(); 
    print "  NotFound: $name($address/$actual_addr): $n/$nodes/$finds/$notfounds/$goods/$noresponses/$mismatch/$temporarys\n";
  }
  if($debug>0) {print STDERR "  $name($address/$actual_addr): $n/$nodes/$finds/$notfounds/$goods/$noresponses/$mismatch/$temporarys\n";}
  if($debug>2) {print STDERR " ";}
}
#########################Finish Up#################################
my $msg="# Summary: ".scalar(localtime())
    . " $0 found nodes=$nodes\n#  founds=$finds, not_founds=$notfounds\n"
    . "#  respond=$goods(addrs=$addrs), no_responses=$noresponses, mismatch=$mismatch, "
    . " blocks=$blocks,  bad_ips=$badips, "
    . "satellite_links=$satellites,\n"
    . "#  clusters=$nclusters, dbaddrs=$dbaddrs, redirects=$nredirect, TTL exceeds=$nexceed, "
    . "Unreachable=$nunreach, Filtered=$nfilter, Temporaries=$temporarys\n"
    . "#  in $n lines of input tulip database \n#  "
    .  scalar(localtime())
    . " this file was created by $0\n#  for $user\@$hostname($^O) \n"
    . "#  $0 @argv\n"; 
#if($debug>0) {print STDERR "$msg";}
print "$msg";
exit 0; 

###########################################
#SYN-ACK to dns1.ethz.ch (129.132.98.12), 4 Packets
#
# connection for seq no: 0 timed out within 1.000 Secs
# connection for seq no: 1 timed out within 1.000 Secs
# connection for seq no: 2 timed out within 1.000 Secs
# connection for seq no: 3 timed out within 1.000 Secs
#
# Waiting for outstanding packets (if any)..........
#
#
# ***** Round Trip Statistics of SYN-ACK to dns1.ethz.ch (Port = 22) ******
# 4 packets transmitted, 0 packets received, 100.00 percent packet loss
# round-trip (ms) min/avg/max = 0.000/0.000/0.000 (std = 0.000)
#  (median = 0.000)       (interquartile range = 0.000)
#  (25 percentile = 0.000)        (75 percentile = 0.000)
sub synack {
  my @ports = @_;
  if($ports[0] eq "-1") {return(-1);}
  if($^O=~"linux") {
    my $success=0;    
    if($target=~/www/)                    {@ports=(80);} 
    if($target=~/^ns/ || $target=~/^dns/) {@ports=(53);}
    if($ports[0] eq "0") {return(-1);}
    foreach my $port (@ports) {
      my $cmd="/afs/slac/package/pinger/old/synack/\@sys/synack -k 4 -p $port $target";
      my @ans=`$cmd`;
      if ($debug>1) {print STDERR "Executing $cmd gave($?):\n @ans"}
      if($? && $debug>=0) {print STDERR "$cmd gave error=$?\n@ans";}
      elsif($ans[12] =~ /,\s+(\d+)\s+/) {
        if($1 ne "0") {$success=$port; last;}
      }
      else {
        if($debug>0) {
          print STDERR "$cmd gave unexpected output (error=$?)\n@ans";
        }
      }
    }
    return($success);
  }
  return(-1);
}

sub node_details {
  my $temp_fn=$_[0];
  truncate($temp_fn,0);
  open(TEMP_FN,">$temp_fn") or die "Can't open $temp_fn";
  our %NODE_DETAILS;
  my $nodes_fn="/afs/slac/package/pinger/nodes.cf";
  require "$nodes_fn";
  my $nlines=0; my $n=0;
  foreach my $key (sort keys %NODE_DETAILS) {
    $n++;
    $key =~ s/^\s+//;
    if($key eq "") {next;}
    if(!defined($NODE_DETAILS{$key}[8])) {
      print "NODE_DETAILS($key) undefined\n";
      next;
    }
    if(($NODE_DETAILS{$key}[8] =~ /D/) || ($NODE_DETAILS{$key}[8] =~ /Z/)) {
      next;
    }
    if((($key !~ /\./) || ($key =~ /^\./) || $key =~ /^0/) && ($key !~ /^amp/)) {
      print "  !!Bad IP name/address $key in ($n): $NODE_DETAILS{$key}[0], groups=$NODE_DETAILS{$key}[14], state=$NODE_DETAILS{$key}[8]\n";
      $badips++;
      next;
    }
    $nlines++;
    print TEMP_FN "$key $NODE_DETAILS{$key}[0] $NODE_DETAILS{$key}[1] $NODE_DETAILS{$key}[2] $NODE_DETAILS{$key}[3] "
                     . "$NODE_DETAILS{$key}[4] $NODE_DETAILS{$key}[5] $NODE_DETAILS{$key}[6] $NODE_DETAILS{$key}[7] "
                     . "$NODE_DETAILS{$key}[8] $NODE_DETAILS{$key}[9] $NODE_DETAILS{$key}[10] $NODE_DETAILS{$key}[11] "
                     . "$NODE_DETAILS{$key}[14] $NODE_DETAILS{$key}[15]\n";
  }
  close TEMP_FN;
  chmod 0774, $temp_fn;
  if($debug>=0) {print STDERR "  created $nlines lines of $temp_fn from $n lines of $nodes_fn\n";}
  return($nlines);    
}

sub pingit {
  #Pings the node given in the argument, returns:
  # 0 if host not found
  # -1 if host found but 100% packet loss
  # +1 if host found and some packets respond
  my $target=$_[0];
  if($target =~ //) {
    my $debugging=1;
  }
  my $cmd;
  if($^O =~ /linux/)   {$cmd="ping -c 5 $target";}
  else                 {$cmd="ping -s $target 64 2";}
  if($debug>1) {print STDERR "Executing $cmd for node $nodes...\n";}
  our @ans=`$cmd`;
  my $found=0; $noresponse=0;
  if($?/256 == 2) {$found=0;} 
  if(!defined($ans[0])) {return($found);}
  $ans[0]=~s/\s+/ /g;
  $mismatch_type="Incorrect database entry, ping gives '$ans[0]'";
  my $echoes=0;
  LINES:
  foreach my $aline (@ans) {
    $aline=~s/\s+/ /g;#Remove un-necessary spaces
    if($aline=~/transmitted/) {
      $found=1;
      if($aline=~/100%/) {$noresponse=1; $noresp_type="100% loss in '$aline'";}
    }
    if(!$noresponse) {
      #Extract IP address out of:
      #PING b.root-servers.net (192.228.79.201) 56(84) bytes of data.
      # or
      #72 bytes from www.unimelb.edu.au (128.250.6.182): icmp_seq=1. time=201. ms
      #Watch out for reversed address as below (so insist on the :):
      #64 bytes from 26.41.79.202.dsl.static.wlink.com.np (202.79.41.26): icmp_seq=0 ttl=42 time=669 ms
      #64 bytes from 17.15.113.217.auto.web.am (217.113.23.17): icmp_seq=21 ttl=39 time=493 ms
      if($aline=~/\({1,1}(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\){1,1}/) {
        $found=1;
        if(($1 ne $actual_addr) && ($actual_addr ne "unknown")) {#Change of IP address
          #Check if report from intermediate host, if so not a true redirect, and we are done
          my $new_address=$1;
          if($aline=~/Unreachable/) {$nunreach++; $noresp_type="unreachable in '$aline'"; $noresponse=1; last LINES;}
          elsif($aline=~/filtered/) {$nfilter++;  $noresp_type="filtered in '$aline'";    $noresponse=1; last LINES;} 
          elsif($aline=~/exceeded/) {$nexceed++;  $noresp_type="TTL exceed in '$aline'";  $noresponse=1; last LINES;}
          else {
            $nredirect++;
            $mismatch_type="Redirect in '$ans[0]' and '$aline'";
            print "  Redirect: ($nredirect) for $target($address) between $actual_addr & $new_address"
                . " in '$ans[0]' & '$aline'\n";
          }
        } # if $1 ne $actual_addr
        $actual_addr=$1;
        if($aline=~/64 bytes from /) {#Is it an echo?
          $echoes++;
          if($aline=~/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\./) {
            #Address followed by period in name, probably a temporary address, e.g. DSL
            if($echoes==1) {#Only report for first echo
              print "  Temporary: (name_addr=$1/actual=$actual_addr) in $aline\n";
              $temporarys++;
            }
          } # if aline =~ "64 bytes from" & numerical IP
        } # if aline =~ numerical ip 
      } # if aline =~ "64 bytes from" 
    } # if aline =~ (numerical ip)
    if(($aline=~/^rtt /) || ($aline =~ /^round-trip/)) {
          my ($pre,$post)=split /=/,$aline;
          ($minrtt,$post)=split'/',$post;
          $minrtt=~s/^\s+//;
          if($minrtt>500){$satellites++;}
          $minrtt.="ms";
          $found=1;
    }
    if($aline =~ /^PING /) {
      $found=1;
      if($^O =~ "linux") {
        #Extract actual address out of:
        #PING dns.iiardd.mr (193.220.169.67) 56(84) bytes of data.
        if($aline =~ /^PING\s+[\w+|.]+\s+\((\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\)/) {
          $actual_addr=$1;
        }
      } else {
        if($aline =~ /^PING\s+([\w+|.]):\s+/) {
          $actual_addr=$1;
        }
      } # else if $^O =~ linux
    } 
  } 
  if($noresponse) {$found=-$noresponse*$found;}
  return($found);
} # sub pingit

############################################
sub get_tulip_pwd {
  #The tulip password is available to group iepm in pinger:/u1/mysql/pws-tulip
  if($hostname ne "pinger.slac.stanford.edu") {
    die "The Tulip password is only available on pinger\n";
  }
  my $file="/u1/mysql/pws-tulip";
  unless(-e $file) {
    die "Can't read tulip password file $file: $!";
  }
  my $cmd="/bin/cat $file";
  my $pwd=`$cmd`;
  if(!defined($pwd) || $pwd eq "") {
    die "Can't read password: $!;"
  }
  chomp $pwd;
  return($pwd);
}#End sub get_tulip_pwd

__END__
