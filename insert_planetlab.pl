#!/bin/env perl

use DBI;

my $debug= 0;

#config db
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


my $query ="DELETE  FROM landmarks where serviceInterfaceType = \'PlanetLab\'";

my $sth = $dbh->prepare( $query );
$sth->execute() or die "Could not execute query '$query'";




#Opening file for parsing 
 open DataFile, "< /afs/slac.stanford.edu/package/pinger/tulip/result.txt" or die $!. "Cannot open file\n";
                                                                                                                                                                   
 if($debug >2)                                                                                                                                                                  
   {                                                                                                                                                                             
             print "Opening /afs/slac.stanford.edu/package/pinger/tulip/result.txt  for reading\n\n\n\n";                                                                       
   }                                                                                                                                                                              
   while (<DataFile>)                                                                                                                                                             
     {                                                                                                                                                                              
       if ($_ =~ /#/) # Checking for comments and ignoring them                                                                                                               
        {                                                                                                                                                                      
            if ($debug > 2)                                                                                                                                                
              {                                                                                                                                                              
                print " Neglecting the comments \n";                                                                                                                           
               }                                                                                                                                                              
          }                                                                                                                                                                      
          else                                                                                                                                                                   
          {                                                                                                                                                                      

  my $var = {
  	'country' =>  '',
        'city' => '',
  	'continent' => '',

  	'latitude' => '',
  	'longitude' => '',
  	
  	'planetLabScript' => '',
  	
  	'name' => '',
  	'domain' => '',
	'hostName' => '',

  	'serviceInterfaceType' => '',
  	
  	'tulipScalingFactor' => '',
  	'tulipTier' => '',
  };
  
  
  # make temp vars to keep for remapping
  my $country = undef;
  my $city =undef;
  my $ip = undef;
  my $lat = undef;
  my $long = undef;
  my $region = undef;
  my $alpha = undef;
  my $totalCount = undef;
  my $fileName =  undef;
  ($ip,$city,$totalCount,$country,$fileName, $lat, $long, $node, $region) = split(/,/, $_); 
	$trace = $ip;
	$var->{'pingURL'} = $ping if $ping;
	$var->{'tracerouteURL'} = $trace if $trace;
  	$var->{'serviceInterfaceType'} = 'PlanetLab';
  	$var->{'tulipScalingFactor'} = $alpha if $alpha;
 	$var->{'hostName'} = $node if $node; 
	$host = $node; 
          #$var->{'institution'} = $inst;
          $var->{'city'} = $city; 
          $var->{'country'} = $country; 
      
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
	      warn "Unable to resolve $host";
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
    if ($region =~ /[nN](orth)?[Aa]merica/) { $region = 'North America'; }
    elsif ($region =~ /samerica/) { $region = 'South America'; }
    elsif ($region =~ /[Ee]ast_?[aA]sia/) { $region = 'East Asia'; }
    elsif ($region =~ /[Ss]outhasia/) { $region = 'South Asia'; }
    elsif ($region =~ /seasia/) { $region = 'S.E. Asia'; }
    elsif ($region =~ /LatinAmerica/) { $region = 'Latin America'; }
    elsif ($region =~ /samerica/) { $region = 'South America'; }
    elsif ($region =~ /Mid(dle)?[Ee]ast/) { $region = 'Middle East'; }
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

#if($count == 0)
{
  my $sql = "INSERT INTO landmarks ( " . join( ',', @fields ) . " ) VALUES ( " . join( ',', @values ) . " )\n\n";
  my $sth = $dbh->prepare( $sql );
  $sth->execute() or die "Could not execute query '$query'";  
   print "$sql;\n";
}  

}

}

