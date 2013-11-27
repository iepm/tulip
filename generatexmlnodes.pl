#!/usr/local/bin/perl -I/afs/slac/package/netmon/tulip/ 
#!/bin/env perl
####
# @ author Qasim Bilal Lone lonex@slac.stanford.edu
# date create 07/01/2008
# Script to create actie planetlab and pingER nodes 
# it will poll a mysql database and write out the xml file from a template. 
# The output is xml file at /afs/slac.stanford.edu/www/comp/net/wan-mon/viper
###
####
# @ updated  by Faisal Zahid fzahid@slac.stanford.edu
# date create 08/31/2010
# disable-rss.xml is created for disabled nodes
###
#The following code is placed at the top to ensure we are able to use perl -d
#and stop things before they call other things.
my $debug; #For cronjobs use -1, for normal execution from command line use 0,
           #for debugging information use > 0, max value = 3.
if (-t STDOUT) {$debug=0;}
else           {$debug=-1;} #script executed from cronjob
use strict;
use Template;
use URI::Escape;
#######Get full hostname ##################
use Sys::Hostname;
my $ipaddr=gethostbyname(hostname());
my ($a, $b, $c, $d)=unpack('C4',$ipaddr);
my ($hostname,$aliases, $addrtype, $length, @addrs)=gethostbyaddr($ipaddr,2);
my $user=scalar(getpwuid($<));
my $dir ="/afs/slac.stanford.edu/www/comp/net/wan-mon/viper";
######Set up to access the Tulip database#############
use DBI;
my $pwd;
require "/afs/slac/g/scs/net/pinger/bin/admin.pl";
our $pwd = &gtpwd('tulip');
our $db = {
          'user' => 'scs_tulip_u',
          'host'  => 'mysql-node01',
          'password' => $pwd,
          'port' => '3307',
          'dbname' => 'scs_tulip',
        };
our $help = 0;
###### get options ########################
use Getopt::Long;
my $ok = GetOptions (
		'user'	=> \$db->{user},
		'password' => \$db->{password},
		'host'	=> \$db->{host},
		'db'	=> \$db->{dbname},
		'help'	=> \$help,
	);
if ( ! $ok || $help ) {
    my $USAGE="Creates the sites.xml PingER configuration from a database
       Usage: $0 [options]
        Options:
           --template=s            template file to use for xml creation
           --host=s                hostname of database location
           --port=s                port number for database
           --db=s                  database name
           --user=s                username for database
           --password=s            password for database
           --help                  this help message\n";
    print $USAGE;
    exit 1;
}
#######Create the output file####################################
my $outputFile = "active-rss.xml";
my $outputFile2 = "disable-rss.xml";
my $kmlOutputFile = "tulip_active.kml";
my $kmlOutputFile2 = "tulip_disable.kml";
my $outputFile = "active-rss.xml";
my $outputFile2 = "disable-rss.xml";
my $kmlOutputFile = "tulip_active.kml";
my $kmlOutputFile2 = "tulip_disable.kml";
open(OUTFILE, ">$dir/$outputFile") or die "Can't open $outputFile: $!";
if($debug>=0) {print "opened OUTFILE  > $dir/$outputFile\n";}
open(OUTFILE2, ">$dir/$outputFile2") or die "Can't open $outputFile2: $!";
if($debug>=0) {print "opened OUTFILE2 > $dir/$outputFile2\n";}
open(OUTKML, ">$dir/$kmlOutputFile") or die "Can't open $kmlOutputFile: $!";
if($debug>=0) {print "opened OUTKML   > $dir/$kmlOutputFile\n";}
open(OUTKML2, ">$dir/$kmlOutputFile2") or die "Can't open $kmlOutputFile2: $!";
if($debug>=0) {print "opened OUTKML2  > $dir/$kmlOutputFile2\n";}
#commented by Fida on 11/20/09 to check whether file is being opened in append mode or not 
#open (OUTFILE, ">>$dir/$outputFile") or die "Can't open $outputFile: $!";
###### Populate headers for the files#######################################                                                                                                                                                                                       
print OUTFILE '<?xml version="1.0"?>                                                                                                                                                   
<rss version="2.0" xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#" xmlns:dc="http://purl.org/dc/elements/1.1/">                                                                   
<channel>                                                                                                                                                                              
<title>TULIP PlanetLab Landmarks</title>                                                                                                                                               
<link>http://www.slac.stanford.edu/comp/net</link>                                                                                                                                     
<description>PlanetLab Landmarks</description>';                    
print OUTFILE2 '<?xml version="1.0"?>                                                                                                                                                   
<rss version="2.0" xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#" xmlns:dc="http://purl.org/dc/elements/1.1/">                                                                   
<channel>                                                                                                                                                                              
<title>TULIP PlanetLab Landmarks</title>                                                                                                                                               
<link>http://www.slac.stanford.edu/comp/net</link>                                                                                                                                     
<description>PlanetLab Landmarks</description>';
print OUTKML '<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
<Style id="PlanetLabIcon">
      <IconStyle>
         <Icon>
            <href>http://www.slac.stanford.edu/comp/net/wan-mon/viper/yellow_MarkerA.png</href>
         </Icon>
      </IconStyle>
</Style>
<Style id="PingERIcon">
      <IconStyle>
         <Icon>
            <href>http://www.slac.stanford.edu/comp/net/wan-mon/viper/pink_MarkerA.png</href>
         </Icon>
      </IconStyle>
</Style>
';
####### setup db############
#connect
my $dbi = 'DBI:mysql:mysql_socket=/var/lib/mysql/mysql.sock;host=' 
        . $db->{host} . ';port=' . $db->{port} . ';database=' . $db->{dbname};
my $dbh = DBI->connect($dbi, $db->{user}, $db->{password} )
	or die "Could not connect to 'db->{host}': $DBI::errstr";
my $query  = 'SELECT * FROM landmarks where enabled = \'1\'';
my $query2 = 'SELECT * FROM landmarks where enabled = \'0\'';
#my $query = 'SELECT * FROM landmarks where enabled = 1 and serviceInterfaceType like \'PingER\'';
my $sth = $dbh->prepare( $query );
$sth->execute() or die "Could not execute query '$query'";
if($debug>=0) {print "Successfully $query from Tulip database\n";}
my $sth2 = $dbh->prepare( $query2 );
$sth2->execute() or die "Could not execute query '$query2'";
# template
my $template = Template->new( { PRE_CHOMP => 1 });
my %domains = ();
my $rowCount  = $dbh->selectrow_array("SELECT count(*) FROM landmarks where enabled=\'1\' and hostName like '%pinger.slac.stanford.edu%'");
my $rowCount2 = $dbh->selectrow_array("SELECT count(*) FROM landmarks where enabled=\'0\' and hostName like '%pinger.slac.stanford.edu%'");
############### Process the Enabled landmarks #######################
my $nenabled=0;
while( my $row = $sth->fetchrow_hashref ) {
  if($row->{hostName} =~ /pinger\.slac\.stanford\.edu/){
    my $found =0;
  }
  $nenabled++;
  if($debug>=0) {
    print "($nenabled) found $row->{serviceInterfaceType} landmark $row->{hostName} in Tulip DB enabled hosts\n";
  }
  print OUTFILE "<item>\n";                                                                                                                                                          
  print OUTKML "<Placemark>\n"
             . "<name>" . $row->{hostName}."</name>\n"
             . "<description>" . $row->{serviceInterfaceType} . "</description>\n";
  if ($row->{city} eq "") { 
    print OUTFILE "<title>".$row->{country} ."</title>\n".
                  "<link>". $row->{pingURL} . "</link>\n".
                  "<lat>". $row->{latitude} . "</lat>\n".
                  "<lon>". $row->{longitude} . "</lon>\n".
                  "<host>". $row->{hostName} . "</host>\n".
                  "<region>". $row->{continent} . "</region>\n".
                  "<type>".$row->{serviceInterfaceType}."</type>\n";
    if($row->{serviceInterfaceType} =~ /PlanetLab/){
      print OUTFILE  "<subject>aPl</subject>\n";                                                                                                                  
      print OUTKML "<styleUrl>#PlanetLabIcon</styleUrl>";
    }
    else{
      print OUTFILE  "<subject>aPingER</subject>\n";
      print OUTKML "<styleUrl>#PingERIcon</styleUrl>";
    } 
  }                                                                                                                                                                                  
  else {                                                                                                                                                                             
    print OUTFILE "<title>". $row->{city}. "_" . $row->{country} . "</title>\n".                                                                                                                    
                  "<link>". $row->{pingURL} . "</link>\n".
                  "<lat>". $row->{latitude} . "</lat>\n".
                  "<lon>". $row->{longitude} . "</lon>\n".
                  "<host>". $row->{hostName} . "</host>\n".
                  "<region>". $row->{continent} . "</region>\n".                                                                                                                               
                  "<type>".$row->{serviceInterfaceType}."</type>\n";
    if($row->{serviceInterfaceType} =~ /PlanetLab/){
      print OUTFILE  "<subject>aPl</subject>\n";
      print OUTKML "<styleUrl>#PlanetLabIcon</styleUrl>";
    }                     
    if($row->{serviceInterfaceType} =~ /PerfSONAR/){
      print OUTFILE  "<subject>aPerf</subject>\n";
      print OUTKML "<styleUrl>#PlanetLabIcon</styleUrl>";
    }                                                                                                             
    if($row->{serviceInterfaceType} =~ /PingER/){
      print OUTFILE  "<subject>aPingER</subject>\n"; 
      print OUTKML "<styleUrl>#PingERIcon</styleUrl>";
    }
  }
  print OUTKML "<Point><coordinates>" . 
               $row->{longitude}.","  .
               $row->{latitude}.",0</coordinates></Point>\n";
  print OUTKML "</Placemark>\n";
  print OUTFILE "</item>\n";                                                   
}
################Now do Disabled landmarks $#######################
while( my $row2 = $sth2->fetchrow_hashref ) {
  if($row2->{hostName} =~ /pinger\.slac\.stanford\.edu/){
    my $found =0;
  }
  print OUTFILE2 "<item>\n";                                                                                                                                                          
  print OUTKML2 "<Placemark>\n"
              . "<name>" . $row2->{hostName}."</name>\n"
              . "<description>" . $row2->{serviceInterfaceType} . "</description>\n";
  if ($row2->{city} eq "") { 
    print OUTFILE2 "<title>".$row2->{country} ."</title>\n".
                   "<link>". $row2->{pingURL} . "</link>\n".
                   "<lat>". $row2->{latitude} . "</lat>\n".
                   "<lon>". $row2->{longitude} . "</lon>\n".
                   "<host>". $row2->{hostName} . "</host>\n".
                   "<region>". $row2->{continent} . "</region>\n".
                   "<type>".$row2->{serviceInterfaceType}."</type>\n";
    if($row2->{serviceInterfaceType} =~ /PlanetLab/){
      print OUTFILE2  "<subject>dPl</subject>\n";                                                                                                                  
      print OUTKML2 "<styleUrl>#PlanetLabIcon</styleUrl>";
    }
    else{
      print OUTFILE2  "<subject>dPingER</subject>\n";
      print OUTKML2 "<styleUrl>#PingERIcon</styleUrl>";
    }                                                                                                                                     
  }                                                                                                                                                                                  
  else {                                                                                                                                                                             
    print OUTFILE2 # "<title>". $row2->{city}. "_" . $row2->{country} . "</title>\n".                      
          "<title>".$row2->{country} ."</title>\n".                                                                                          
          "<link>". $row2->{pingURL} . "</link>\n".
          "<lat>". $row2->{latitude} . "</lat>\n".
          "<lon>". $row2->{longitude} . "</lon>\n".
          "<host>". $row2->{hostName} . "</host>\n".
          "<region>". $row2->{continent} . "</region>\n".                                                                                                                               
          "<type>".$row2->{serviceInterfaceType}."</type>\n";
    if($row2->{serviceInterfaceType} =~ /PlanetLab/){
      print OUTFILE2  "<subject>dPl</subject>\n";
      print OUTKML2 "<styleUrl>#PlanetLabIcon</styleUrl>";
    }                     
    if($row2->{serviceInterfaceType} =~ /PerfSONAR/){
      print OUTFILE2  "<subject>dPerf</subject>\n";
      print OUTKML2 "<styleUrl>#PlanetLabIcon</styleUrl>";
    }                                                                                                             
    if($row2->{serviceInterfaceType} =~ /PingER/){
      print OUTFILE2  "<subject>dPingER</subject>\n"; 
      print OUTKML2 "<styleUrl>#PingERIcon</styleUrl>";
    }
  }
  print OUTKML2 "<Point><coordinates>" . $row2->{longitude}.",".$row2->{latitude}.",0</coordinates></Point>\n";
  print OUTKML2 "</Placemark>\n";
  print OUTFILE2 "</item>\n";                                                   
}
print OUTFILE "</channel>\n";                                                                                                                                                          
print OUTFILE "</rss>\n";                                                                                                                                                              
print OUTKML  "</Document></kml>\n";
close OUTKML  or die "Can't close OUTKML: $!";
close OUTFILE or die "Can't close OUTFILE: $!";  
print OUTFILE2 "</channel>\n";                                                                                                                                                          
print OUTFILE2 "</rss>\n";                                                                                                                                                              
print OUTKML2  "</Document></kml>\n";
close OUTKML2  or die "Can't close OUTKML2: $!";
close OUTFILE2 or die "Can'r close OUTFILE2: $!";         
exit;
