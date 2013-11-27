#!/usr/local/bin/perl -w
use strict;
#This Prog is TULIP utility perl file which can be used to
#recover the lost data from tulip database. The source of data recovery
# is sites.xml
#############Web stuff#################################
use XML::LibXML;
my $xmlfile= "http://www.slac.stanford.edu/comp/net/wan-mon/tulip/sites.xml";
#############DataBase Stuff#################################
use DBI;
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

#####################################################
# Read the data from sites.xml
  my $parser = new XML::LibXML;
  my $struct = $parser -> parse_file($xmlfile);
  my $rootel = $struct -> getDocumentElement;
  my @kids = $rootel -> getElementsByTagName('nmtb:domain');
  foreach my $child (@kids){
    my ($server,$longitude,$latitude,$city,$type);
    #my @s   = $child -> getElementsByTagName('pinger:pingURL');
    my @t   = $child -> getElementsByTagName('nmtb:hostName');
    $server   = $t[0]->getFirstChild->getData;
    my @r   = $child -> getElementsByTagName('nmtb:longitude');
    $longitude = $r[0]->getFirstChild->getData;
    my @c   = $child->getElementsByTagName('nmtb:latitude');
    if(defined($c[0])){
      $latitude   = $c[0]->getFirstChild->getData;
      chomp($longitude);
      
    }
#Put recover data from sites.xml to tulip database
 my $query   =  "update landmarks set latitude = \'$latitude\' , longitude = \'$longitude\' where".
                " hostName = \'$server\'";
 print "$query \n";
 my $sth = $dbh->prepare( $query );
 $sth->execute() or die "Could not execute query '$query'";

  print "$server, $latitude, $longitude\n";
  }#End foreach @kids