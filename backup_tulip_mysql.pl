#!/usr/local/bin/perl -w
#See https://confluence.slac.stanford.edu/display/IEPM/IEPM+Perl+Coding+Styles
#for version of perl to use.

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
# Copyright (c) 2009
# The Board of Trustees of
# the Leland Stanford Junior University. All Rights Reserved.
####################################################################
#The following code is placed at the top to ensure we are able to use perl -d
#and stop things before they call other things.
my $debug=0;
     #For cronjobs use -1, for normal execution from command line use 0,
     #for debugging information use > 0, max value = 3.
if (-t STDOUT) { $debug = 0; }
else { $debug = -1; }    #script executed from cronjob
use strict;

#  Please send comments and/or suggestion to Les Cottrell.
#
# ****************************************************************
# Creater(s): Fahad Satti (02/20/10).
# Revision History:
# --- 
# ****************************************************************
#Get some useful variables for general use in code
umask(0002);
use DBI;
use Sys::Hostname;
my $ipaddr = gethostbyname(hostname());
my ($a, $b, $c, $d) = unpack('C4', $ipaddr);
my ($hostname, $aliases, $addrtype, $length, @addrs) =
  gethostbyaddr($ipaddr, 2);
#use Date::Calc qw(Add_Delta_Days Delta_Days Delta_DHMS);
#use Date::Manip qw(ParseDate UnixDate);
use Time::Local;
use POSIX qw(strftime);
(my $progname = $0) =~ s'^.*/'';    #strip path components, if any
my $user        = scalar(getpwuid($<));
my $help;
my $version = "0.1 02/20/10, Fahad Ahmed Satti";
my $backuppath="/scratch/mysql";
my $gzip = "/bin/gzip";
my $dow = strftime("%U", localtime);
our $db = {
          'user'  => 'scs_tulip_u',
          'host'  => 'mysql-node01',
          'port'  => '3307',
          'dbname'=> 'scs_tulip',
        };
my $dbi;
use Getopt::Long;
my $ok = GetOptions(
  'debug|v=i'         => \$debug,
  'help|?|h'          => \$help,
  'backup_path|b=s'   => \$backuppath,
  );
if ($help) {
  my $USAGE="Usage: $0 options\n
  Purpose:
   $progname is used to create a backup of TULIP mysql database.
  Version:
   $version.
  Options:
  \t--help|-h         \tDisplay this help.\n
  \t--debug|-v        \tSet debug value, to increase or decrease the amount of output.\n
  \t                  \t [default = $debug]\n
  \t--backup_path|-b  \tSet the path where backup file for mysql should be stored.\n
  \t                  \t [default = $backuppath]\n
Output:
  none, if debug is less than 1;
Examples:
   $progname
   $progname --debug 1
   $progname -b=/scratch/mysql/
  ";
  print $USAGE;
  exit 1;
} ## end if ($help)

require "/afs/slac/g/scs/net/pinger/bin/admin.pl";
our $pwd = &gtpwd('tulip');
$db->{'password'} = $pwd;
$dbi              =
    'DBI:mysql:mysql_socket=/var/lib/mysql/mysql.sock;host='
  . $db->{host}
  . ';port='
  . $db->{port}
  . ';database='
  . $db->{dbname};
  
  #Set up the database.
  my $dbh = DBI->connect($dbi, $db->{user}, $db->{password})
    or die "Could not connect to 'db->{host}': $DBI::errstr";
  if(!(-d $backuppath)){
    `mkdir -p $backuppath`;
    if($debug>0){
     print "$backuppath was not found. creation attemp complete.\n";
    }
  }
  my $query_showTables = "show tables";
  my $query_tables = $dbh->prepare($query_showTables);
  $query_tables->execute();
  my $dumpTableArgs = "--add-drop-table --allow-keywords -q -a -c";
  while (my @tables = $query_tables->fetchrow_array()) {
    if($debug>0){
      print "Dump procedure started for table:".$tables[0]."\n";
    }
    if(!(-d "$backuppath/$dow" )){
      my $mkdirCmd = 'mkdir -p '.$backuppath.'/'.$dow;
      `$mkdirCmd`;
      if($debug>0){
        print "Creating, current day of week sub-dir. complete path:".$backuppath.'/'.$dow."\n";
      }
    }
    my $dumpFile = $backuppath.'/'.$dow.'/'.$tables[0].'.sql';
    my $dumpTable = `mysqldump --port 3307 -h mysql-node01 $dumpTableArgs -u $db->{user} --password=$db->{password}   scs_tulip $tables[0] > $dumpFile`;
    if($debug>0){
      print "Table Dump procedure finish.\n";
    }
    if(-e $backuppath.'/'.$dow.'/'.$tables[0].'.sql.gz.old' ){
      my $rmCmd = "rm ". $backuppath.'/'.$dow.'/'.$tables[0].'.sql.gz.old';
      if($debug>0){
        print "removing old backup file:\n".$rmCmd."\n";
      }
      `$rmCmd`;
    }
    if(-e $backuppath.'/'.$dow.'/'.$tables[0].'.sql.gz'){
      my $mvCmd = "mv ".$backuppath.'/'.$dow.'/'.$tables[0].'.sql.gz '
                . $backuppath.'/'.$dow.'/'.$tables[0].'.sql.gz.old ';
      if($debug>0){
        print "moving current zipped backup file to old:\n".$mvCmd."\n";
      }
      `$mvCmd`;
    }
     my $zipCmd = "$gzip $backuppath".'/'.$dow.'/'.$tables[0].'.sql';
     if($debug>0){
       print "gzip backup file:\n".$zipCmd."\n"; 
     }
     `$zipCmd`; 

  }

##########OLD Shell Script######################

#d=`date +%u`
#backuppath=/scratch/mysql/
#pwdfile=/u1/mysql/pws-tulip

#mkdir -p $backuppath
#for i in `echo "show tables" | mysql -u tulip --password=\`cat $pwdfile\` tulip|grep -v Tables_in_`;
#do
   #echo "Backup of table $i"
#   mysqldump --add-drop-table --allow-keywords -q -a -c -u tulip \
#     --password=`cat $pwdfile` tulip $i > $backuppath/$d/$i.sql
#   if [ -w $backuppath/$d/$i.sql.gz.old ]; then
#     rm $backuppath/$d/$i.sql.gz.old
#   fi
#   mv $backuppath/$d/$i.sql.gz $backuppath/$d/$i.sql.gz.old
#   #echo "Compressing Files for table $i..."
#   gzip $backuppath/$d/$i.sql
#done
#echo "Complete" 
