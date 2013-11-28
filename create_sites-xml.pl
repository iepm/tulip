#!/usr/local/bin/perl -I/afs/slac/package/netmon/tulip/
#!/bin/env perl
####
# @ author Qasim Bilal Lone lonex@slac.stanford.edu
######################################
#The following code is placed at the top to ensure we are able to use perl -d
#and stop things before they call other things.
my $debug; #For cronjobs use -1, for normal execution from command line use 0,
           #for debugging information use > 0, max value = 3.
if (-t STDOUT) {$debug=0;}
else           {$debug=-1;} #script executed from cronjob
use strict;
#######################################
use Template;
use DBI;
use URI::Escape;
use Sys::Hostname;
my $ipaddr=gethostbyname(hostname());
my ($a, $b, $c, $d)=unpack('C4',$ipaddr);
my ($hostname,$aliases, $addrtype, $length, @addrs)=gethostbyaddr($ipaddr,2);
my $user=scalar(getpwuid($<));
(my $progname = $0) =~ s'^.*/'';#strip path components, if any
########################################
# get options
our $help    = 0;
our $ability = 1;
##############################################
# setup db
require "/afs/slac/g/scs/net/pinger/bin/admin.pl";
our $pwd = &gtpwd('tulip');
our $db = 
          {
           'user' => 'scs_tulip_u',
          'host'  => 'mysql-node01',
          'password' => $pwd,
          'port' => '3307',
          'dbname' => 'scs_tulip',
	  };
###################Get options##################
our $templateFile = 'sites-xml.tt2';
use Getopt::Long;
my $ok = GetOptions (
		'template=s' => \$templateFile,
		'user=s'     => \$db->{user},
		'password=s' => \$db->{password},
		'host=s'     => \$db->{host},
		'db=s'	     => \$db->{dbname},
                'ability=i'  => \$ability,
		'help'	     => \$help,
	);
my $version="Version 1.1, 12/10/09; Author: Qasim Bilal; Maintainer: Les Cottrell";
if ( ! $ok || $help ) {
  my $USAGE="Creates the sites.xml TULIP configuration from a database\n" 
  . "Usage: $0 [options]\n"
  . "Options:\n"
  . "  --template=s            template file to use for xml creation\n"
  . "  --host=s                hostname of database location\n"
  . "  --port=s                port number for database\n"
  . "  --db=s                  database name\n"
  . "  --user=s                username for database\n"
  . "  --password=s            password for database\n"
  . "  --ability=i             whether to get enabled or disabled landmarks\n"
  . "                          default = $ability (1=enabled, 0=disabled)\n"
  . "  --help                  this help message\n"
  . "Purpose:
      Script to create the sites.xml file as per 
      http://confluence.slac.stanford.edu/display/IEPM/PingER+Sites+XML
      it will poll a mysql database and write out the xml file from a template. 
      all this script does is to construct a useable datastructure to populate 
      the template file and spits it out to STDOUT
   
Output:\n
  The xml file of landmarks is written to STDOUT
Examples:
  $progname > /afs/slac/www/comp/net/wan-mon/tulip/sites.xml
  $progname --ability 0 > /afs/slac/www/comp/net/wan-mon/tulip/sites-disabled.xml
  $progname --help
Version=$version
";
  print STDERR $USAGE;
  exit 1;
}
####################################################
require '/afs/slac/package/pinger/tulip/insert_sites-xml.pl';
chdir( '/afs/slac/package/pinger/tulip/');
#my $pwd=get_tulip_pwd();
require "/afs/slac/g/scs/net/pinger/bin/admin.pl";
our $pwd = &gtpwd('tulip');
$db->{'password'}=$pwd;
our $dbi = 'DBI:mysql:mysql_socket=/var/lib/mysql/mysql.sock;host=' . $db->{host} . ';port=' . $db->{port} . ';database=' . $db->{dbname};
our $dbh = DBI->connect($dbi, $db->{user}, $db->{password} )
      or  die "Could not connect to 'db->{host}': $DBI::errstr";
#my $query = 'SELECT * FROM landmarks where enabled = \'1\'';
my $query = "SELECT * FROM landmarks where enabled = '$ability'";
my $sth = $dbh->prepare( $query );
$sth->execute() or die "Could not execute query '$query'";
my $rowCount = $dbh->selectrow_array("SELECT count(*) FROM landmarks where enabled=\'1\'");

############################
# template
my $template = Template->new( { PRE_CHOMP => 1 });
my %domains = ();
while( my $row = $sth->fetchrow_hashref ) {
  
  my @serviceInterfaces = ();
  my $pingUrl = undef;
  my $tracerouteUrl = undef;
  $pingUrl = uri_escape( $row->{pingURL} ) if $row->{pingURL};
  $pingUrl =~s/%3A/:/g;
  $pingUrl =~s/%2F/\//g;
  $pingUrl =~s/%3F/?/g;
  $pingUrl =~s/%3D/=/g;
  $tracerouteUrl = uri_escape( $row->{tracerouteURL} )if $row->{tracerouteURL};
  $tracerouteUrl =~s/%3A/:/g;
  $tracerouteUrl =~s/%2F/\//g;
  $tracerouteUrl=~s/%3F/?/g;
  $tracerouteUrl =~s/%3D/=/g;
 # if ((defined $tracerouteUrl) and ($tracerouteUrl !~ /traceroute.pl/)) {
 #   $tracerouteUrl=$tracerouteUrl.'/cgi-bin/nph-traceroute.pl?';
 #   my $query = "UPDATE landmarks SET tracerouteURL=\'$tracerouteUrl\' where ipv4Addr= \'$row->{ipv4Addr}\'";
 #   my $sth = $dbh->prepare($query);
 #   $sth->execute();
 # }
  for my $key ( keys %{$row} ) {
    if($key ne 'pingURL' && $key ne 'tracerouteURL' 
     && ($row->{$key} =~ /&/) && !($row->{$key} =~ /&amp;/)) {
      #$breakpoint=1;
    }
    $row->{$key}=~s/&/&amp;/g;
  }
  my $serviceInterface = {
      	'type' => $row->{serviceInterfaceType},
    	'planetLabScript' => $row->{planetLabScript},
    	'pingURL' => $pingUrl,
    	'tracerouteURL' => $tracerouteUrl,
  };
  push @serviceInterfaces, $serviceInterface;
  # construct for template
  if($row->{institution} =~ /&/) {
    #$breakpoint=2;
  }
  my $node = {
    'id' => $row->{name},
    'domain' => $row->{domain},
    'hostName' => $row->{hostName},
    'name' => $row->{name}, # strip out domain
    'port' => {
        'ipAddress' => $row->{ipv4Addr},
              },
    # pinger specific stuff
    'serviceInterface' => \@serviceInterfaces,
    
    'tulipTier' => $row->{tulipTier},
    'tulipScalingFactor' => $row->{tulipScalingFactor},
    
    'location' => {
      'institution' => $row->{institution},
      'country' => $row->{country},
      'continent' => $row->{continent},
      'city' => $row->{city},
      'state' => $row->{state},
      'longitude' => $row->{longitude},
      'latitude' => $row->{latitude},
    },
    'comments' => $row->{comments},
  };
  
  #use Data::Dumper;
  push( @{$domains{$row->{domain}}}, $node );
}
#############################################
# setup vars and create the template
my $domainCount = scalar keys %domains;


my $vars = { 'domains' => () };
foreach my $name ( sort keys %domains ) {
  my $d = {
  	'nodes' => $domains{$name},
  	'name' => $name,
	};
  push ( @{$vars->{'domains'}}, $d );
}
my $time =  scalar(localtime); #getting the time stamp for the file
# spit out to STDOUT xml file
$template->process( $templateFile, $vars )
      || die $template->error() . "\n";
print"<!-- This file is generated for ability=$ability by ",
        "/afs/slac.stanford.edu/package/pinger/tulip/create_sites-xml.pl",
        " on $time at $hostname by $user -->\n\n";           
exit 0;

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
}
__END__
