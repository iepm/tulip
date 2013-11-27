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

(my $progname = $0) =~ s'^.*/'';    #strip path components, if any
my $version    = "0.2, 10/4/13, Raja Asad & Les Cottrell";

my $dir        = "/afs/slac/package/pinger/tulip/sitesxml";
my $regions_fn = "/afs/slac/g/www/www-iepm/pinger/region_country.txt";

my $USAGE = "Usage:\t $progname [opts]
opts:
    -v Prints this output as a usage guide
    -D sets the debug option (default from command line is $debug (from
       a cronjob it is -1)
Method:
  Gets a list of PlanetLab hosts from tulip database:
  Then for each site it gets the country, region, lat/long 
  using www.geoiptool.com
  If the result of GeoIP doesn't match that of MySQL then that 
  entry is written to /afs/slac/package/pinger/tulip/maintainPL-log.txt
Examples:
 $progname

Version=$version
";

#  Please send comments and/or suggestion to Les Cottrell.
#
# ****************************************************************
# Owner(s): Raja Asad & Les Cottrell (10/4/13).
# Revision History: The function is completely changed, now instead of updating the DB it just compares with GeoIP
# ****************************************************************
use Math::Trig ':great_circle';
use Math::Trig 'deg2rad';
use Math::Trig 'rad2deg';
use Math::Trig;
require "getopts.pl";
our ($opt_v, $opt_D)=("", "");
&Getopts('vD:');

if($opt_v) {
  print "$USAGE";
  exit 1;
}

umask(0002);
use Sys::Hostname;
my $ipaddr = gethostbyname(hostname());
my ($hostname, $aliases, $addrtype, $length, @addrs) =
  gethostbyaddr($ipaddr, 2);
my $user = scalar(getpwuid($<));
my $outputFile = "Sites-" . get_timestamp();
open (my $fh, ">/afs/slac/package/pinger/tulip/maintainPL-log.txt");
#############DataBase Stuff#################################
use DBI;
my $pwd;
require "/afs/slac/g/scs/net/pinger/bin/admin.pl";
our $pwd = &gtpwd('tulip');
our $db = {
          'user' => 'scs_tulip_u',
          'host'  => 'mysql-node01',
          'port' => '3307',
          'dbname' => 'scs_tulip',
        };
$db->{'password'} = $pwd;
#connect
my $dbi = 'DBI:mysql:mysql_socket=/var/lib/mysql/mysql.sock;host=' . $db->{host} . ';port=' . $db->{port} . ';database=' . $db->{dbname};
my $dbh = DBI->connect($dbi, $db->{user}, $db->{password} )
        or die "Could not connect to 'db->{host}': $DBI::errstr";
###################Process options############################
if($opt_D)  {$debug=$opt_D;}
#####Get the region for each country from $regions_fn file######
my %regions;
get_regions($regions_fn);
##############################################################
###For each PlanetLab host get the country, region, lat/long##
my $i = 0;
my %landmarks_per_region;
my %landmarks_per_country;
my $query   =  "select ipv4Addr,latitude,longitude,city,continent,country,hostName from landmarks where".
               " serviceInterfaceType = \'PlanetLab\' ";
if($debug >0){print "$query \n";}
my $sth = $dbh->prepare( $query );
$sth->execute() or die "Could not execute query '$query'";
my $count = 0;
my $total = 0;
#Error in lat/long in geoiptool 
my %errltln = (
   'planet01.hhi.fraunhofer.de'     => '1',
   'planet02.hhi.fraunhofer.de'     => '1',
   'planet-lab1.ufabc.edu.br'       => '1',
   'cs-planetlab3.cs.surrey.sfu.ca' => '1',
   'planetlab1.pop-mg.rnp.br'       => '1',
   'planetlab2.pop-rs.rnp.br'       => '1',
   'csplanet02.cs-ncl.net'          => '1',
   );

#############Start Checking database#########################
while( my $row = $sth->fetchrow_hashref ) {
  $count++; 
  if($debug > 0) {
    # print "$row->{rtt}($count)\t $row->{distance}\n";
  }
  my $ip    = $row->{ipv4Addr};
  my ($country, $countrycode, $city, $latitude, $longitude, $host) = 
     ("",       "",           "",    "",        "",         "");
  my $fail=&geoplot_countryinfo($ip, \$country, \$countrycode, \$city,
    \$latitude, \$longitude, \$host);
  if($fail==100) {
    print "#$progname: terminated, "
        . "Temporary failure in Name resolution for www.geoiptool.com, looking for $ip\n";
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
    #$region="?";
    print "Region $region not found for ipaddr=$ip country $country city $city\n"
        . "Exiting with error \n"; exit(0);
  }
  $landmarks_per_region{$region}++;
  $landmarks_per_country{$country}++;
  $i++;
  #if ($debug >= 0) { print "($i)$host($ip) in $country in $region\n"; }
  #Handling dicritics for further information please see 
  #https://confluence.slac.stanford.edu/display/IEPM/Handling+Diacritics  
  #Stripping of Unicodes within some cities like Zu?rich (where ? is an Umlauted u)
  #$city  = encode("utf-8", decode("iso-8859-1", $city));
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
  if(great_circle_distance(deg2rad($longitude), pi/2 - deg2rad($latitude), deg2rad($row->{longitude}), pi/2 - deg2rad($row->{latitude}), 6371) > 20){

   
      $total++;
      #####Update database with new coordinates#############
      $query   =  "update landmarks set latitude = \'$latitude\',longitude = \'$longitude\'".
                  " , city=\'$city\', country = \'$country\'".
                  " where hostName = \'$row->{hostName}\'";
      print $fh "Host: $row->{hostName}\tMySQL $row->{latitude},$row->{longitude}\tGeoIP $latitude,$longitude\n";
      
    
  }#End  if($latitude ne $row->{latitude} && $longitude ne $row->{longitude}){   
} ## end foreach my $line (@ans)
if($debug>0){print "Total nodes checked are $count\n";}
close($fh);
#######################################################
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
    `rm -f $fn`;
  }
  my $host_status="off";
  #my $cmd = "wget \'http://www\.geoiptool\.com/en/?IP=$_[0]\' 2>&1";
  my $cmd = "wget \'http://www\.geoiptool\.com/?IP=$_[0]\' 2>&1";#Changed by Cottrell 12/14/2012
  my @ans;
  @ans=`$cmd`;
  if(!defined($ans[4]) || ($ans[4]!~/200 OK/ && $ans[3]!~/200 OK/)) {
    print "Cmd=$cmd failed with\n@ans";
    my $fail=1;
    if($ans[$#ans] =~ /Temporary failure in name resolution./) {$fail=100;}
    return $fail;
  }
  open(INFILE, $fn) or die "Attempted $cmd with result @ans but can't open INFILE $fn: $!";
  @ans = <INFILE>;
  close INFILE or die "Can't close INFILE $fn: $!";;
  `rm -f $fn`;
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
/var myLatlng = new google.maps.LatLng\((-{0,1}\d{1,3}\.{0,1}\d{0,}),(-{0,1}\d{1,3}\.{0,1}\d{0,})\)/
      ){
      $$ref_latitude  = $1;
      $$ref_longitude = $2;
#      print "$_[0]\t$2,$1\n";
      next;
    }
    if ($line =~ /var contentString = /) {
#      my @temp = $line =~ m/<\/strong>: (\w*\s*\w*)<br>/g;#Fails on Unicode chars such as umlauts.
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
  foreach my $line (@ans) {
    my ($pre, $post)=split(/#/,$line);
    if($pre eq "") {next;}
    my ($country, $reg)=split(/,/,$pre);
    $reg=~s/\s+//g;
    $regions{$country}=$reg;
  }
  return;
}      
#############################################################
#Gets the data from the action=post form in geotool for the IP
#address provided in the agument.  Out of the result it extracts
#Country, CountryCode, City, Latitude, Longitude, Host
#in that order. If we failed to successfully access geotool.flagfox.com
#then the first element of the array is returned with a message starting "Error" 
#example:
# ($country, $code, $city, $lat, $long, $host)=geotool('134.79.16.9);
#
#Bugs; This function has not been fully debugged for all the anomalous
#      cases such as Country="Korea, Republic of", City="Rio de Janeiro",
#      or strange characters such as umlauts etc, or all the possible
#      error conditions.
sub geotool {
  my $cmd="curl --silent --data 'send=&ip=$_[0]' http://geotool.flagfox.net/";
  my @ans=`$cmd`;
  if ($? != 0) {
     return "Error in geotool: failure of $cmd, rc=$?: $!";
  }     
  #@searches contains the regular expressions to search on
  my @searches=(">Country<",   ">Country Code<",  ">City<",
                ">Longitude<", ">Latitude<",      '\s+Hostname\s+<', 
               );
  #@extracts provide the regular expressions to extract the values.
  #  the elements are in the same order as @searches
  my @extracts=('<b>(.+)<\/b>','\s+(.+)\&nbsp;.*',  '\s+(.+)\s*',
                '\s+(.+)\s*',  '\s+(.+)\s*',        "<b>(.+)<\/b>",    
               );
  my @results;
SEARCH:
  #For City, Latitude, Longitude, look for lines of the form:
  # <td align="left">City</td>
  # <td align="left" >
  # Istanbul
  #For country it is of the form:
  # <td align="left">Country</td>
  # <td align="left" >
  # <a href="http://en.wikipedia.org/wiki/Turkey" target="_blank" title="Wikipedia entry for Turkey"><b>Turkey</b></a>
  #For hostname it is of the form:
  # <td align="left" width="16%">
  #	Hostname				</td>
  # <td align="left" width="21%">
  #<span class="font"><a href="http://whois.domaintools.com/76-191-222-66.dsl.dynamic.sonic.net" target="blank" title="Whois information for 76-191-222-66.dsl.dynamic.sonic.net"><b>76-191-222-66.dsl.dynamic.sonic.net</b></a>
  for my $j (0 .. $#searches) {
    $results[$j]="n/a";
    for my $i (0 .. $#ans) {
      if($ans[$i] =~ /$searches[$j]/) {        
        if ($ans[$i+2]    =~ /$extracts[$j]/) {$results[$j]=$1;}
        else                                  {$results[$j]="Unknown";}           
        if($j == 3) {
          my $dbug=1;
        }
        next SEARCH;
      }#end if($ans[$i] 
    }#end for my $i        
  }#end foreach my $j
  return @results;
}
