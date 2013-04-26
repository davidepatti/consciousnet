#!/opt/local/bin/perl -w 

use Chatbot::Eliza;
use WWW::Google::CustomSearch;
use POSIX;
use Time::HiRes qw(sleep);
use Data qw($api_key $cx);

use strict; 
use warnings;


my $entity_mail = "pgiogio\@mit.edu";
my $entity_name = "PGioio";
my $debug_on = 0;
my $no_net = 0;
my $quick_on = 0;
my $filter_on = 0;
my $engine  = WWW::Google::CustomSearch->new(api_key => $api_key, cx => $cx);

###############################################################################
sub searchable
{
    my ($msg) = @_;
    return 1 if (length($msg)>4);
    return 0;
}
###############################################################################
sub juice
{
    my ($raw_msg) = @_;
#extract the part that cite the main elements of the query and that ends with a . or ?
    $raw_msg =~ /(.*?)([\.|\?|!])/i;
    my $msg = "$1$2";
}
###############################################################################
sub sanity_check
{
    my ($msg) = @_;
    my $pass = 1; # ok is default
    $pass=0 if (length($msg)<15);
    if ($filter_on)
    {
	$pass=0 if $msg=~ /sex|porn|fuck|porno/;
    }
    $pass;
}

###############################################################################
sub nett
{
    my ($msg) = @_;

    if ($debug_on)
    {
	print "\n DEBUG--> Google API searching: ";
	print $msg, "\n"; 
    }
    my $result = $engine->search($msg);
    my $clean;
    my $n = 0;

    my @responses;

    foreach my $item ($result->items) 
    {
	$clean = &juice($item->snippet);
	if (&sanity_check($clean))
	{
	    push @responses, $clean;
	    $n++;
	}
	elsif ($debug_on)
	{
	    print "\n DEBUG: **DISCARDING RESULT** (sanity_check false)";
	}

	if ($debug_on)
	{
	    print "\nDEBUG raw: <<< ", $item->snippet, " >>>" if defined $item->snippet;
	    print "\nDEBUG clean: <<< " , $clean, " >>>\n";
	}
    }
    my $chosen= int(rand($n));
    $responses[$chosen];
}

###############################################################################
sub typing
{
    my ($msg) = @_;
#sleep(int(length($msg)/10)) unless $quick_on;
    print "$entity_name> ";

    my $start = 0;
    my $count = 0;

    if (!$quick_on)
    {
	while ( $start<length($msg) )
	{
	    $count = int(rand(5));
	    my $speed = (rand)*0.3;
	    sleep($count*$speed);
	    print substr($msg,$start,$count);
	    $start+=$count;
	}
    }
    else
    {
	print $msg;
    }
    print "\n";
}

###############################################################################
sub greetings
{
    my $now = localtime;

    print "\n______________________________________________________\n";
    print "   c0n5c10u55n3t  \n";
    print "______________________________________________________\n";
    print " session local time: $now\n";
    print " > Initializing system entity: ", $entity_mail, "\n";
    print " > Please wait\n";

    my $x = 10;

    while ($x--)
    {
	print ".";
	sleep(0.1);
    }

    print "\n Connected !\n";
    print "\n=====================================================\n";

    typing ("Hi, I'm doctor Gioio, prof. Patti said me we have about 4-5 minutes");
    typing ("Tell me something (family, work, hobby, ideas, etc...)");
}

###############################################################################
sub parse_cmdline
{
    for my $arg (@ARGV)
    {
	$debug_on = 1 if $arg eq "debug";
	$no_net = 1 if $arg eq "no_net";
	$quick_on = 1 if $arg eq "quick";
	$filter_on = 1 if $arg eq "filter";
    }

}

######################################################################
$|++;
&parse_cmdline;
&greetings;

my $bot = new Chatbot::Eliza {
	name       => "Paul", 
        scriptfile => "nettgw.txt",
	debug      => 1, prompts_on => 1, memory_on  => 1,
	myrand     => sub { my $N = defined $_[0] ? $_[0] : 1;  rand($N); },
};

# typing($bot->{initial}->[0] . "\n");

my $true++;
my $now = localtime;

open(LOG, ">> log_$now.txt");

my $last_msg = "none";

while ($true) 
{
    select((select(LOG), $|=1)[0]);

    print "You> ";

    my $message = <STDIN>;

    $now = localtime;
    print LOG "[$now] You: $message";

START:
    my $reasmb = $bot->transform($message);
    my $answer = $reasmb;  #already done if is not a NET response...

# check for NET response
    if ($reasmb=~/NET/)
    {
	$reasmb =~ s/(.*)NET(.*)/$2/g;
	if (&searchable($reasmb))
	{
	    my $search_result = &nett($reasmb);
	    if (!defined($search_result)) 
	    {
		print "\n  DEBUG--> skipping empty search result of: $reasmb" if ($debug_on);
		goto SKIP_NET;
	    }
	    $answer = $search_result;
	}
	else #if not searchable (e.g. "yes" only response, too generic)
	{
SKIP_NET:
	    print "\n  DEBUG--> skipping not searchable pattern: $reasmb" if ($debug_on);
	    my $tmp_answer;
	    until ( ($tmp_answer = $bot->transform($message))!~/NET/  ) 
	    {
		print "\n DEBUG--> skipping NET response $tmp_answer" if ($debug_on);
	    };
	    $answer = $tmp_answer;
	}
    }

    if ($debug_on)
    {
	my $debugging  = $bot->debug_text;
	print $debugging;
	$bot->_debug_memory();
    }

    if ($answer eq $last_msg)
    {
	print "\n DEBUG--> skipping repeated: $answer" if ($debug_on);
	goto START;
    }

    $last_msg = $answer;


    sleep(length($message)*0.1) if (!$quick_on);
    typing("$answer\n");
    $now = localtime;
    print LOG "[$now] $entity_name: $answer\n";
}

exit;
