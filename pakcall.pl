#!/usr/bin/env perl
use strict; 
use warnings; 
use LWP::Simple;

#####################################################################
#This script just calls the South Asia landmarks to ping slac.
#It is run by trscrontab everyday in order to help laundering
#####################################################################

my $URL='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?region=South%20Asia&target=pinger.slac.stanford.edu&tier=all&type=all&ability=1&debug=0';
my $raw = get($URL);
$URL='http://www-wanmon.slac.stanford.edu/cgi-wrap/reflector.cgi?region=South%20Asia&target=pinger.slac.stanford.edu&tier=all&type=all&ability=0&debug=0';
$raw = get($URL);