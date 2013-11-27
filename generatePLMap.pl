#!/usr/local/bin/perl -w
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
#
# Updated by: Fahad Ahmed Satti
# Date: 11/20/2009
#
#The following code is placed at the top to ensure we are able to use perl -d
#and stop things before they call other things.
my $debug; #For cronjobs use -1, for normal execution from command line use 0,
           #for debugging information use > 0, max value = 3.
if (-t STDOUT) {$debug=0;}
else           {$debug=-1;} #script executed from cronjob

require Text::CSV_XS;
my $csv = Text::CSV_XS->new;
#use lib "/afs/slac/package/pinger/tulip/";
#use TULIP::ANALYSIS::NODEDETAILNODES;
use strict;
use DBI;
use Encode;
umask(0002);
use Sys::Hostname;
my $ipaddr = gethostbyname(hostname());
my ($hostname, $aliases, $addrtype, $length, @addrs) =
  gethostbyaddr($ipaddr, 2);
my $user = scalar(getpwuid($<));
(my $progname = $0) =~ s'^.*/'';    #strip path components, if any
#my $cmd = "wget --tries=5 --timeout=30 --wait=120 \'http://www.scriptroute.org:3967/\' 2>&1";
##################################################
##Changing wget command to not download the file, rather keep it in a variable.
##This would also save us a file read. The option '-O -' to wget command outputs
##all the data on StdOut.
#################################################
my $cmd = "wget --tries=5 --timeout=30 --wait=120 --no-verbose --quiet 'http://www.scriptroute.org:3967/' -O - ";
if( $cmd =~ /^([a-zA-Z0-9\'\-\_\+\&\/\?\.\:\=\s]+)$/i ){
  $cmd = $1;
}
else{
  print "Error while untainting the wget command<br/>";
  print $cmd;
  exit;
}
#wget command processing complete.
####################################################

my $regions_fn="/afs/slac/g/www/www-iepm/pinger/region_country.txt";
my $version="0.1, 5/13/07";
#my $dir        = "/afs/slac.stanford.edu/package/netmon/tulip/sitesxml";
my $dir ="/afs/slac.stanford.edu/www/comp/net/wan-mon/viper";
my $tulipDir = "/afs/slac/package/pinger/tulip";
#  ....................................................................
my $USAGE = "Usage:\t $progname [opts]
  Gets a list of PlanetLab host using:
  $cmd
  Then for each site it gets the country, region, lat/long and writes it to
  a file in $dir
  The region for each country is obtained from $regions_fn
Examples:
 $progname
Version=$version
";
#  Please send comments and/or suggestion to Les Cottrell.
#
# ****************************************************************
# Owner(s): Les Cottrell (7/13/04).
# Revision History:
# ****************************************************************
##########Get the list of PlanetLab servers####################
#my @ans = `$cmd`;
#if (!defined($ans[4]) || !$ans[4] =~ /200 OK/) {
#  print scalar(localtime())
#    . "$progname on $hostname for $user failed using $cmd with:\n"
#    . @ans;
#  exit 100;
#}
my $timeStamp = scalar(localtime()) . "\n";
#open(INFILE, "index.html") or die "Can't open index.html: $!";
#@ans = <INFILE>;
#close INFILE;
my @ans = `$cmd`;
if($debug>=0){
  print "#".scalar(localtime())
      . " $progname:read ".scalar(@ans)." lines\n";
}

###Get the region for each country from $regions_fn file######
my %regions;
get_regions($regions_fn);

#######Create the output file####################################
my $outputFile = "pl-rss.xml";
open(OUTFILE, ">$dir/$outputFile") or die "Can't open $dir/$outputFile: $!";

print OUTFILE '<?xml version="1.0" ?>'.
'<rss version="2.0" xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#" xmlns:dc="http://purl.org/dc/elements/1.1/">'.
'<channel>'.
'<title>TULIP PlanetLab Landmarks</title>'.
'<link>http://www.slac.stanford.edu/comp/net</link>'.
'<description>PlanetLab Landmarks</description>';

###For each PlanetLabs host get the country, region, lat/long##
my $i = 0;
my %landmarks_per_region;
my %landmarks_per_country;
foreach my $line (@ans) {
  if ($line =~ /<td align="center"><a href/) {
    $line = toutf8("iso-8859-1",$line);
    my @array = split(/>/, $line);
    my $junk  = $array[2];
    my @ip    = split(/</, $junk);
    my ($country, $countrycode, $city, $latitude, $longitude, $host) = 
       ("",       "",           "",    "",        "",         "");
    my $fail=&geoplot_countryinfo($ip[0], \$country, \$countrycode, \$city,
      \$latitude, \$longitude, \$host);
    if($fail==100) {
      print OUTFILE "#$progname: terminated, "
          . "Temporary failure in Name resolution for www.geoiptool.com\n";
      last;
    }
    $country =~ s/\s+//;
    $city    =~ s/\s+//;
    if($country eq "") {
      $country="?";
    }

    my $region="?";
    if($country eq "UnitedStates") {
      $region="northamerica";
    }
    elsif(defined($regions{$country})) {
      $region=$regions{$country};
    }
    elsif ($country=~/^Russia/) {$region="Russia";}
    elsif ($country=~/^UnitedK/){$region="Europe";}
    elsif ($country=~/^Czech/)  {$region="Europe";}
    elsif ($country=~/^Korea/)  {$region="EastAsia";}
    else {$region="?";}
    $landmarks_per_region{$region}++;
    $landmarks_per_country{$country}++;
    $i++;
    if ($debug >= 0) { print "($i)$host($ip[0]) in $country in $region\n"; }
    print OUTFILE "<item>";
    if ($city eq "") {
      print OUTFILE "<link>".$country ."</link>".
                    "<title>". $ip[0] . "</title>".
                    "<lat>". $latitude . "</lat>".
                    "<lon>". $longitude . "</lon>".
                    "<host>". $host . "</host>".
                    "<region>". $region . "</region>".
			"<type>planetlab</type>".
                    "<subject>planetlab</subject>\n";
    }
    else {
      print OUTFILE "<link>". $city . "_" . $country . "</link>".
                    "<title>". $ip[0] . "</title>".
                    "<lat>". $latitude . "</lat>".
                    "<lon>". $longitude . "</lon>".
                    "<host>". $host . "</host>".
                    "<region>". $region . "</region>".
		    "<type>planetlab</type>".
                    "<subject>planetlab</subject>\n";
    }
    print OUTFILE "</item>\n";
  } ## end if ($line =~ /<td align="center"><a href/)
} ## end foreach my $line (@ans)
############### Getting data from Database to write in pl-rss.xml
############ DB Operations
############# DB variables
#my $pwd = get_tulip_pwd();
require "/afs/slac/g/scs/net/pinger/bin/admin.pl";
our $pwd = &gtpwd('tulip');
my %db = (
                'user' => 'tulip',
                'host'  => 'localhost',
                'password' => $pwd,
                'port' => '1000',
                'dbname' => 'tulip',
        );
######################################
my $dbi = 'DBI:mysql:mysql_socket=/var/lib/mysql/mysql.sock;host=' . $db{host} . ';port=' . $db{port} . ';database=' . $db{dbname};
my $dbh = DBI->connect($dbi, $db{user}, $db{password} )
        or die "Could not connect to '$db{host}': $DBI::errstr";
my $query = 'SELECT * FROM landmarks where serviceInterfaceType = \'PingER\'';
my $sth = $dbh->prepare( $query );
$sth->execute() or die "Could not execute query '$query'";
while( my $row = $sth->fetchrow_hashref ) {
  print OUTFILE "<item>\n";                                                                                                                                    
    if ( !defined($row->{country} )) {
      $row->{country}="?";
    }       
    if (!defined($row->{city})||!exists($row->{city})||$row->{city} eq ""){                                                                                                                                
      print OUTFILE "<title>".$row->{country} ."</title>".                                                                              
                    "<link>". $row->{tracerouteURL} . "</link>".                                                                                               
                    "<lat>". $row->{latitude} . "</lat>".                                                                                                   
                    "<lon>". $row->{longitude} . "</lon>".                                                                                                  
                    "<host>". $row->{hostName} . "</host>".
                    "<region>". $row->{continent} . "</region>".
                    "<type>".$row->{serviceInterfaceType}."</type>".
                    "<subject>pingER</subject>\n";
    }                                                                                                                                                         
    else {                       
      print OUTFILE "<link>". $row->{tracerouteURL}. "</link>".                                                                              
                    "<title>". $row->{city}."-".$row->{country} . "</title>".
                    "<lat>". $row->{latitude} . "</lat>".
                    "<lon>". $row->{longitude} . "</lon>".
                    "<host>". $row->{hostName} . "</host>".
                    "<region>". $row->{continent} . "</region>".                                                                                            
                    "<type>".$row->{serviceInterfaceType}."</type>".
                    "<subject>pingER</subject>\n";
    }                                                                                                                                                        
  print OUTFILE "</item>\n";
}
#####
#Reading file for target
open(MYDATA, "$tulipDir/Initial.txt") or 
  die("Error: cannot open file $tulipDir/Initial.txt\n");
my $line;
my $lnum = 1;
while( $line = <MYDATA> ){
  chomp($line);
  my @targets = split //,$line; # split on 1 or more spaces
  print OUTFILE "<item>".                                                                                                                                                      
                "<link>".$targets[1]."</link>".                                                                                                                         
                        "<title>".$targets[1]."</title>".                                                                                                                                  
                        "<lat>".$targets[2]."</lat>".                                                                                                                                       
                        "<lon>".$targets[3]."</lon>".                                                                                                                                      
                        "<host>".$targets[1]."</host>".                                                                                                                                    
                        "<region>North America</region>".                                                                                                                              
                        "<type>target</type>".                                                                                                                                       
                        "<subject>Target</subject>\n";                                                                                                                                 
        print OUTFILE "</item>\n";                                     
  if($debug>=0) {print "$lnum: $line\n";}
  $lnum++;
}
close MYDATA;

print OUTFILE "</channel>";
print OUTFILE "</rss>";
close OUTFILE;
if($debug>=0) {
  foreach my $key (sort keys %landmarks_per_country) {
    print "Country=$key has $landmarks_per_country{$key} landmarks\n";
  }
  foreach my $region_key (sort keys %landmarks_per_region) {
    print "Region=$region_key has $landmarks_per_region{$region_key} landmarks\n";
  } 
}
`rm -f index.html`;
exit 0;

sub geoplot_countryinfo
{
  #$_[0] ip address of the host
  #$_[1] reference to a variable in which to store the Country
  #$_[2] reference to a variable in which to store the Country code
  #$_[3] reference to a variable in which to store the City
  #$_[4] reference to a variable in which to store the latitude
  #$_[5] reference to a variable in which to store the longitude
  my $ref_country     = $_[1];
  my $ref_countrycode = $_[2];
  my $ref_city        = $_[3];
  my $ref_latitude    = $_[4];
  my $ref_longitude   = $_[5];
  my $ref_host        = $_[6];
  my $fail=0;
  my $fn = "index.html?IP=$_[0]";
  if (-e $fn) {
    `rm $fn`;
  }
  my $host_status="off";
  my $cmd = "wget \'http://www\.geoiptool\.com/en/?IP=$_[0]\' 2>&1";
  my @ans=`$cmd`;
  #if(!defined($ans[4]) || $ans[4]!~/200 OK/) {
  #  print "Cmd=$cmd failed with\n@ans";
  #  $fail=1;
  #  if($ans[$#ans] =~ /Temporary failure in name resolution./) {$fail=100;}
  #  return $fail;
  #}
  open(INFILE, $fn) or die "Can't open $fn: $!";
  @ans = <INFILE>;
  close INFILE;
  `rm $fn`;
  my $countrycode_status = 'off';
  foreach my $line (@ans) {
    $line = toutf8("iso-8859-1",$line);

    if ($countrycode_status eq 'on') {
      $line =~
        m/<td align=\"left\" class=\"arial_bold\">(\w*) \(\w*\)<\/td>/;
      $$ref_countrycode   = $1;
      $countrycode_status = 'off';
      next;
    }
    if ($line =~ /<td align="right"><span class="arial">Country code/) {
      $countrycode_status = 'on';
      next;
    }
    if ($host_status eq 'on') {
      $line =~ m/<td align=\"left\" class=\"arial_bold\">(\w*)<\/td>/;
      my ($junk, $rest)  = split(/>/, $line);
      my ($host, $junk2) = split(/</, $rest);
      $$ref_host   = $host;
      $host_status = 'off';
      next;
    }
    if ($line =~ /<td align="right"><span class="arial">Host Name:/) {
      $host_status = 'on';
      next;
    }
    if ($line =~
/var point = new GPoint\((-{0,1}\d{1,3}\.{0,1}\d{0,}), (-{0,1}\d{1,3}\.{0,1}\d{0,})\)/
      )
    {
      $$ref_latitude  = $2;
      $$ref_longitude = $1;
      next;
    }
    if ($line =~ /var marker = createMarker/) {
#      my @temp = $line =~ m/<\/strong>: (\w*\s*\w*)<br>/g;#Fails on Unicode chars such as umlaughts.
      my @temp=split(/strong>: /,$line);
      ($$ref_city,undef)    = split(/<br>/,$temp[1]);
      ($$ref_country,undef) = split(/<br>/,$temp[2]);
#      if($$ref_country =~ /Korea, Rep/) {$$ref_country="Korea Rep";}
    }
  } ## end foreach $line (@ans)
  return $fail;
} ## end sub geoplot_countryinfo

sub get_timestamp
{
  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
    localtime(time);
  if ($mon < 10)  { $mon  = "0$mon"; }
  if ($hour < 10) { $hour = "0$hour"; }
  if ($min < 10)  { $min  = "0$min"; }
  if ($sec < 10)  { $sec  = "0$sec"; }
  $year = $year + 1900;

  return $year . '_' . $mon . '_' . $mday . '__' . $hour . '_' . $min
    . '_'
    . $sec;
} ## end sub get_timestamp

sub get_regions {
  my $fn=$_[0];
  open(REGIONS, "$fn") or die "Can't open $fn: $!";
  my @ans = <REGIONS>;
  close INFILE;
  foreach my $line (@ans) {
    my ($pre, $post)=split(/#/,$line);
    if($pre eq "") {next;}
    my ($country, $reg)=split(/,/,$pre);
    $reg=~s/\s+//g;
    $regions{$country}=$reg;
  }
  return;
}

sub toutf8 {
#takes: $from_encoding, $text
#returns: $text in utf8
    my $encoding = shift;
    my $text = shift;
    if ($encoding =~ /utf\-?8/i) {
        return $text;
    }
    else {
        $text =  Encode::encode("utf8", Encode::decode($encoding, $text));
        return $text;
    }
}      

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
