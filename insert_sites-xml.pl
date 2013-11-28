#!/usr/local/bin/perl -I/afs/slac/package/netmon/tulip/
#!/bin/env perl
######################################################################
#This script is used to update the tulip database based 
#on landmarks status from pingER NodeDetails database
#documentation of the script can be found at :
# https://confluence.slac.stanford.edu/display/IEPM/TULIP+Analysis
######################################################################
use lib "/afs/slac/package/pinger/tulip";
use DBI;
use   TULIP::ANALYSIS::NODEDETAILNODES;
require Text::CSV_XS;
my $csv = Text::CSV_XS->new;
chdir( '/afs/slac/package/pinger/tulip/');
use Sys::Hostname;
my $ipaddr=gethostbyname(hostname());
my ($a, $b, $c, $d)=unpack('C4',$ipaddr);
my ($hostname,$aliases, $addrtype, $length, @addrs)=gethostbyaddr($ipaddr,2);
#config db
require "/afs/slac/g/scs/net/pinger/bin/admin.pl";
our $pwd = &gtpwd('tulip');
our $db = {
          'user' => 'scs_tulip_u',
          'host'  => 'mysql-node01',
          'password' => $pwd,
          'port' => '3307',
          'dbname' => 'scs_tulip',

          };
#$db->{'password'}=get_tulip_pwd();
require "/afs/slac/g/scs/net/pinger/bin/admin.pl";
$db->{'password'}=&gtpwd('tulip');

#connect
my $dbi = 'DBI:mysql:mysql_socket=/var/lib/mysql/mysql.sock;host=' . $db->{host} . ';port=' . $db->{port} . ';database=' . $db->{dbname};
my $dbh = DBI->connect($dbi, $db->{user}, $db->{password} )
        or die "Could not connect to 'db->{host}': $DBI::errstr";
my $query ="DELETE  FROM landmarks where serviceInterfaceType = \'PingER\' and tulipTier != \'0\' and tulipTier != \'1\'";

my $sth = $dbh->prepare( $query );
$sth->execute() or die "Could not execute query '$query'";

#print $string;
for( $i =0  ; $i < @data ; $i++ ) {
  my @stuff;
  if ($csv->parse( $data[$i])) {
    @stuff = $csv->fields;
  }
  else {
    print " Data could not be parsed correctly \n";
    exit 1;
  }
  my $var = {
  	'institution' => '',
  	'country' =>  '',
        'city' => '',
  	'continent' => '',

  	'latitude' => '',
  	'longitude' => '',
  	
  	'planetLabScript' => '',
  	'pingURL' => '',
  	'tracerouteURL' => '',
  	
  	'name' => '',
  	'domain' => '',
	'hostName' => '',

  	'serviceInterfaceType' => '',
  	
  	'tulipScalingFactor' => '',
  	'tulipTier' => '',
  };
  # make temp vars to keep for remapping
  my $count = undef;
  my $myCity =undef;
  my $inst = undef
  my $ip = undef;
  my $ping = undef;
  my $trace = undef;
  my $lat = undef;
  my $long = undef;
  my $region = undef;
  my $alpha = undef;
    
  #print @stuff;
  ($tmp, $inst,$myCity,$count, $ping, $trace, $lat, $long, $host, $alpha, $region ) = @stuff;
  #print" $tmp, $inst,$myCity,$count, $ping, $trace, $lat, $long, $host, $alpha, $region\n";
   
  $var->{'pingURL'} = $ping if $ping;
  $var->{'tracerouteURL'} = $trace if $trace;
  $var->{'serviceInterfaceType'} = 'PingER';
  $var->{'tulipScalingFactor'} = $alpha if $alpha;
  $var->{'institution'} = $inst;
  $var->{'city'} = $myCity; 
  $var->{'country'} = $count; 
  # clean up CamelCase in location names
  sub cleanCamelCase {
    my $input = shift;
    my $output = $input;
    $output =~ s/([a-z])([A-Z])/$1 $2/g;
    return $output;
  }
  $var->{'city'} = cleanCamelCase($var->{'city'});
  $var->{'state'} = cleanCamelCase($var->{'state'});
  $var->{'country'} = cleanCamelCase($var->{'country'});
  # deal with node and domains
  if ( $host ) {
  	$host = lc $host;
  	$var->{hostName} = $host;
	if ( $host =~ /(\d+\.){3}\d+/ ) {
                $var->{'name'} = $host;
	} elsif ( $host =~ /([-\w]+)\.(.*)/ ) {
  		$var->{name} = $1;
  		$var->{domain} = $2;
  	}
  }

  # resolve name to IP if necessary
  if ( $host ) {
      if ( $host !~ /^\d+\.\d+\.\d+.\d+$/ and not $ip ) {
	  $iptemp = `host -t a $host`;

	  if ($? or $iptemp !~ /has address (\d+\.\d+\.\d+\.\d+)/) { 
              # host lookup fails
	      #warn "Unable to resolve $host";
	      next;
	  } else { 
	      $ip = $1;
	  }
	  
	  #print STDERR "host $host ip (len ", length($ip), ") $ip\n";
      } elsif ( $host =~ /^\d+\.\d+\.\d+\.\d+/ ) {
	  $ip = $host;
      }      
  }

  if ( $ip ) { $var->{'ipv4addr'} = $ip; }

  $var->{longitude} = $long if $long;
  $var->{latitude} = $lat if $lat;
  if ($region) {
    if ($region =~ /n(orth)?america/) { $region = 'North America'; }
    elsif ($region =~ /samerica/) { $region = 'South America'; }
    elsif ($region =~ /east_?[aA]sia/) { $region = 'East Asia'; }
    elsif ($region =~ /southasia/) { $region = 'South Asia'; }
    elsif ($region =~ /seasia/) { $region = 'S.E. Asia'; }
    elsif ($region =~ /lamerica/) { $region = 'Latin America'; }
    elsif ($region =~ /samerica/) { $region = 'South America'; }
    elsif ($region =~ /mid(dle)?east/) { $region = 'Middle East'; }
    elsif ($region =~ /africa|oceania|europe|russia/) { $region = ucfirst($region); }
  }
  $var->{'continent'} = $region;
  my @fields = ();
  my @values = ();
  while( my ($k, $v) = each %$var ) {
  	#print "   $k: $v\n";
  	next if ! defined $v or $v eq '';
  	push @fields, $k;
  	push @values, "'" . $v . "'";
  }
  $query ="SELECT * FROM landmarks where ipv4addr = \'$ip\'";
  $sth = $dbh->prepare( $query );
  $sth->execute() or die "Could not execute query '$query'";
  my $count = 0;
  while( my $row = $sth->fetchrow_hashref ) {
    #print "$query \n";
    $count = 1;
  }

  if($count == 0){
    my $sql = "INSERT INTO landmarks ( " . join( ',', @fields ) . " ) VALUES ( " . join( ',', @values ) . " )\n\n";
    my $sth = $dbh->prepare( $sql );
    $sth->execute() or die "Could not execute query '$query'";  
     #print "$sql;\n";
  }  
  pop(@stuff);
}
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

1;
