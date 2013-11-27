#!/usr/local/bin/perl -w


package TULIP::ANALYSIS::NODEDETAILNODES;



sub new
{
        my $className = shift;
        bless $self, $className;
	 $self->_init( );
        return $self;
}

sub _init
{
        my $self = shift;
        return $self;
}


our %NODE_DETAILS;
require '/afs/slac/package/pinger/nodes.cf';
require Text::CSV_XS;

use strict;

my $csv = Text::CSV_XS->new;
my @dataList;
my @parsedData;
#open (MYFILE, '>>data.txt');





sub getData () # This function goes through complete set of node details and returns all the nodes with traceroute servers
{
	foreach my $key (keys %NODE_DETAILS){  

	   my $nodeName  = $key ;  # Node name required for the database

	   my $institution = $NODE_DETAILS{$key}[3]; # details of the location

	   my $location = $NODE_DETAILS{$key}[4]; # Getting the location
           
           my $country = $NODE_DETAILS{$key}[5];  # Country of the nod

	   my $continent    = $NODE_DETAILS{$key}[6];

	#Now dividing the latitude and longitude  
  	my @latitudeLongitude  = split (/\s+/ , $NODE_DETAILS{$key}[7]);
 	my $lat = $latitudeLongitude[0];
  	my $long = $latitudeLongitude[1];

	#Getting PingServer Information 
	 my $pingServ = "NULL";
	if( defined $NODE_DETAILS{$key}[9] and $NODE_DETAILS{$key}[9]!~ /^\s*$/)
	{ 
		$pingServ = $NODE_DETAILS{$key}[9];
	}
	#Getting TraceServer Information
	 my $traceServ = $NODE_DETAILS{$key}[10]; 
     
        #print "$NODE_DETAILS{$key}[8]\n";
    	if(defined $traceServ and $NODE_DETAILS{$key}[8] =~ m/M/)
    	{
	chomp ($traceServ );
	if($traceServ !~ m/NOT-SET/ and $traceServ !~ /^\s*$/ and $traceServ !~ m/Not/ and $NODE_DETAILS{$key}[8] !~ m/[DZdz]/  ) # Getting all those values which 
															     #have defined tracerout servers
		{	
                        push (@dataList,"1",$institution,$location, $country , $pingServ, $traceServ, $lat, $long, $nodeName,"40", $continent);

			if ($csv->combine(@dataList)) {              
				 my $string = $csv->string;
				 push(@parsedData, "$string");
				 for (my $j =0; $j<@dataList; $j++)
				 { 
                                 delete $dataList[$j];
				 }
				 #pop(@dataList);
        		} else {
              			 my $err = $csv->error_input;
               			print "combine() failed on argument: ", $err, "\n";
         		}


			#print MYFILE "1 $location,$country  $pingServ $traceServ $lat $long $nodeName $continent \n";
			
			# print "$location $country  $pingServ $traceServ $lat $long $nodeName $continent \n\n\n\n";
			#print MYFILE  "$location\n";
		}

      }
	
  } #close of for loop	

} #close of function 


# This function gets the array and puts it in CSV format
sub csvData()
{
   getData();

return @parsedData;


} #close of parse data
1
