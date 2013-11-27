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
# Copyright (c) 2008
# The Board of Trustees of
# the Leland Stanford Junior University. All Rights Reserved.

#The following code is placed at the top to ensure we are able to use perl -d
#and stop things before they call other things.
my $debug; #For cronjobs use -1, for normal execution from command line use 0,
           #for debugging information use > 0, max value = 3.
if (-t STDOUT) {$debug=0;}
else           {$debug=-1;} #script executed from cronjob
use strict;
use Encode;
umask(0002);
use Sys::Hostname;
require Text::CSV_XS; # Perl Standard package to generate the csv data

my $csv = Text::CSV_XS->new();#Creating new object for csv
my @parsedData; #will contain the csv data
my @dataList ;
my $ipaddr = gethostbyname(hostname());
my ($hostname, $aliases, $addrtype, $length, @addrs) =
   gethostbyaddr($ipaddr, 2);
my $user = scalar(getpwuid($<));
(my $progname  = $0) =~ s'^.*/'';    #strip path components, if any
my $plservers  = "index.html";
#my $cmd="wget --tries=5 --timeout=30 --wait=120 --output-document=$plservers \'http://www.scriptroute.org:3967/\' 2>&1";
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
my $regions_fn = "/afs/slac/g/www/www-iepm/pinger/region_country.txt";
my $version    = "0.2, 6/15/2010, Qasim Lone & Les Cottrell";
my $dir        = "/afs/slac/package/pinger/tulip/sitesxml";
my $outputFile = "Sites-" . get_timestamp();
#  ....................................................................
my $USAGE = "Usage:\t $progname [opts]
opts:
    -v Prints this output as a usage guide
    -D sets the debug option (default from command line is $debug (from
       a cronjob it is -1)
Method:
  Gets a list of PlanetLab servers using:
  $cmd
  Then for each site it gets the country, region, lat/long and writes it to
  a file.
  It gets the country, city and lat/long using www.geoiptool.com
  The region for each country is obtained from $regions_fn

Time: It takes about 10 minutes to run.
";

#Input: is a PlanetLabs servers list file called $plservers that is created using: 
#  $cmd

$USAGE = $USAGE . "
Output: to $dir/$outputFile comma separated. There may also be comments (preceded by a #):
 zurich,Switzerland,192.33.90.195,47.3667,8.55,planetlab01.ethz.ch,Europe
 Lawrence,\"United States\",129.237.161.194,38.9525,-95.2756,kupl2.ittc.ku.edu,NorthAmerica

Examples:
 $progname

Version=$version
";
#  Please send comments and/or suggestion to Les Cottrell.
#
# ****************************************************************
# Owner(s): Qasim Lone & Les Cottrell (7/13/08).
# Revision History:
# ****************************************************************

###################Process options############################
require "getopts.pl";
our ($opt_v, $opt_D)=("", "");
&Getopts('vD:');
if($opt_v) {
  print "$USAGE";
  exit 1;
}
if($opt_D)  {$debug=$opt_D;}
##########Get the list of PlanetLab servers####################
#my @ans = `$cmd`;
#if (!defined($ans[4]) || !$ans[4]=~/200 OK/ || $ans[6]=~/Disk quota exceeded/) {
#  print "$progname on $hostname for $user failed executing\n"
#    . " $cmd\n"
#    . " resulting in:\n";
#  print @ans;
#  exit 100;
#}
##############################
#The PlanetLabs servers list file is of the form:
#<html><head><title>Scriptroute Active Server List</title></head><body>
#This is a dynamically generated list of scriptroute servers.<br>
#321 servers are operational; 296 have announced themselves but are unverified; 285 are pending verification<br>
#<table>
#<td>
#<tr>
#<th>Address</th><th>Enclosing AS</th><th>Version</th><th>Country</th><th>Continent</th><th>Attributes</th></tr>
#<tr>
#<td align="center"><a href="http://193.136.191.26:3355/">193.136.191.26</a></td>
#<td align="center">AS 0</td>
#<td align="center">v0.4.9</td>
#<td align="center">pt</td>
#<td align="center">eu</td>
#<td>NTP=NTP-stratum2</td>
#</tr>
my $timeStamp = scalar(localtime()) . "\n";
#open(INFILE, $plservers) or die "Can't create $plservers: $!";
#@ans = <INFILE>;
#close INFILE;
my @ans = `$cmd`;
if($debug>=0) {
  print "#".scalar(localtime())
      . " $progname: read $plservers with ".scalar(@ans)." lines\n";
}
######Get the region for each country from $regions_fn file######
my %regions;
get_regions($regions_fn);
#######Create the output file####################################
open(OUTFILE, ">:utf8",$dir."/".$outputFile) or die "Can't open >$dir/$outputFile: $!";
my $msg="#"
  . scalar(localtime())
  . " $0: created "
  . scalar(@ans)
  . " lines (excluding this line) on $hostname for $user from $cmd\n";
if($debug>=0) {print $msg;}
print OUTFILE $msg;
###For each PlanetLabs host get the country, region, lat/long##
my $i = 0;
my %landmarks_per_region;
my %landmarks_per_country;
my $nline=0;
my $hline=0;
foreach my $line (@ans) {
  $nline++;
  if($debug>2) {
    print "Found line ($hline/$nline/".scalar(@ans)."): $line\n";
  }
  if ($line =~ /<td align="center"><a href/) {
    #e.g. $line=<td align="center"><a href="http://200.129.0.161:3355/">200.129.0.161</a></td> 
    $hline++;
    chomp $line;
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
    if($country eq "" || !(defined $country)) {
      $country="?";
    }
    my $newCountry =  $country;
       $newCountry  =~ s/\s+//g;
    my $region="?";
    if(defined($regions{$country})) {
      $region=$regions{$country};
    }
    elsif ($country=~/^Russia/) {$region="Russia";}
    elsif (defined($regions{$newCountry})){$region=$regions{$newCountry};}
    else {
      $region="?";
      unless($line=~/:3355/ || $debug>=0) {
        print "Can't find region for country=$country, city=$city, ip=$ip[0] in line($nline): $line\n";
        print "used command=$cmd\n";
      }
      next;
      #exit(0);          
    }
    if($debug>1) {
      print "processing country=$country, city=$city, ip=$ip[0] in line($hline/$nline/"
           . scalar(@ans)."): $line\n";
    }
    $landmarks_per_region{$region}++;
    $landmarks_per_country{$country}++;
    $i++;
    if ($debug >= 0) { 
      print "($nline/"
        .scalar(@ans).")[$i]$host($ip[0]) in $country in $region\n"; 
    }
    #Handling diacritics: for further information please see 
    #https://confluence.slac.stanford.edu/display/IEPM/Handling+Diacritics  
    #Stripping of Unicodes within some cities like Zu?rich (where ? is an Umlauted u)
    #$city  = encode("utf-8", decode("iso-8859-1", $city));
    #$country  = encode("utf-8", decode("iso-8859-1", $country));
    #$host  = encode("utf-8", decode("iso-8859-1", $host));
    #$region  = encode("utf-8", decode("iso-8859-1", $region));
    #print "City is $city\n";
    if ($city =~ m/\xfc/){
       $city = "zurich";
    }
    if($city=~ m/\xe9/){
      $city =~ s/\xe9/e/g;
    }
    if($city =~ m/\xe1/){
      $city  =~ s/\xe1/a/g; 
    }		
    if($city =~ m/\xe3/){
      $city  =~ s/\xe3/a/g;
    }	
    if($city =~ m/\xe2/){
     $city  =~ s/\xe2/a/g;
    }
    $city  = decode_utf8($city);
    $country  = decode_utf8($country);
    #$host  = encode("utf-8", decode("iso-8859-1", $host));
    #$region  = encode("utf-8", decode("iso-8859-1", $region));
    push(@dataList ,$city, $country , $ip[0] , $latitude  , $longitude , $host , $region);
    #now combining the values for CSV
    if ($csv->combine(@dataList)) {
      my $string = $csv->string;
      push(@parsedData, "$string");
      for (my $j =0; $j<@dataList; $j++) {
      	delete $dataList[$j];
      }
      if($debug > 2){
        print "Comma separated data $csv->string is generated for line($line/$nline/".scalar(@ans).")\n";
      }     
    } 
    else {
      my $err = $csv->error_input;
      print "combine() failed on argument: $err in line ($nline)$line\n"
          . " host=$host, ip=$ip[0], region=$region, country=$country, city=$city\n";
    }
  } ## end if ($line =~ /<td align="center"><a href/)
} ## end foreach my $line (@ans)
########################################################
##### Now Parsing our data to insert in the file #######
my $finalData = '';
my $first =1;
for (my $data = 0; $data<@parsedData; $data++){
  if($first){
    $finalData = $parsedData[$data]. "\n";
    $first = 0;
  }
  else {
    $finalData = $finalData .$parsedData[$data] . "\n"; 
  }	
}
if($debug>=0) {print $finalData;}
print OUTFILE $finalData;
close OUTFILE;
if($debug>=0) {
  foreach my $key (sort keys %landmarks_per_country) {
    print "Country=$key has $landmarks_per_country{$key} landmarks\n";
  }
  foreach my $key (sort keys %landmarks_per_region) {
    print "Region=$key has $landmarks_per_region{$key} landmarks\n";
  } 
}
#`rm $plservers`;
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
    #`rm $fn`;
  }
  my $host_status="off";
  #my $cmd = "wget \'http://www\.geoiptool\.com/en/?IP=$_[0]\' 2>&1";
  my $cmd = "wget \'http://www\.geoiptool\.com/?IP=$_[0]\' 2>&1";#CHanged by Cottrell 12/14/2012
  my $ans=`$cmd`;
  if(!defined($ans) || $ans!~/200 OK/) { 
    print "Cmd=$cmd failed with\n$ans";
    $fail=1;
    if($ans =~ /Temporary failure in name resolution./) {$fail=100;}
    return $fail;
  }
  open(INFILE, $fn) or die "Attempted $cmd with result=@ans, but can't open INFILE $fn: $!";
  my @ans = <INFILE>;
  close INFILE;
  `rm $fn`;
  my $countrycode_status = 'off';
  foreach my $line (@ans) {
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
      if($$ref_country =~ /Korea, Rep/) {$$ref_country="Korea Rep";}
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
  if($debug>0) {
    print "#".scalar(localtime())." $progname: read $fn with "
        . scalar(@ans)." lines\n";
  }
  foreach my $line (@ans) {
    my ($pre, $post)=split(/#/,$line);
    if($pre eq "") {next;}
    my ($country, $reg)=split(/,/,$pre);
    $reg=~s/\s+//g;
    $regions{$country}=$reg;
  }
  return;
}      
