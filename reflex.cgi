#!/usr/local/bin/perl -wT
#See https://confluence.slac.stanford.edu/display/IEPM/IEPM+Perl+Coding+Styles
#for version of perl to use.
#The following code is placed at the top to ensure we are able to use perl -d
#and stop things before they call other things.
my $debug; #For cronjobs use -1, for normal execution from command line use 0, 
           #for debugging information use > 0, max value = 3.
if (-t STDOUT) {$debug=0;}
else           {$debug=-1;} #script executed from cronjob
my $t0=time();
########################################################################
use strict;
use warnings;
$ENV{PATH} = '/usr/local/bin:/bin:/usr/bin';#Untaint the path
#Reduce the ENV variable so that the system command should not complain
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
########################################################################
my $version="0.2, Raja Asad 10/22/2013 ";
(my $progname = $0) =~ s'^.*/'';#strip path components, if any
my $threshold=80;#Max min RTT for host to be in same region as landmark
my $USAGE = "<pre>Usage:\t $progname [opts] 

Options(opts):
  These are in the form of a web type query_string (see examples below).
  the string provides a list of name=value pairs separated by & signs.
  The supported names are below  
   target=value   #name of host, eg. www.slac.stanford.edu
   debug=[-2..2]  #debug level, higher number gives more debugging info
   help           #provides this output

Purpose:
$progname is a web service wrapper for reflector.cgi. It first of all calls
reflector.cgi for tier 0 landmarks. It gets the results from the 
tier 0 landmarks synchronously and analyzes the results to see which
region the target is most likely to be in. It does this by sorting
the min RTT between the landmarks and the target, and selecting those
below $threshold. The region for these landmarks is then used to provide 
the region for a second call to reflector.cgi to use all landmarks in 
that region. The output from reflector.cgi on the second call is
aynchronous.

Examples:
 http://wanmon.slac.stanford.edu/cgi-wrap/reflex.cgi?help=1
 http://wanmon.slac.stanford.edu/cgi-wrap/reflex.cgi?debug=-1
 $progname 'help=1' #provide this output
 $progname 'target=www.pieas.edu.pk'
 time $progname 'target='www.cern.ch'
 $progname 'target=www.pieas.edu.pk&debug=-1'#Takes 194 secs
 $progname 'target=www.slac.stanford.edu&debug=-1'#Takes 144 secs
 $progname 'target=www.kek.jp&debug=-1' #takes 140secs
 $progname 'target=gamsv01.in2p3.fr&debug=0'# Takes 112 secs
 $progname 'target=wwb.pieas.edu.pk'#returns an error (unknown host)
Output:
 Stage 1 (find region):
  Locating the region for www.slac.stanford.edu

Using tier=0 PingER,perfSONAR landmarks to get a rough idea of where www.slac.stanford.edu is located so we can then use all landmarks in the region to pin down the location of www.slac.stanford.edu.
/afs/slac/g/www/cgi-wrap-bin/net/offsite_mon/reflex.cgi (step 1, locate region) calling /afs/slac/g/www/cgi-wrap-bin/net/zafar/reflector.cgi with QUERY_STRING target=www.slac.stanford.edu&type=PingER,perfSONAR&tier=0&debug=0, wait a minute...

Reflex.pl(debug=-1): result from reflector.cgi
Min RTT from landmark[0/10]users.sdsc.edu to www.slac.stanford.edu = 11ms. Landmark in region North America*
...
Min RTT from landmark[10/10]pinger.comsats.edu.pk to www.slac.stanford.edu = 325.586ms. Landmark in region South Asia
Found minimum RTT of 11 ms. from users.sdsc.edu landmark to www.slac.stanford.edu in region=North America. Time so far 54secs

 Stage 2(get landmark to target RTTs for region)
reflex.cgi: temp_file: 279calling ans=/afs/slac/g/www/cgi-wrap-bin/net/zafar/reflector.cgi with QUERY_STRING target=www.slac.stanford.edu&PingER,perfSONAR®ion=North America&debug=1 
reflex.cgi: temp_file: reports Content-type: text/html Client=134.79.230.223 probing landmarks in region=North America, tier=all, type=all, ability=1
Probing PlanetLab landmark 206.117.37.5(1/109) in region=North America(tier=all) for North America(all), so far found landmarks=0 (pl=0, sl=0, ps=0)
...
Probing PlanetLab landmark 130.73.142.87(109/109) in region=Europe(tier=all) for North America(all), so far found landmarks=80 (pl=61, sl=6, ps=13)
EventHandler->new: class= EventHandler Total landmark domains (=domain) in http://www.slac.stanford.edu/comp/net/wan-mon/tulip/sites.xml = 109, PlanetLab servers = 61, Pinger servers = 6, PerfSONAR servers = 13, landmark=all, type=all, target=134.79.18.188, tier=all, region=North America, ability=1, debug=1, version=2.5, Cottrell & Zafar 6/01/2011
Landmark(2)=http://pinger.ascr.doe.gov/cgi-bin/traceroute.pl?target=134.79.18.188&function=ping, Client=134.79.230.223, ability=1, 5 packets transmitted, 5 received, 0% packet loss, rtt min/avg/max = 79.857/79.967/80.073

Fri Jun 3 08:02:23 2011 reflex.cgi: took 154(Step 2) secs to issue /afs/slac/g/www/cgi-wrap-bin/net/zafar/reflector.cgi with QUERY_STRING target=www.slac.stanford.edu&type=PingER,perfSONAR&tier=0&debug=0
Calling /afs/slac/g/www/cgi-wrap-bin/net/zafar/reflector.cgi ...
Version=$version
";
##################################################################
# To test from command line use:
# perl -dT $progname "target=www.slac.stanford.edu"
# **************************************************************** 
#Get some useful variables for general use in code
$|=1;#Flush output buffer
umask(0002);
use Net::Domain qw(hostname hostfqdn hostdomain);
my $hostname = hostfqdn();
unless(($hostname=~/(([a-z0-9]+|([a-z0-9]+[-]+[a-z0-9]+))[.])+/)){#Name
  print "hostname=$hostname, not a valid IP name\n";
  exit 101;
}
use Socket;
my $ipaddr=inet_ntoa(scalar(gethostbyname($hostname||'localhost')));
#use Sys::Hostname; 
#my $ipaddr=gethostbyname(hostname());
#my ($a1, $b1, $c1, $d1)=unpack('C4',$ipaddr);
#my ($hostname,$aliases, $addrtype, $length, @addrs)=gethostbyaddr($ipaddr,2);
#unless(($hostname=~/(([a-z0-9]+|([a-z0-9]+[-]+[a-z0-9]+))[.])+/)#Name
#    || ($hostname=~/(\d{1,3}\.){4}/)){                          #IPv4 addr
#  print "hostname=$hostname, not a valid IP name or address\n";
#  exit 101;
#}
use DBI;
use Date::Calc qw(Add_Delta_Days Delta_Days Delta_DHMS);
use Date::Manip qw(ParseDate UnixDate);
use Time::Local;
use Time::HiRes qw( time );
#print time();exit 0;
my $user=scalar(getpwuid($<));
#############Web stuff & parameters########################
print "Content-type: text/html\n\n<html>\n";
require 'getopts.pl';
our ($opt_v)=("");
&Getopts('v');
if($opt_v) {
  print "$USAGE";
  exit 1;
}
use CGI qw/:standard/;
use HTTP::Request;
my $data = new CGI;
my $tmpdir = '/tmp/tulip/';
my $target="";
my $ucache=0;
if(defined($data->param('-v')))      {print $USAGE; exit 1;}
if(defined($data->param('help')))   {print $USAGE; exit 1;}
if(defined($data->param('debug')))  {$debug=$data->param('debug');}
if(defined($data->param('ucache')))  {$ucache=$data->param('ucache');}
if(defined($data->param('target'))) {$target=$data->param('target');}
else {
  $target='www.slac.stanford.edu'; 
  $ENV{QUERY_STRING}='target=www.slac.stanford.edu';
}
my $emsg="";
unless($target=~m/^((\d{1,3}\.){3}\d{1,3})$/) {#Is it an IPv4 addr
  unless($target=~m/^((([a-z0-9]|[a-z0-9][a-z0-9\-]{0,61}[a-z0-9])\.)+([a-z0-9]{2,5}))$/i){#IP name?
    die "target=$target, not a valid IP name or address";
  }
}
else {$target=$1;}#untaint
my $type='PingER,perfSONAR,PlanetLab';
if(defined($data->param('type')))   {$type=$data->param('type');}
unless($type=~/^([\w+,]+)$/) {
  die "Tainted invalid type=$type, must consist of alpha character and commas";
}
$type=$1;#untaint
my $cmd='/afs/slac/g/www/cgi-wrap-bin/net/zafar/reflector.cgi';
unless($cmd=~/^([\/\w+-\.]+)$/) {#untaint
  die "Tainted invalid cmd=$cmd";
}
$cmd=$1;#untaint
my $tier="tier=0";
unless($tier=~/(\w+=\d+)/) {#untaint
  die "Tainted invalid tier=$tier";
}
$tier=$1;#Untaint
##############Database of hosts########################
my $nodes_cf="/afs/slac/package/pinger/nodes.cf";
unless(-e $nodes_cf) {die "Can't find $nodes_cf: $!";}
our %NODE_DETAILS;
require "$nodes_cf";
##############Get the regions##########################
#The default for all of these except domain and ability is 'all'
#Region Examples: Africa        | Balkans     | Europe       | East Asia
#               | Latin America | Middle East | North America
#               | Oceania       | Russia      | South Asia   | S.E. Asia
my @regions=("Africa",        "Balkans",     "Europe",        "East Asia",
             "Latin America", "Middle East", "North America", "Oceania",
             "Russia"       , "South Asia",  "S.E. Asia",
            );
#The following list is of the regions that have enough landmarks to be
#assigned one or more tier 0 landmarks in the region
my $tier0_region="North America,Europe,South Asia";
#########Keep user informed######################################
my $msg="Locating the target $target";
print "<title>TULIP GEOLOCATION</title>\n<head>"
	. "<meta name=\"viewport\" content=\"initial-scale=1.0, user-scalable=no\">
    <meta charset=\"utf-8\">"
	. "<style type=\"text/css\">\n
P {
        font: italic 11pt calibri;
}
#legend {
        width=100%;
        border:1px ridge grey;
        border-radius:no;
        background-color: #ffffff;
}
#map_canvas {
    width: 100%;
    height: 300px;
        border:1px ridge grey;
        background-image:url('http://www.slac.stanford.edu/comp/net/tulip/loading2.gif');
        background-size:400px 400px;
        background-repeat:no-repeat;
        background-position:center;
}
H4{

        font: bold 12pt calibri;
}
H2{
        color:black;
}
a{
        color:darkcyan;
}
body{
        background:#ffffff;
}
#wrapper {
        margin: 0 auto;
        width: 880px;
}
#content {
        width: 100%;
}
#top {
        background:black;
        opacity:1;
        color:white;
		text-shadow: 5px 5px 5px grey;
		border-radius: 20px; 
		padding:0px;
		margin:0px;
}
#footer {
		width=100%;
        background:black;
        background: linear-gradient(#606060, black);
        bottom: 0;
        color: white;
        text-shadow: 1px 1px 1px grey;
}
#top:hover {
        background:black;
}
#top2 {
        background:#000000;
        background: linear-gradient(black, #000000);
        text-shadow: 5px 5px 5px black;
}
#feedback {
                position:fixed;
                right:5px;
}

nav {
	margin:0px
}

nav ul ul {
	display: none;
}

	nav ul li:hover > ul {
		display: block;
	}

nav ul {
	background: #efefef; 
	background: linear-gradient(top, #000000 0%, #404040 100%);  
	background: -moz-linear-gradient(top, #000000 0%, #404040 100%); 
	background: -webkit-linear-gradient(top, #404040 0%, #202020 100%); 
	box-shadow: 0px 0px 9px rgba(0,0,0,0.15);
	text-shadow: 5px 5px 5px black;
	padding: 0 20px;
	margin:0px;
	border-radius: 10px;  
	list-style: none;
	position: relative;
	display: inline-table;
	z-index:1;
	opacity:0.95;
}
	nav ul:after {
		content: \"\"; clear: both; display: block;
	}
	
nav ul li {
	float: left;
}
	nav ul li:hover {
		background: #4b545f;
		
		background: linear-gradient(top, #4f5964 0%, #5f6975 40%);
		background: -moz-linear-gradient(top, #4f5964 0%, #5f6975 40%);
		background: -webkit-linear-gradient(top, #300000 0%,#500000 40%);
	}
		nav ul li:hover a {
			color: #fff;
			
		}
	
	nav ul li a {
		display: block; padding: 15px 40px;
		margin:0px;
		color: #ffffff; text-decoration: none;
	}
	
nav ul ul {
	background:#404040; border-radius: 2px; padding: 0; 
	position: absolute; top: 100%;
}
	nav ul ul li {
		float: none; 
		border-top: 1px dashed black;
		border-bottom: 1px solid black;
		
		position: relative;
	}
		nav ul ul li a {
			padding: 15px 40px;
			color: #fff;
		}	
			nav ul ul li a:hover {
				background: #500000;
			}
			
			nav ul ul ul {
				position: absolute; left: 100%; top:0;
			}
*{
	margin:0px;
	
}
</style>"
	."<script src=\"http://maps.googleapis.com/maps/api/js?sensor=false\"></script>"
	. "<script>
	  
      function initialize() {
		var myLatlng = new google.maps.LatLng(0,0);
        var map_canvas = document.getElementById('map_canvas');
        var map_options = {
          center: myLatlng,
          zoom: 1,
          mapTypeId: google.maps.MapTypeId.ROADMAP
        }
        var map = new google.maps.Map(map_canvas, map_options)		
      }
      google.maps.event.addDomListener(window, 'load', initialize);

	  	function AlertFunction(x)
		{
		alert(x);
		}
</script>"
	. "</head>\n<body>\n"
	. "<div id=\"top\">
<center>
<h1><img src=\"http://www.slac.stanford.edu/comp/net/tulip/tulip_logo.png\" alt=\"TULIP logo\" height=75 align=\"center\">
Trilateration Utility for Locating IP hosts</h1>
</center>

<center>
<nav>
	<ul>
		<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/home.html\">Home</a></li>
		<li><a href=\"https://confluence.slac.stanford.edu/display/IEPM/TULIP\">TULIP Wiki</a></li>
		<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/joinus.html\">Join Us</a></li>
		<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/home.html#\">Information</a>
			<ul>
				<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/home.html#tulip\">TULIP</a></li>
				<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/home.html#ways\">Others Techniques</a></li>
				<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/home.html#lateration\">Lateration</a></li>
				<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/home.html#uses\">Uses of TULIP</a></li>
				<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/home.html#landmarks\">Landmarks</a>
					<ul>
						<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/home.html#landmarks\">List</a></li>
						<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/home.html#maps\">Maps</a></li>
						<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/home.html#laundering\">Laundering</a></li>
					</ul>
				</li>
			</ul>
		</li>
		<li><a href=\"#\">Related Material</a>
			<ul>
				<li><a href=\"http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks\">List of Landmarks</a></li>
				<li><a href=\"http://www.slac.stanford.edu/comp/net/wan-mon/viper/tulipmap.html\">Map of Landmarks</a></li>
				<li><a href=\"http://www.slac.stanford.edu/comp/net/wan-mon/tulip/\">Old TULIP</a></li>
			</ul>
		</li>
		<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/examples.html\">Examples</a></li>
		<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/contact.html\">Contact Us</a>
			<ul>
				<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/contact.html\">Contacts</a></li>
				<li><a href=\"http://www.slac.stanford.edu/comp/net/tulip/feedback_form.html\">Feedback Form</a></li>
			</ul>
	</ul>
</nav>
</center>
</div>
<div id=\"feedback\">
<a href=\"http://www.slac.stanford.edu/comp/net/tulip/feedback_form.html\"><img src=\"http://www.slac.stanford.edu/comp/net/tulip/feedback2.jpg\" alt=\"Please Give Feedback\" height=150 align=\"right\"></a>
</div>
<div id=\"wrapper\">
<div id=\"content\">\n

<center>
<br>
<form name=\"input\" action=\"http://www-wanmon.slac.stanford.edu/cgi-wrap/reflex.cgi\" method=\"post\">
<strong>IP / URL : <input type=\"text\" name=\"target\">
<input type=\"submit\" value=\"Submit\"> 
<input type=\"checkbox\" name=\"debug\" value=\"1\"> Debug 
<input type=\"checkbox\" name=\"ucache\" value=\"1\"> Update Cache
</form><br><br>
</strong>
</center>";
if ($debug>0)
{
print"<h2>Debugging Mode !<h2>";
}
print"<h3>$msg</h3>
<div id=\"legend\">
<center>
<strong>LEGEND : </strong>
<img src=\"http://www.slac.stanford.edu/comp/net/tulip/marker-red.gif\" alt=\"ACBG\" height=20> ACBG <img src=\"http://www.slac.stanford.edu/comp/net/tulip/marker_bubble.png\" alt=\"CBG\" height=20> CBG <img src=\"http://www.slac.stanford.edu/comp/net/tulip/marker-green.png\" alt=\"GEOIP\" height=20> GEOIPTOOL <img src=\"http://www.slac.stanford.edu/comp/net/tulip/marker-nw.png\" alt=\"NETWORLD\" height=20> NETWORLD <img src=\"http://www.slac.stanford.edu/comp/net/tulip/marker-gp.png\" alt=\"NETWORLD\" height=20> GEOPLUGIN <img src=\"http://www.slac.stanford.edu/comp/net/tulip/marker_black.png\" alt=\"landmark\" height=20> Nearest Landmarks
</center>
</div>
\n<div id=\"map_canvas\"></div>";
	

	
####################################################################
#	The Code
####################################################################
use Math::Trig ':great_circle';
use Math::Trig 'deg2rad';
use Math::Trig 'rad2deg';
use Math::Trig;
#use List::Gen;
use LWP::Simple qw/get/;

my $ip=&getaddr($target);
my $ipfile='';

if ($ip=~/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/)
{
	$ipfile=$1.'-'.$2.'-'.$3.'-'.$4;
	
	if ($1==10)
	{
		print "\nError: Target $ip is a private ip address (public ip address is required for geolocation)\n";
		print "<script>AlertFunction(\"Error: Target $ip is a private ip address (public ip address is required for geolocation)\")</script>";
		print "</div>\n</div>\n
		<div id=\"footer\">
		<center>
		<h4>Created by: Raja Asad {rajaasad\@slac.stanford.edu}</h4>
		</center>
		</div>
		</body>\n</html>\n";
		exit 0;
	}
	elsif ($1==172 && ($2>=16 && $2<=31))
	{
		print "\nError: Target $ip is a private ip address (public ip address is required for geolocation)\n";
		print "<script>AlertFunction(\"Error: Target $ip is a private ip address (public ip address is required for geolocation)\")</script>";
		print "</div>\n</div>\n
		<div id=\"footer\">
		<center>
		<h4>Created by: Raja Asad {rajaasad\@slac.stanford.edu}</h4>
		</center>
		</div>
		</body>\n</html>\n";
		exit 0;
	}
	elsif ($1==192 && $2==168)
	{
		print "\nError: Target $ip is a private ip address (public ip address is required for geolocation)\n";
		print "<script>AlertFunction(\"Error: Target $ip is a private ip address (public ip address is required for geolocation)\")</script>";
		print "</div>\n</div>\n
		<div id=\"footer\">
		<center>
		<h4>Created by: Raja Asad {rajaasad\@slac.stanford.edu}</h4>
		</center>
		</div>
		</body>\n</html>\n";
		exit 0;
	}
	elsif ($ip eq '127.0.0.1')
	{
		print "\nError: Target $ip is localhost ip address (public ip address is required for geolocation)\n";
		print "<script>AlertFunction(\"Error: Target $ip is a private ip address (public ip address is required for geolocation)\")</script>";
		print "</div>\n</div>\n
		<div id=\"footer\">
		<center>
		<h4>Created by: Raja Asad {rajaasad\@slac.stanford.edu}</h4>
		</center>
		</div>
		</body>\n</html>\n";
		exit 0;
	}
	elsif ($1==127)
	{
		print "\nError: Target $ip is a private ip address (public ip address is required for geolocation)\n";
		print "<script>AlertFunction(\"Error: Target $ip is a private ip address (public ip address is required for geolocation)\")</script>";
		print "</div>\n</div>\n
		<div id=\"footer\">
		<center>
		<h4>Created by: Raja Asad {rajaasad\@slac.stanford.edu}</h4>
		</center>
		</div>
		</body>\n</html>\n";
		exit 0;
	}
}
my $usecache=0;		# This will decide if cache is used
unless ($ucache==1)
{
if (-e ($tmpdir.$ipfile.'-0.txt')) {
	print "Cache $ipfile";
	open(my $testh,"<",($tmpdir.$ipfile.'-0.txt'));
	my $line = readline $testh;
	close($testh);
	chomp $line;
	my @data=(split("\t", $line));
	my $age=time()-$data[3];	#age of cache in seconds
	$age=$age/86400; 			#age of cache in day
	$age=sprintf("%.1f", $age);
	print " is $age days old\n<br>";
	if ($age > 15) {
		print "Updating Cache since its too old\n<br>";
	}
	else {
		#print "Using cache\n<br>";
		$usecache=1;
	}
}
}

######### Performing tier=0 measurements to find region #############
my $fho;
my $fout=$tmpdir.$ipfile."-0.txt";			#filename of formatted output
my $fint=$tmpdir."raw0.txt";
my $land;my $doit=0;my $end=0;my $ind=1;
my $fin=$fint;				#filename of refector rtt dump
my $fh;my $fh1;my $URL;my $raw;

if ($usecache==0)
{
open($fh1, ">$fint") || die "Couldn't open '".$fint."' for writing because: ".$!;
my $start = time(); #Start time
print "\n<h4>Performing tier=0 RTT Measurements to get a rough idea of target's location (takes around 10sec).....</h4>\n";
$URL='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?region=all&target='.$ip.'&tier=0';
#my $URL='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?function=landmarks';
$raw = get($URL);
print "\nRetrieved " . length($raw) . " bytes of data.<br>\n";
#print "\nThanks for you patience ;) \n";
if ($debug>0){print "<h3>Reflector Output for tier0 :</h3>\n<br>".$raw."\n<br>";}
$raw=~s/<.*?>/ /g;
#getstore($URL,$fint);
print $fh1 $raw;
my $stop1 = time(); #time to do tier0 measurements
#print "Retrieved " . length($raw) . " bytes of data.\n";
#open(my $fh, "$fout") || die "Couldn't open '".$fout."' for reading because: ".$!;
#while ((my $n = read $fh, my $data, 10) != 0) {
#  print "$n bytes read\n";
#  print "$data\n";
  #$buf .= $data;
#}
close($fh1);
print "Took ".sprintf ("%.1f",(time()-$start))." seconds<br>\n";

open($fh, "$fin") || die "Couldn't open '".$fin."' for reading because: ".$!;


open($fho, ">$fout") || die "Couldn't open '".$fout."' for writing because: ".$!;

while(<$fh>) {
    my $line=$_;
	chomp $line;
	if ($line =~ /Landmark\(\d\)=http:\/\/(.+)\/toolkit/ || $line =~ /Landmark\(\d\)=http:\/\/(.+)\/cgi/ || $line =~ /Landmark\(\d\)=http:\/\/(.+):3355/)
		{
		$land=$1;
			
		if ($line =~ /min\/avg\/max = (\d+\.\d+)\//)
			{
			my $minrtt=$1;
			print $fho "$land\t$minrtt\t".($ind++)."\t".time()."\n";
			}
}
}
close($fin);
close($fho);
}
else
{
	print "\n<h4>Using cached tier=0 RTT Measurements to get a rough idea of target's location.....</h4>\n";
}


open($fho, "$fout") || die "Couldn't open '".$fout."' for writing because: ".$!; #open rtt formatted file for reading

my $flands="/afs/slac.stanford.edu/u/sf/rajaasad/bin/landmarks.txt";		#filename of function=landmarks dump
open(my $fhlands, "$flands") || die "Couldn't open '".$flands."' for reading because: ".$!;
my $foutf=$tmpdir."input0.txt";		#filename of final formatted file
#my $foutf=$tmpdir."$ip".'0.txt';		#filename of final formatted file
#print $foutf."\n";
open(my $fhf, ">","$foutf") || die "Couldn't open '".$foutf."' for reading because: ".$!;
#print $fhf "0\t0\t1\t0\n";
my $minrtt=1000;
my $clat;my $clon;my $clname;my $ccity;my $cconti;
local $/ = "\n";
if ($debug>0){print"<h3>Printing tier0 RTT data:</h3><table border=\"1\"><tr><td><strong>Latitude</td><td><strong>Longitude</td><td><strong>hostName</td><td><strong>RTT</td><td><strong>City</td><td><strong>Region</td></tr>\n";}
while(!eof $fho) {
	my $line = readline $fho;
	# process $line...
	chomp $line;
	my @data=(split("\t", $line));
	my $lname=$data[0];my $rtt=$data[1];
		while(!eof $fhlands) {
			my $lline = readline $fhlands;
			my @ldata=(split("\t", $lline));
			for(my $i=1; $i< (scalar @ldata); $i++)
			{
				if($lname eq $ldata[$i]) {
					if($minrtt>$rtt)
					{
						$minrtt=$rtt;
						$clat=$ldata[3];
						$clon=$ldata[4];
						$clname=$lname;
						$ccity=$ldata[7];
						$cconti=$ldata[8];
					}
					print $fhf "$ldata[3]\t$ldata[4]\t$rtt\n";
					if ($debug>0){print"<tr><td>$ldata[3]</td><td>$ldata[4]</td><td>$lname</td><td>$rtt</td><td>$ldata[7]</td><td>$ldata[8]</td></tr>\n";}
					last;
					}
			}
			
		}
	seek($fhlands,0,0);
	#push(@array,[@data]);
	#print "$lname\t$rtt\n";
};
if ($debug>0){print"</table><br>\n";}
if ($minrtt==1000)
{
	print "\nError: Target $ip is not responding\n";
	print "<script>AlertFunction(\"Error: Target didn't respond to pings probes<br>Either the target is offline, doesn't exist or is configured not to respond to pings\")</script>";
	print "</div>\n</div>\n
	<div id=\"footer\">
	<center>
	<h4>Created by: Raja Asad {rajaasad\@slac.stanford.edu}</h4>
	</center>
	</div>
	</body>\n</html>\n";
	exit 0;
}
print "Closest tier0 landmark is $clname in $ccity, $cconti at ($clat,$clon) with RTT : $minrtt ms from target<br>\n";
my $region;my $minalpha=0.15;my $maxalpha=0.6;my $reg='all';

if ($minrtt>475)
{
	print "<h3>The target is probably on Satellite Link since RTTs are greater than 475ms and hence cannot be Geolocated !</h3>";
	print "<script>AlertFunction(\"Error: The target is on Satellite Link and cannot be Geolocated\")</script>";
	print "</div>\n</div>\n
	<div id=\"footer\">
	<center>
	<h4>Created by: Raja Asad {rajaasad\@slac.stanford.edu}</h4>
	</center>
	</div>
	</body>\n</html>\n";
	exit 0;
}

if($clat<71&&$clon>-166&&$clat>16&&$clon<-49&&$minrtt<80)
{
	$region="North America";
	$reg='NA';
	$maxalpha=0.65;
	print "\nRegion = $region<br>\n";
}
elsif($clat<70&&$clon>-10&&$clat>39&&$clon<30&&$minrtt<50)
{
	$region="Europe";
	$reg='E';
	print "\nRegion = $region\n";
}
elsif($clat<37.7&&$clon>52&&$clat>5.4&&$clon<94.7&&$minrtt<50)
{
	$region="South Asia";
	$reg='SA';
	$maxalpha=0.55;
	print "\nRegion = $region\n";
}
elsif($clat<-10.8&&$clon>112.5&&$clat>-46.7&&$clon<179.3&&$minrtt<80)
{
	$region="Australia";
	$reg='AU';
	print "\nRegion = $region\n";
}
elsif($clat<22.6&&$clon>90.7&&$clat>-10.1&&$clon<153.3&&$minrtt<80)
{
	$region="S.E. Asia";
	$reg='SEA';
	print "\nRegion = $region\n";
}
else
{
	$region="all";
	$reg='all';
	print "\nRegion = $region\n";
}
close($fho);
close($fhlands);
close($fhf);



############### Performing tier=all measurements for multilateration ###########
$fout=$tmpdir.$ipfile.".txt";			#filename of formatted output
$fint=$tmpdir."raw.txt";
$land=0;$doit=0;$end=0;$ind=1;
$fin=$fint;				#filename of refector rtt dump

if ($usecache==0)
{
my $start=time();
open($fh1, ">$fint") || die "Couldn't open '".$fint."' for writing because: ".$!;
#my $ip='134.79.197.197'; 
print "\n<h4>Performing tier=1 RTT Measurements in $region region (takes around 20sec) .....</h4>\n";
$URL='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?region='.$region.'&target='.$ip.'&tier=all';
$raw = get($URL);
print "\nRetrieved " . length($raw) . " bytes of RTT data.<br>\n";
print "Took ".sprintf ("%.1f",(time()-$start))." seconds<br>\n";
print "\nThanks for your patience..... <br>\n";
$raw=~s/<.*?>/ /g;
#getstore($URL,$fint);
print $fh1 $raw;
close($fh1);
open($fh, "$fin") || die "Couldn't open '".$fin."' for reading because: ".$!;
open($fho, ">$fout") || die "Couldn't open '".$fout."' for writing because: ".$!;

while(<$fh>) {
    my $line=$_;
	chomp $line;
	if ($line =~ /Landmark\(\d\)=http:\/\/(.+)\/toolkit/ || $line =~ /Landmark\(\d\)=http:\/\/(.+)\/cgi/ || $line =~ /Landmark\(\d\)=http:\/\/(.+):3355/)
		{
		$land=$1;
			
		if ($line =~ /min\/avg\/max = (\d+\.\d+)\//)
			{
			my $minrtt=$1;
			print $fho "$land\t$minrtt\t".($ind++)."\n";
			}
}
}
close($fin);
close($fho);
}
else
{
	print "\n<h4>Using cached tier=1 RTT Measurements in $region region .....</h4><br>\n";
}
open($fho, "$fout") || die "Couldn't open '".$fout."' for writing because: ".$!; #open rtt formatted file for reading

$flands="/afs/slac.stanford.edu/u/sf/rajaasad/bin/landmarks.txt";		#filename of function=landmarks dump
open($fhlands, "$flands") || die "Couldn't open '".$flands."' for reading because: ".$!;
$foutf=$tmpdir."input.txt";		#filename of final formatted file
#$foutf=$tmpdir.$ipfile.".txt";		#filename of final formatted file
open($fhf, ">$foutf") || die "Couldn't open '".$foutf."' for reading because: ".$!;
print $fhf "0\t0\t1\t0\n";

local $/ = "\n";
while(!eof $fho) {
	my $line = readline $fho;
	# process $line...
	chomp $line;
	my @data=(split("\t", $line));
	my $lname=$data[0];my $rtt=$data[1];
		while(!eof $fhlands) {
			my $lline = readline $fhlands;
			my @ldata=(split("\t", $lline));
			for(my $i=1; $i< (scalar @ldata); $i++)
			{
				if($lname eq $ldata[$i]) {
					print $fhf "$ldata[3]\t$ldata[4]\t$rtt\t$data[2]\t$lname\t$rtt\t$ldata[0]\n";
					last;
					}
			}
			
		}
	seek($fhlands,0,0);
	#push(@array,[@data]);
	#print "$lname\t$rtt\n";
};

close($fho);
close($fhlands);
close($fhf);

my $f=$tmpdir."input.txt";
$fout=$tmpdir."out.txt";
open($fh, "<", $f) || die "Couldn't open '".$f."' for reading because: ".$!;

#print "Enter Region (NA,E,SA) : ";
#my $reg=<>;
#chomp $reg;
# unless($reg=~ /^NA$|^E$|^SA$/i)
# {
# print "Error: Unsupported region";
# exit 0;
# }
my @aamax;my @aamin;
my $mindelay=0.03; 	#This is the min delay landmarks take to ping themselves 

if ($reg=~ /NA/i)
{
	@aamax=(0.7,0.69,0.68,0.65);
	@aamin=(0.05,0.1,0.1);
	$mindelay=0.15;
	#$f="tmp/NA_RTTS_wop/$ip.txt";
}
elsif ($reg=~ /E/i)
{
	@aamax=(0.63,0.6,0.6,0.55);
	@aamin=(0.05,0.1,0.1);
	$mindelay=0.15;
	#$f="tmp/EU_new_RTTS/$ip.txt";
}
elsif ($reg=~ /SA/i)
{
	@aamax=(0.52,0.52,0.4,0.25);
	@aamin=(0.07,0.07,0.001);
	#$f="tmp/Pak_RTTS/$ip.txt";
	$mindelay=0.3;
}
elsif ($reg=~ /all/i)
{
	@aamax=(1,1,1,1);
	@aamin=(0.001,0.001,0.001);
	$mindelay=0;
	#$f="tmp/NA_RTTS_wop/$ip.txt";
}
else
{
	@aamax=(1,1,1,1);
	@aamin=(0.001,0.001,0.001);
	$mindelay=0;
	#$f="tmp/NA_RTTS_wop/$ip.txt";
}

my %landstoskip=(37.2692,1,39.661,1,40.7855,1,40.76,1,40.3563,1,53.3431,1,40.6944,1,40.7458,1,38.9525,1); #latitude of suspicious landmark ,40.7563,1

$region='';$minalpha=0.25;$maxalpha=0.65;


my @array;my @array2; my @array0; my @rttarray;
my $count=0;
my $line = readline $fh;
chomp $line;
my @actual=(split("\t", $line));
if ($actual[0]==0)
{
#print "\nActual lat and Actual lon : unknown\n";
}
else
{
print "\nActual lat : $actual[0] \t\t Actual lon : $actual[1]\n";
print "\n--------------------------------------------------------------------------\n";
}
if ($debug>0){print"<br><h3>Printing tier1 RTT data:</h3><table border=\"1\"><tr><td><strong>Latitude</td><td><strong>Longitude</td><td><strong>CBG_distance</td><td><strong>ID#</td><td><strong>hostName</td><td><strong>RTT</td><td><strong>Type</td></tr>\n";}
while(!eof $fh) {
	
	$line = readline $fh;
	# process $line...
	chomp $line;
	my @data=(split("\t", $line));
	my @data2=@data; my @data0=@data;
	if (defined($landstoskip{$data[0]})){next;}
	if ($data[2]<0 || $data[2]>60){next;}
	# if ($debug>0){print"$line<br>\n";}
	push(@rttarray,[@data]);
	$data[2]=$data[2]*100*$aamax[0];			#using max alpha
	$data0[2]=$data0[2]*100*1;				#using SOI alpha
	$data2[2]=$data2[2]*100*$minalpha;			#using min alpha
	if ($debug>0){print"<tr><td>$data[0]</td><td>$data[1]</td><td>$data[2]</td><td>$data[3]</td><td>$data[4]</td><td>$data[5]</td><td>$data[6]</td></tr>\n";}
	push(@array,[@data]);
	push(@array2,[@data2]);
	push(@array0,[@data0]);
	#print $array[$count++]->[1],"\n";
};
if ($debug>0){print"</table><br>\n";}
my @sorted0 = sort { $a->[2] <=> $b->[2] } @array0; #sorted array wrt  max Distance in ascending order
my @sorted = sort { $a->[2] <=> $b->[2] } @array; 	#sorted array wrt  max Distance in ascending order
my @rttsorted = sort { $a->[2] <=> $b->[2] } @rttarray;
my @sorted2 = sort { $b->[2] <=> $a->[2] } @array2; #sorted array wrt min Distance in descending order

#$sorted[0]->[3]=100;
# print "The list is : \n\n";
# print "@$_\n" for @rttsorted;

open(OUTFILE, ">$fout") || die "Couldn't open '".$fout."' for writing because: ".$!;

print OUTFILE "@$_\n" for @sorted2;


close (OUTFILE); 

# my $lat0=10;
# my $lat1=10;
# my $lon0=11;
# my $lon1=12;
my $rho=6371;

my @degran=0 .. 360;

my $diro=45;
my $dist=100;

my @scircle=&scircle(0);
#my @scircle2=&scircle(1);
my $quit=0;
my $estlat=0;my $estlon=0;
if(!defined($sorted[0]->[2]))
{
	print"Error: Target didn't respond to tier1 landmarks or there aren't nearby landmarks available for Geolocation";
	print "<script>AlertFunction(\"Error: Target either didn't respond to tier1 landmark pings or there aren't any nearby landmarks available for Geolocation.\")</script>";
	$quit=1;
}
elsif($sorted[0]->[2] < 30)
{
	$quit=1;
}
elsif($sorted[0]->[2] < 30)
{
	$quit=1;
}
my @region=@scircle; #array for containing the intersection region points
my @bearing;my @sarc;



# print scalar @sorted."\n";
# exit 0;
#################Performing CBG#######################
for (my $i=1; $i < (scalar @sorted);$i++)
{
	if($quit==1){last;}
	@bearing=();#@sarc=();
	for (my $j=0; $j < (scalar @region);$j++)
	{
		my $distance = great_circle_distance(deg2rad($sorted[$i]->[1]), pi/2 - deg2rad($sorted[$i]->[0]), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]), $rho);
		if ($distance > $sorted[$i]->[2])
		{
			my $direction = great_circle_bearing(deg2rad($sorted[$i]->[1]), pi/2 - deg2rad($sorted[$i]->[0]), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]));
			#push(@bearing,($direction+0.02));
			push(@bearing,$direction);
			#push(@bearing,($direction+0.05));
			splice(@region,$j,1);
			$j--;
		}
	}
	if ((scalar @bearing > 0))
	{
		@sarc=&sarc($i,\@bearing);
		#print @bearing;
		push (@region,@sarc);
	}
}

for (my $i=0; $i < (scalar @sorted);$i++)
{
	if($quit==1){last;}
	@bearing=();#@sarc=();
	for (my $j=0; $j < (scalar @region);$j++)
	{
		my $distance = great_circle_distance(deg2rad($sorted[$i]->[1]), pi/2 - deg2rad($sorted[$i]->[0]), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]), $rho);
		if (($distance-0.2) > $sorted[$i]->[2])
		{
			#my $direction = great_circle_bearing(deg2rad($sorted[$i]->[1]), pi/2 - deg2rad($sorted[$i]->[0]), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]));
			#push(@bearing,$direction);
			splice(@region,$j,1);
			$j--;
		}
	}

}


$estlat=0;$estlon=0;my $tempdist=0;

if (scalar @region==0)
{
	print"CBG didn't converge, verify landmark locations\n<br>";
}
else
{
for (my $k=0; $k < (scalar @region); $k++)
{
	$estlat+=$region[$k]->[0];
	$estlon+=$region[$k]->[1];
}
$estlat= sprintf "%.4f", ($estlat/(scalar @region));
$estlon= sprintf "%.4f", ($estlon/(scalar @region));

for (my $k=0; $k < (scalar @region); $k++)
{
	$tempdist+=great_circle_distance(deg2rad($region[$k]->[1]), pi/2 - deg2rad($region[$k]->[0]), deg2rad($estlon), pi/2 - deg2rad($estlat), $rho);
}
$tempdist= sprintf "%.1f", ($tempdist/(scalar @region));
}
print "\n<h4>CBG_Est lat : $estlat,\tCBG_Est lon : $estlon,\tAccuracy: $tempdist km</h4>\n";
if ($actual[0]>0)
{
my $error=great_circle_distance(deg2rad($actual[1]), pi/2 - deg2rad($actual[0]), deg2rad($estlon), pi/2 - deg2rad($estlat), $rho);
$error= sprintf "%.1f", $error;
print "\nThe CBG Geolocation Error is : $error km<br>\n";
print "\n--------------------------------------------------------------------------\n";
}
my $estlatcbg=$estlat; my $estloncbg=$estlon;
# open(OUTFILE, ">/tmp/region1.txt") || die "Couldn't open region.txt for writing because: ".$!;
# print OUTFILE "@$_\n" for @region;
# close (OUTFILE);

my @regioncbg=@region;
##########################Performing ACBG #######################################################



#my @regionc=@region; #make a copy
#while($minalpha>0.05)
#{
seek($fh,0,0);
readline $fh;
#chomp $line;
@array2=();@array=();
while(!eof $fh) {
	$line = readline $fh;
	# process $line...
	chomp $line;
	my @data=(split("\t", $line)); my @data2=@data;
	$data[2]=($data[2]-$mindelay);
	if ($data[2]>0)
	{
	$data2[2]=$data[2];
	}
	else
	{
	$data2[2]=0.01;$data[2]=0.01;
	}
	if (defined($landstoskip{$data[0]})){next;}
	if ($data[2]<0 || $data[2]>60){next;}
	if ($data[2]<20)
	{
		$data[2]=$data[2]*100*$aamax[0];			#using max alpha
	}
	elsif ($data[2]<30)
	{
		$data[2]=$data[2]*100*$aamax[1];			#using max alpha
	}
	elsif ($data[2]<40)
	{
		$data[2]=$data[2]*100*$aamax[2];			#using max alpha
	}
	else
	{
		$data[2]=$data[2]*100*$aamax[3];			#using max alpha
	}
	push(@array,[@data]);
	if ($data2[2]<7){next;}
	if ($data2[2]<25)
	{
	$data2[2]=$data2[2]*100*$aamin[0];			#using min alpha
	}
	elsif ($data2[2]<40)
	{
	$data2[2]=$data2[2]*100*$aamin[1];			#using min alpha
	}
	else
	{
	$data2[2]=$data2[2]*100*$aamin[2];			#using min alpha
	}
	push(@array2,[@data2]);
	#print $array[$count++]->[1],"\n";
};
#print "Using Min-Alpha = $minalpha\n"; 
#$minalpha=$minalpha-0.03;
@sorted = sort { $a->[2] <=> $b->[2] } @array; #sorted array wrt min Distance
@sorted2 = sort { $b->[2] <=> $a->[2] } @array2; #sorted array wrt min Distance in descending order

@scircle=&scircle(0);
#@scircle2=&scircle(1);
@region=@scircle; #array for containing the intersection region points

for (my $i=1; $i < (scalar @sorted);$i++)
{
	if($quit==1){last;}
	@bearing=();#@sarc=();
	for (my $j=0; $j < (scalar @region);$j++)
	{
		my $distance = great_circle_distance(deg2rad($sorted[$i]->[1]), pi/2 - deg2rad($sorted[$i]->[0]), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]), $rho);
		if ($distance > $sorted[$i]->[2])
		{
			my $direction = great_circle_bearing(deg2rad($sorted[$i]->[1]), pi/2 - deg2rad($sorted[$i]->[0]), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]));
			#push(@bearing,($direction+0.02));
			push(@bearing,$direction);
			#push(@bearing,($direction+0.05));
			splice(@region,$j,1);
			$j--;
		}
	}
	if ((scalar @bearing > 0))
	{
		@sarc=&sarc($i,\@bearing);
		#print @bearing;
		push (@region,@sarc);
	}
}

for (my $i=0; $i < (scalar @sorted);$i++)
{
	if($quit==1){last;}
	@bearing=();#@sarc=();
	for (my $j=0; $j < (scalar @region);$j++)
	{
		my $distance = great_circle_distance(deg2rad($sorted[$i]->[1]), pi/2 - deg2rad($sorted[$i]->[0]), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]), $rho);
		if (($distance-0.2) > $sorted[$i]->[2])
		{
			#my $direction = great_circle_bearing(deg2rad($sorted[$i]->[1]), pi/2 - deg2rad($sorted[$i]->[0]), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]));
			#push(@bearing,$direction);
			splice(@region,$j,1);
			$j--;
		}
	}

}

$estlat=0;$estlon=0;

if (scalar @region==0)
{
print"ACBG didn't converge\n<br>";
$estlat=$estlatcbg;$estlon=$estloncbg;
}
else
{
for (my $k=0; $k < (scalar @region); $k++)
{
	$estlat+=$region[$k]->[0];
	$estlon+=$region[$k]->[1];
}
$estlat= sprintf "%.4f", ($estlat/(scalar @region));
$estlon= sprintf "%.4f", ($estlon/(scalar @region));
}
#print "\n<h4>ACBG_wod_Est lat : $estlat\tACBG_wod_Est lon : $estlon<h4>\n";
if ($actual[0]>0)
{
my $error=great_circle_distance(deg2rad($actual[1]), pi/2 - deg2rad($actual[0]), deg2rad($estlon), pi/2 - deg2rad($estlat), $rho);
$error= sprintf "%.1f", $error;
print "\nThe ACBG wod Geolocation Error is : $error km\n";
print "\n--------------------------------------------------------------------------\n";
}
# open(OUTFILE, ">/afs/slac.stanford.edu/u/sf/rajaasad/bin/region3.txt") || die "Couldn't open region.txt for writing because: ".$!;
# print OUTFILE "@$_\n" for @region;
# close (OUTFILE);
#####################################DONUTS##################################################
my @regionc=@region; #make a copy

for (my $i=0; $i < (scalar @sorted2);$i++)
{
	if($quit==1){last;}
	@bearing=(); my @bearing2=(); my $checker=0; my $pminfromcent=9999; #@sarc=();
	my $distfromcent = great_circle_distance(deg2rad($sorted2[$i]->[1]), pi/2 - deg2rad($sorted2[$i]->[0]), deg2rad($estlon), pi/2 - deg2rad($estlat), $rho);
	for (my $j=0; $j < (scalar @region);$j++)
	{
		my $distance = great_circle_distance(deg2rad($sorted2[$i]->[1]), pi/2 - deg2rad($sorted2[$i]->[0]), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]), $rho);
		my $pdistfromcent = great_circle_distance(deg2rad($estlon), pi/2 - deg2rad($estlat), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]), $rho);
		
		if ($distance < $sorted2[$i]->[2])
		{
			my $direction = great_circle_bearing(deg2rad($sorted2[$i]->[1]), pi/2 - deg2rad($sorted2[$i]->[0]), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]));
			push(@bearing,$direction);
			push(@bearing2,($direction- pi));
			#push(@bearing2,($direction- pi+0.05));
			splice(@region,$j,1);
			#if (scalar @region == 0){last;}
			$j--;
			if ($pdistfromcent < $pminfromcent)
			{
				$pminfromcent=$pdistfromcent;
			}
			
		}
	}
	# print "For Landmark $distfromcent and for point $pminfromcent\n";
	if ($distfromcent < $pminfromcent || ($distfromcent - $pminfromcent) < 50)
	{
		$checker=1;
	}
	if ((scalar @bearing > 0))
	{
		#if ($checker==1){@sarc=&sarc2($i,\@bearing2);push (@region,@sarc);}
		@sarc=&sarc2($i,\@bearing);
		if ($checker==1){@sarc=&scircle2($i);}
		#print @bearing;
		push (@region,@sarc);
	}
}

for (my $i=0; $i < (scalar @sorted);$i++)
{
	if($quit==1){last;}
	@bearing=();#@sarc=();
	for (my $j=0; $j < (scalar @region);$j++)
	{
		my $distance = great_circle_distance(deg2rad($sorted[$i]->[1]), pi/2 - deg2rad($sorted[$i]->[0]), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]), $rho);
		if (($distance-0.2) > $sorted[$i]->[2])
		{
			splice(@region,$j,1);
			#if (scalar @region == 0){last;}
			$j--;
		}
	}

}


for (my $i=0; $i < (scalar @sorted2);$i++)
{
	if($quit==1){last;}
	@bearing=(); my @bearing2=(); my $checker=0; my $pminfromcent=9999; #@sarc=();
	my $distfromcent = great_circle_distance(deg2rad($sorted2[$i]->[1]), pi/2 - deg2rad($sorted2[$i]->[0]), deg2rad($estlon), pi/2 - deg2rad($estlat), $rho);
	for (my $j=0; $j < (scalar @region);$j++)
	{
		my $distance = great_circle_distance(deg2rad($sorted2[$i]->[1]), pi/2 - deg2rad($sorted2[$i]->[0]), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]), $rho);
		my $pdistfromcent = great_circle_distance(deg2rad($estlon), pi/2 - deg2rad($estlat), deg2rad($region[$j]->[1]), pi/2 - deg2rad($region[$j]->[0]), $rho);
		
		if (($distance+0.2) < $sorted2[$i]->[2])
		{
			splice(@region,$j,1);
			#if (scalar @region == 0){last;}
			$j--;
						
		}
	}
}
if (scalar @region == 0)
{
@region=@regionc;
print "\n---min-alpha not used---\n"
}

if (scalar @region == 0)
{
}
else
{
$estlat=0;$estlon=0;$tempdist=0;

for (my $k=0; $k < (scalar @region); $k++)
{
	$estlat+=$region[$k]->[0];
	$estlon+=$region[$k]->[1];
	
}
$estlat= sprintf "%.4f", ($estlat/(scalar @region));
$estlon= sprintf "%.4f", ($estlon/(scalar @region));


for (my $k=0; $k < (scalar @region); $k++)
{
	$tempdist+=great_circle_distance(deg2rad($region[$k]->[1]), pi/2 - deg2rad($region[$k]->[0]), deg2rad($estlon), pi/2 - deg2rad($estlat), $rho);
}
$tempdist= sprintf "%.1f", ($tempdist/(scalar @region));
}
print "\n<h4>ACBG_Est lat : $estlat,\tACBG_Est lon : $estlon,\tAccuracy : $tempdist km</h4>\n";

# open(my $preg, ">/afs/slac.stanford.edu/u/sf/rajaasad/tulipdata/reg_".$ip.".txt") || die "Couldn't open region.txt for writing because: ".$!;
# print $preg "@$_\n" for @region;
# close ($preg);

if ($actual[0]>0)
{
my $error=great_circle_distance(deg2rad($actual[1]), pi/2 - deg2rad($actual[0]), deg2rad($estlon), pi/2 - deg2rad($estlat), $rho);
$error= sprintf "%.1f", $error;
print "\nThe ACBG Geolocation Error is : $error km\n";
print "\n--------------------------------------------------------------------------\n";
}
#my $stop2=time();
#print "\nTime for tier0 = ".int($stop1-$start)."\tTime for tierall = ".int($stop2-$stop1)."\tTotal Time = ".int($stop2-$start)."\n";
#print $fh3 "@$_\n" for @region;
#close ($fh3);
#print "\n\n", (scalar @sorted), "\n\n";
#(my $thetad, my $phid, my $dird) = great_circle_destination(deg2rad($lon0), pi/2 - deg2rad($lat0), deg2rad($diro), $dist/$rho);

#print ("\n",rad2deg($thetad),"\t",rad2deg($phid),"\t",$dird,"\n");


####################################### GEOIPTOOL ###############################################
my $geolat=0;my $geolon=0;


use LWP::UserAgent;
use HTTP::Cookies;
 
# Create the fake browser (user agent).
my $ua = LWP::UserAgent->new();
 
# Accept cookies. You don't need to supply
# any options to new() here, but just for
# kicks we'll save the cookies to a file.
my $cookies = HTTP::Cookies->new();
 
$ua->cookie_jar($cookies);
 
# Pretend to be Internet Explorer.
$ua->agent("Windows IE 7");
# or maybe .... $ua->agent("Mozilla/8.0");
 
# Get some HTML.
my $response = $ua->get('http://www.geoiptool.com/en/?IP='.$ip);
my $content= $response->content;
if($response->is_success) {
	if ($content =~ /var myLatlng = new google\.maps\.LatLng\((-*\d+.?\d*),(-*\d+.?\d*)\)/) {
	  $geolat=$1;$geolon=$2;
	}
}

print "\n<h4>GEOIPTOOL lat : $geolat\tlon : $geolon</h4>\n";
#################################################################################################

####################################### NETWORLD ###############################################
my $nwlat=0;my $nwlon=0;

my $ipaddress=&getaddr($ip);
# Get some HTML.
$response = $ua->get('http://www.networldmap.com/TryIt.htm?GetLocation&ipaddress='.$ipaddress);
$content= $response->content;
if($response->is_success) {
	if ($content =~ /mark=(-*\d+.?\d*),(-*\d+.?\d*)/) {
	  $nwlat=$2;$nwlon=$1;
	}
}

print "\n<h4>NETWORLD lat : $nwlat\tlon : $nwlon</h4>\n";
#################################################################################################

####################################### GEOPLUGIN ###############################################
my $gplat=0;my $gplon=0;

# Get some HTML.
$response = $ua->get('http://www.geoplugin.net/php.gp?ip='.$ipaddress);
$content= $response->content;
if($response->is_success) {
	if ($content =~ /geoplugin_latitude";s:\d+:"(-*\d+.?\d*)";s:\d+:"geoplugin_longitude";s:\d+:"(-*\d+.?\d*)"/) {
	  $gplat=$1;$gplon=$2;
	}
}

print "\n<h4>GEOPLUGIN lat : $gplat\tlon : $gplon</h4>\n";
#################################################################################################

print"<script>
	  // First, create an object containing LatLng and population for each city.
		var citymap = {};";
if(defined($sorted[0]->[2]))
{
	print"	citymap['one'] = {
		  center: new google.maps.LatLng($sorted[0]->[0], $sorted[0]->[1]),
		  radi: $sorted[0]->[2]
		};";
}
if(defined($sorted[2]->[2]))
{		
print"	citymap['two'] = {
		  center: new google.maps.LatLng($sorted[1]->[0], $sorted[1]->[1]),
		  radi: $sorted[1]->[2]
		};
		citymap['three'] = {
		  center: new google.maps.LatLng($sorted[2]->[0], $sorted[2]->[1]),
		  radi: $sorted[2]->[2]
		};";
}		
print"
		var cityCircle;
	  
      function initialize() {
		var myLatlng = new google.maps.LatLng($estlat,$estlon);
        var map_canvas = document.getElementById('map_canvas');
        var map_options = {
          center: myLatlng,
          zoom: 8,
          mapTypeId: google.maps.MapTypeId.ROADMAP
        }
	
		var map = new google.maps.Map(map_canvas, map_options)		
		var marker = new google.maps.Marker({
		position: myLatlng,
		map: map,
		title: 'ACBG'
		});
		setMarkers(map, beaches);
		setMarkers2(map, cbgregion);
		
		var imagenw = {
		url: 'https://www.slac.stanford.edu/comp/net/tulip/marker-nw.png',
		};
		var myLatLngnw = new google.maps.LatLng($nwlat, $nwlon);
		var nwmarker = new google.maps.Marker({
        position: myLatLngnw,
        map: map,
        icon: imagenw,
        title: 'NETWORLD',       
		});
		
		var imagegp = {
		url: 'https://www.slac.stanford.edu/comp/net/tulip/marker-gp.png',
		};
		var myLatLnggp = new google.maps.LatLng($gplat, $gplon);
		var gpmarker = new google.maps.Marker({
        position: myLatLnggp,
        map: map,
        icon: imagegp,
        title: 'GEOPLUGIN',       
		});
		
		var image = {
		url: 'https://www.slac.stanford.edu/comp/net/tulip/marker-green.png',
		// This marker is 20 pixels wide by 32 pixels tall.
		size: new google.maps.Size(32, 32),
		// The origin for this image is 0,0.
		origin: new google.maps.Point(0,0),
		// The anchor for this image is the base of the flagpole at 0,32.
		anchor: new google.maps.Point(16, 32)
		};
		var myLatLnggeo = new google.maps.LatLng($geolat, $geolon);
		var geoipmarker = new google.maps.Marker({
        position: myLatLnggeo,
        map: map,
        icon: image,
        title: 'GEOIPTOOL',       
		});
		var image2 = {
		url: 'https://www.slac.stanford.edu/comp/net/tulip/marker_bubble.png',
		// This marker is 20 pixels wide by 32 pixels tall.
		size: new google.maps.Size(32, 32),
		// The origin for this image is 0,0.
		origin: new google.maps.Point(0,0),
		// The anchor for this image is the base of the flagpole at 0,32.
		anchor: new google.maps.Point(16, 32)
		};
		var myLatLngcbg = new google.maps.LatLng($estlatcbg, $estloncbg);
		var cbgmarker = new google.maps.Marker({
        position: myLatLngcbg,
        map: map,
        icon: image2,
        title: 'CBG',       
		});
		var imageland = {
			url: 'https://www.slac.stanford.edu/comp/net/tulip/marker_black.png',
		};
		
		";

for (my $k=0; ($k < 10) && defined($sorted[$k]->[2]); $k++)
{

	print"
	var myLatLng = new google.maps.LatLng($sorted[$k]->[0], $sorted[$k]->[1]);
	var markerl".$k." = new google.maps.Marker({
        position: myLatLng,
        map: map,
        icon: imageland,
        title: 'Landmark',

    });
	var contentString = '<strong>$sorted[$k]->[6]<br>$sorted[$k]->[4]<br>Lat:</strong> $sorted[$k]->[0], <strong>Lon:</strong> $sorted[$k]->[1]<br><strong>RTT:</strong> ".($sorted[$k]->[5])." ms<br><strong>Distance:</strong> $sorted[$k]->[2] km';

	var infowindow".$k." = new google.maps.InfoWindow({
	  content: contentString
	});
	google.maps.event.addListener(markerl".$k.", 'click', function() {
		infowindow".$k.".open(map,markerl".$k.");
	});
	";
}		

	
print"	
		for (var city in citymap) {
		var landOptions = {
		  strokeColor: '#000000',
		  strokeOpacity: 0.8,
		  strokeWeight: 1,
		  fillColor: '#000000',
		  fillOpacity: 0.1,
		  map: map,
		  center: citymap[city].center,
		  radius: citymap[city].radi*1000
		};
		// Add the circle for this city to the map.
		cityCircle = new google.maps.Circle(landOptions);
		}
	
}
var beaches = [
";

for (my $k=0; $k < (scalar @region); $k++)
{
	print"['acbg', $region[$k]->[0], $region[$k]->[1],$k],\n";
}

#    new google.maps.LatLng(25.774252, -80.190262),


print"
];

var cbgregion = [
";

for (my $k=0; $k < (scalar @regioncbg); $k++)
{
	print"['cbg', $regioncbg[$k]->[0], $regioncbg[$k]->[1],$k],\n";
}

print"
];

function setMarkers(map, locations) {
  // Add markers to the map

  // Marker sizes are expressed as a Size of X,Y
  // where the origin of the image (0,0) is located
  // in the top left of the image.

  // Origins, anchor positions and coordinates of the marker
  // increase in the X direction to the right and in
  // the Y direction down.
  var image = {
    url: 'https://www.slac.stanford.edu/comp/net/tulip/dot.png',
  };
  // Shapes define the clickable region of the icon.
  // The type defines an HTML &lt;area&gt; element 'poly' which
  // traces out a polygon as a series of X,Y points. The final
  // coordinate closes the poly by connecting to the first

  for (var i = 0; i < locations.length; i++) {
    var beach = locations[i];
    var myLatLng = new google.maps.LatLng(beach[1], beach[2]);
    var marker = new google.maps.Marker({
        position: myLatLng,
        map: map,
        icon: image,
        title: beach[0],
        zIndex: beach[3]
    });
  }
}

function setMarkers2(map, locations) {
  // Add markers to the map

  // Marker sizes are expressed as a Size of X,Y
  // where the origin of the image (0,0) is located
  // in the top left of the image.

  // Origins, anchor positions and coordinates of the marker
  // increase in the X direction to the right and in
  // the Y direction down.
  var image = {
    url: 'https://www.slac.stanford.edu/comp/net/tulip/dot_blue.png',
  };
  // Shapes define the clickable region of the icon.
  // The type defines an HTML &lt;area&gt; element 'poly' which
  // traces out a polygon as a series of X,Y points. The final
  // coordinate closes the poly by connecting to the first

  for (var i = 0; i < locations.length; i++) {
    var beach = locations[i];
    var myLatLng = new google.maps.LatLng(beach[1], beach[2]);
    var marker = new google.maps.Marker({
        position: myLatLng,
        map: map,
        icon: image,
        title: beach[0],
        zIndex: beach[3]
    });
  }
}


google.maps.event.addDomListener(window, 'load', initialize);

</script></div>\n</div>\n<br>
<div id=\"footer\">
<center>
<h4>Created by: Raja Asad {rajaasad\@slac.stanford.edu}</h4>
</center>
</div>
</body>\n</html>\n";
close $fh;

sub scircle
{
	print"<!--";
	my $num=shift; my @scirc;
	
	for (my $i=0; $i < (scalar @degran);$i++)
	{
		no warnings 'numeric';
		(my $thetad, my $phid, my $dird) = great_circle_destination(sprintf("%.5f",(deg2rad($sorted[$num]->[1]))), sprintf("%.5f",(pi/2 - deg2rad($sorted[$num]->[0]))), sprintf("%.5f",(pi/2 - deg2rad($degran[$i]))), ($sorted[$num]->[2])/$rho);
		push(@scirc,[(rad2deg(sprintf("%.5f",$phid))),rad2deg(sprintf("%.5f",($thetad)))]);
	}
	print"-->";
	return @scirc;
}
sub scircle2
{
	print"<!--";
	my $num=shift; my @scirc;
	for (my $i=0; $i < (scalar @degran);$i=$i+2)
	{
		(my $thetad, my $phid, my $dird) = great_circle_destination(deg2rad($sorted2[$num]->[1]), pi/2 - deg2rad($sorted2[$num]->[0]), pi/2 - deg2rad($degran[$i]), ($sorted2[$num]->[2])/$rho);
		push(@scirc,[(rad2deg($phid),rad2deg($thetad))]);
	}
	print"-->";
	return @scirc;
}
sub sarc
{
	print"<!--";
	my $num=$_[0]; my @sar; my $inc=1;
	my @arcran=@{$_[1]};
	#print @arcran;
	if ((scalar @arcran) > 200) {$inc=2;}
	for (my $i=0; $i < (scalar @arcran);$i=$i+$inc)
	{
		(my $thetad, my $phid, my $dird) = great_circle_destination(deg2rad($sorted[$num]->[1]), pi/2 - deg2rad($sorted[$num]->[0]), ($arcran[$i]), ($sorted[$num]->[2])/$rho);
		push(@sar,[(rad2deg($phid),rad2deg($thetad))]);
	}
	print"-->";
	return @sar;
}
sub sarc2
{
	print"<!--";
	my $num=$_[0]; my @sar; my $inc=1;
	my @arcran=@{$_[1]};
	#print @arcran;
	if ((scalar @arcran) > 200) {$inc=2;}
	for (my $i=0; $i < (scalar @arcran);$i=$i+$inc)
	{
		(my $thetad, my $phid, my $dird) = great_circle_destination(deg2rad($sorted2[$num]->[1]), pi/2 - deg2rad($sorted2[$num]->[0]), ($arcran[$i]), ($sorted2[$num]->[2])/$rho);
		push(@sar,[(rad2deg($phid),rad2deg($thetad))]);
	}
	print"-->";
	return @sar;
}
sub getaddr{
  my $name=$_[0];
  if($name=~/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/) {
    return $name;#Input is a valid IP address
  }
  elsif($name !~ /[\w\.\-]+/) {#Valid characters in name
    return "Invalid target=$name is not an IP address or name. ";
	print "<h4>Invalid target=$name is not an IP address or name.</h4>"
  }
  else {#Input is a valid IP name
    my $ipaddr=gethostbyname($name);
    if(!defined($ipaddr)) {
      return "Unknown name=$name. ";
    }
    my ($a, $b, $c, $d)=unpack('C4',$ipaddr);
    $ipaddr=$a.".".$b.".".$c.".".$d;
    return $ipaddr;
  }
} 

#####################################################################
#  My Code End
#####################################################################

__DATA__
Typical output from reflector.cgi follows:
Content-type: text/html

<html>
<head>
 Client=134.79.200.28 probing landmarks in region=all, tier=0, type=PingER,perfSONAR,PlanetLab, ability=1, debug=0<br>
<title>Tulip</title></head><body>

Total landmark domains (=domain) in http://www.slac.stanford.edu/comp/net/wan-mon/tulip/sites.xml = 2, PlanetLab servers = 2, Pinger servers = 10, PerfSONAR servers = 6, landmark=all, type=PingER,perfSONAR,PlanetLab, target=134.79.18.188, tier=0, region=all, ability=1, debug=0, version=2.8 Zafar & Cottrell 8/27/2011<br>
Landmark(3)=http://users.sdsc.edu/cgi-bin/traceroute.pl?target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, failed to connect:404
<br>Landmark(1)=http://pinger.sesame.org.jo/cgi-bin/traceroute.pl?target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, failed to connect response code 408 <br>
Landmark(2)=http://andrew.triumf.ca/cgi-bin/traceroute.pl?target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, 5 packets transmitted, 5 received, 0% packet loss, rtt min/avg/max = 21.907/22.008/22.167<br>
Landmark(2)=http://pinger.cern.ch/cgi-bin/traceroute.pl?target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, 5 packets transmitted, 5 received, 0% packet loss, rtt min/avg/max = 180.120/181.487/183.393<br>
Landmark(1)=http://mel-a-ext1.aarnet.net.au/cgi-bin/traceroute.pl?target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, failed to connect response code 408 <br>
Landmark(2)=http://pinger.ictp.it/cgi-bin/traceroute.pl?target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, 5 packets transmitted, 5 received, 0% packet loss, rtt min/avg/max = 207.377/207.629/207.845<br>
Landmark(1)=http://pingerkhi-cpsp.pern.edu.pk/cgi-bin/traceroute.pl?target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, failed to connect response code 408 <br>
Landmark(1)=http://pingerlhr-gcu.pern.edu.pk/cgi-bin/traceroute.pl?target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, failed to connect response code 408 <br>
Landmark(2)=http://pinger.cdac.in/cgi-bin/traceroute.pl?target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, 5 packets transmitted, 5 received, 0% packet loss, rtt min/avg/max = 258.980/259.142/259.600<br>
Landmark(2)=http://icfamon.rl.ac.uk/cgi-bin/traceroute.pl?target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, 5 packets transmitted, 5 received, 0% packet loss, rtt min/avg/max = 158.502/159.676/159.973<br>
Landmark(1)=200.128.79.36target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, failed to connect response code 501 <br>
Landmark(1)=perfsonar.ihep.ac.cntarget=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, failed to connect response code 501 <br>
Landmark(1)=140.123.4.15%20target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, failed to connect response code 501 <br>
Landmark(1)=200.136.80.19target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, failed to connect response code 501 <br>
Landmark(1)=140.110.209.193target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, failed to connect response code 501 <br>
Landmark(1)=134.75.248.50target=134.79.18.188&function=ping, Client=134.79.200.28,  ability=1, failed to connect response code 501 <br>
Landmark(1)=http://kupl1.ittc.ku.edu:3355, Client=134.79.200.28, target=134.79.18.188,  ability=1, failed to connect response code 500 <br>
Landmark(2)=http://planetlab1.inf.ethz.ch:3355, Client=134.79.200.28, target=134.79.18.188,  ability=1, 10 packets transmitted, 10 received, 0% packet loss, rtt min/avg/max = 192.490/192.8062/194.552<br>
<p>reflector.cgi: processed http://www.slac.stanford.edu/comp/net/wan-mon/tulip/sites.xml(2), client=134.79.200.28, target=134.79.18.188, region=all, tier=0, type=PingER,perfSONAR,PlanetLab, ability=1, landmark = all, landmarks available=18, landmarks used PL=2, SLAC=10, PS=6, dupes=0, parallel=20, threads=80, duration=18 secs<br>

</body></html>

__END__
# /*---------------------------------------------------------------*/
# /*          STANFORD UNIVERSITY NOTICES FOR SLAC SOFTWARE        */
# /*               ON WHICH COPYRIGHT IS DISCLAIMED                */
# /*                                                               */
# /* AUTHORSHIP                                                    */
# /* This software was created by Les Cottrell, Stanford Linear    */
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
# Copyright (c) 2011
# The Board of Trustees of          
# the Leland Stanford Junior University. All Rights Reserved.       
#  Please send comments and/or suggestion to Les Cottrell.
#
# **************************************************************** 
# Owner(s): Les Cottrell (5/30/2011).                                
# Revision History:                                                
#########################################################################
