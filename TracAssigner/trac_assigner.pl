#!/bin/perl

# trac_assigner.pl - assign macports tickets automatically to maintainer
# Copyright 2013 Eric Le Lay <elelay@macports.org>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;

use LWP::UserAgent;    # get it via port install p5-libwww-perl
use HTML::TreeBuilder; # get it via port install p5-html-tree
use Expect;            # get it via port install p5-expect
use Getopt::Long;


############################
# constants
############################
# a ticket is a dict 
# id => trac id
use constant ID => 'id';
# port => port
use constant PORT => 'port';
# maintainer (internal)
use constant MAINTAINER => 'maintainer';
# cc
use constant CC => 'cc';

# stats constants
use constant NO_PORT  => 'no_port';
use constant NO_MAINT => 'no_maint';
use constant OK       => 'ok';

############################
# utility function, removes whitespace before and after
# @param s string to trim
# @return s without whitespace at begining or end
############################
sub trim {
	my ($s) = @_; 
	$s =~ s/^\s+(.+)\s$/$1/;
	$s =~ s/\r//g; # remove rogue \r not trimmed by above expression
	return $s;
}

# must keep it around for cookies
my $ua = LWP::UserAgent->new;
# keep cookies
$ua->cookie_jar( {} );
# set user agent as courtesy to macports stats if any
$ua->agent("User-Agent: $0");

############################
# fetch all new tickets on ports with owner macports-tickets
# don't fetch requests for new ports or port submissions since they wouldn't
# have an existing port.
# @param  limit how many tickets to fetch
# @return unparsed HTML results of advanced query
############################
sub fetchResults {
	my ($limit) = @_;
    my $url = 'https://trac.macports.org/query?status=new&type=!request&type=!submission&owner=^macports-tickets%40lists.macosforge.org&component=ports&col=id&col=owner&col=port&col=cc&report=11&max='. $limit;
    
    my $response = $ua->request(
    	HTTP::Request->new( GET => $url )
    	);
    unless($response->is_success) {
    	die "Couldn't get tickets: ", $response->status_line, "\n";
    }
    return $response->decoded_content;
}

############################
# parse HTML results into ticket list
# @param  results HTML results from query (or saved file for testing)
# @return list of hashrefs with
#         ID => id of the ticket (without hash)
#         PORT => list of presumably port names
############################
sub parseResults {
	my ($results) = @_;
	
	my @tickets = ();
	my $tree = HTML::TreeBuilder->new_from_content($results);
	
	my $results_table = $tree->look_down('_tag' => 'table',
	                                     'class' => 'listing tickets');
	$results_table || die "No results table in parsed results\n";
	my @results_rows = $results_table->look_down('_tag' => 'tbody')->look_down('_tag' => 'tr');
	
	for my $result_row (@results_rows) {
		my %result = ();
		$result{ID} = trim($result_row->look_down('class' => 'id')->as_text);
		die "E: Invalid ticket id: ${result{ID}}\n" unless($result{ID} =~ m/#\d+/);
		$result{ID} =~ s/^#//;
		my $ports = trim($result_row->look_down('class' => 'port')->as_text);
		my @port_list = split(/[\s,]+/,$ports);
		$result{PORT} = \@port_list;
		push(@tickets,\%result);
	}
	return @tickets;
}


############################
# open pipe to port in interactive mode
# checks that the welcome message shows up before returning
# You can make it distant by setting the command to 'ssh YOUR_HOST port';
# it will work fine.
############################
sub initPortExpect {
	my $exp = Expect->spawn("port") or die "Cannot execute port command: $!\n";

	my @results = $exp->expect(30, 
		[ qr/Macports 2\.\d\.\d$/, sub {exp_continue;} ],
		[ qr/Warning: port definitions are more than two weeks old.*$/, 
			sub { print "W: port definitions are more than two weeks old.\n";
			      exp_continue;}
		],
		[ qr/Entering interactive mode...+$/ ]);
	
	unless(defined($results[0])){
		die ("Unexpected error executing port command: " . $results[1]);
	}
	
	$exp->log_stdout(0);
	
	return $exp;
}

############################
# query port for maintainer
# @param exp      open pipe to port
# @param portname port name to query
# @return empty list if port not found, unfiltered maintainers list otherwise
############################
sub getMaintainer {
	my ($exp,$portname) = @_;
	
	$exp->send("info --maintainer $portname\n");
	
	my ($matched_pattern_position, $error) = $exp->expect(10, 
		 '-re', qr/Error: Port .+ not found/,
		 '-re', qr/maintainer: (.+)$/
		);
	unless(defined($matched_pattern_position)){
		die ("Unexpected error: " . $error);
	}
	if($matched_pattern_position == 1){
		return ();
	} elsif($matched_pattern_position == 2){
		my $maintainers = trim(($exp->matchlist)[0]);
		return split(/, /,$maintainers);
	}
}

############################
# set the maintainer field in ticket (calls port to get it),
# filtering openmaintainer and nomaintainer out.
# @param exp       open pipe to port
# @param ticketref hashref to ticket
# @return 0 if OK, -2 if no port, -3 if no maintainer
############################
sub setMaintainers {
	my ($exp,$ticketref) = @_;
	my %ticket = %{$ticketref};
	my @ports = @{$ticket{PORT}};

	if(scalar(@ports) == 0){
		return -2;
	}

	my %maintainers_dedup = ();
	for my $port (@ports){
		if($port =~ m/\w+/ ){
			my @maintainerstmp = &getMaintainer($exp, $port);
			if(scalar(@maintainerstmp) == 0){
				my $id = $ticket{ID};
				print "W: $id wrong portname: $port\n";
			}
			# print "maintainers for $port: " . join(', ',@maintainerstmp) . "\n";
			# use a hash so that if same maintainer for multiple ports, the maintainer
			# is not added multiple times (e.g. ticket #23279)
			for my $maintainer (grep {!/(open)|(no)maintainer\@macports.org/} @maintainerstmp){
				$maintainers_dedup{$maintainer} = 1;
			}
		}
	}
	my @maintainers = keys(%maintainers_dedup);
	$ticketref->{MAINTAINER} = \@maintainers;

	if(scalar(@maintainers == 0)){
			return -3;
	}else{
		return 0;
	}
}

############################
# login to TRAC to be able to modify tickets afterwards.
# @param username trac email
# @param password trac password
# @return 0 if OK, -1 on error
############################
sub loginToTRAC {
	my ($username,$password) = @_;
	
	my $url = "https://trac.macports.org/auth/login/?";
	
	my %data = ( "email" => $username,
				 "password" => $password,
				 "next"     => "/"
			   );
	
	my $response = $ua->post($url, \%data);
	unless ($response->code == 302) {
	   print ("E: couldn't connect to the forge : " . $response->status_line . "\n");
	   return -1;
	}
	
	return 0;
}

#
# modify TRAC contents: assign the ticket to the first maintainer
# and CC any other maintainer.
# @param ticketref reference to the ticket hash. Ticket must have maintainers.
# @param pretend   if true, will not modify TRAC but return 0
# @return          0 if OK, -1 on error
#
sub assign {
	my ($ticketref,$pretend) = @_;
	
	my %ticket = %{$ticketref};
	
	my $id = $ticket{ID};
	
	my @maintainers = @{$ticket{MAINTAINER}};
	
	die "ticket $id must have maintainers" unless(scalar(@maintainers) > 0);
	
	my $firstmaintainer = shift @maintainers;
	
	my $comment = "automatically assigning to first maintainer";

	my $existingcc = $ticket{CC};
	my $cc;
	if(scalar(@maintainers) > 0){
		$comment = "$comment, cc to other maintainers.";
		if($existingcc ne ''){
			$cc = "$existingcc, ";
		}
		# don't add already cc-ed maintainers
		@maintainers = grep { index($cc,$_) == -1 } @maintainers;
		$cc .= join(', ',@maintainers);
	}else{
		$cc = $existingcc;
	}
	
	if($pretend){
		print "D: pretend to assign $id to $firstmaintainer, CC: $cc\n";
		return 0;
	}
	
    my $url = "https://trac.macports.org/ticket/$id";
    
    my $response = $ua->get( $url );
    unless($response->is_success) {
    	print "E: Couldn't get ticket $url ", $response->status_line, "\n";
    	return -1;
    }
	
    my $content = $response->decoded_content;
    my $token;
    if($content =~ /<input type="hidden" name="__FORM_TOKEN" value="([^"]+)"/) {
    	$token = $1;
    }else{
    	print "E: no token in ticket contents";
    	return -1;
    }
    my $cnum;
    if($content =~ /<input type="hidden" name="cnum" value="([^"]+)"/) {
    	$cnum = $1;
    }else{
    	die "no cnum in ticket contents";
    }
    
    my $ts;
    if($content =~ /<input type="hidden" name="ts" value="([^"]+)"/) {
    	$ts = $1;
    }else{
    	die "no ts in ticket contents";
    }

	my %infos = ();
	$infos{'__FORM_TOKEN'} = $token;
	$infos{'comment'} = $comment;
	$infos{'field_cc'} = $cc;
	$infos{'action'} = 'reassign';
	$infos{'action_reassign_reassign_owner'} = $firstmaintainer;
	$infos{'submit'} = 'Submit changes';
	$infos{'ts'} = $ts;
	$infos{'cnum'} = $cnum;
	
	$url = "https://trac.macports.org/ticket/$id#trac-add-comment";
	my $response = $ua->post($url, \%infos);
	if ($response->code == 303) {
	   print "I: successfuly assigned $id to $firstmaintainer\n";
	}
	else {
	   print ("E: can't post $url " . $response->status_line, "\n");
	   print $response->decoded_content;
	   return -1;
	}
	
	return 0;
}


############################
# command-line parsing
############################

my $pretend   = 0;
my $me        = 0;
my $help      = 0;
my $login     = '';
my $password  = '';
my $ticket_id ='';
my $limit     = 10000;

my $usage = <<EUSAGE;
Usage: $0 [-p/retend] [-l/imit=n] [-me] <LOGIN> <PASSWORD> [TICKET_ID]
       $0 -h/elp

       -p/retend    don't modify TRAC contents
       -l/imit      only deal with n tickets ($limit by default)
       -me          only assign tickets for ports maintained by <LOGIN>
       -h/elp       print this usage

       LOGIN        login to trac.macports.org
       PASSWORD     password to trac.macports.org
       TICKET_ID    to only assign this ticket (for testing purpose)

EUSAGE

GetOptions ("pretend" => \$pretend, "help" => \$help,
	        "limit=i" => \$limit, "me" => \$me)  || die $usage;

if($help){
	print $usage;
	exit 0;
}


if(scalar(@ARGV) == 3){
	$ticket_id = pop @ARGV;
}

if(scalar(@ARGV) == 2){
	($login,$password) = @ARGV;
} else {
	die $usage;
}

die "$usage\nlimit must be strictly positive\n" unless($limit > 0);


############################
# main part
############################

my $status;
loginToTRAC($login,$password) if(!$pretend);
if($status == 0){
	print "I: successfuly logged in as $login\n";
}elsif($pretend){
	print "D: continuing even if not logged in\n";
}else{
	die "$usage\ncouldn't log in\n";
}

my $queryres = &fetchResults($limit);
my @tickets = &parseResults($queryres);
print "I: successfuly fetched and parsed results\n";

my $exp = &initPortExpect();

my %stats = ( NO_PORT  => 0,
			  NO_MAINT => 0,
			  OK       => 0);

for my $ticketref (@tickets){
	my %ticket = %{$ticketref};
	my $id = $ticket{ID};
	if($ticket_id eq '' || $ticket_id eq $id){
		$status = &setMaintainers($exp,$ticketref);
		if($status == -2){
			print "W: $id no portname\n";
			$stats{NO_PORT}++;
		}elsif($status == -3) {
			print "W: $id doomed: no maintainer\n";
			$stats{NO_MAINT}++;
		}else{
			if($me){
				my @maintainers = @{$ticketref->{MAINTAINER}};
				unless(grep $_ eq $login,@maintainers){
					print "D: ignoring ticket not maintained by me: $id\n";
					next;
				}
			}
			$status = &assign($ticketref,$pretend);
			if($status == -1){
				die "E: error assigning $id"
			}else {
				print "I: $id assigned\n";
				$stats{OK}++;
			}
		}
	}
}
$exp->hard_close();

print <<EOSTAT;

I:	$stats{OK} tickets assigned
I:	$stats{NO_PORT} tickets without or with incorrect port
I:	$stats{NO_MAINT} tickets for abandoned ports

EOSTAT

# my %testticket = (ID => '#13289', PORT => [], MAINTAINER => ['me@macports.org'], CC => '');
# my $result = &assign(\%testticket);
# print "result:$result\n";
