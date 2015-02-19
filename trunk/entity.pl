#!/opt/local/bin/perl -w 

use Chatbot::Eliza;
use WWW::Google::CustomSearch;
use POSIX;
use Time::HiRes qw(sleep);
use Data qw($api_key $cx);

use strict; 
use warnings;


#defaults for command line
my $entity_mail = "pgioio\@mit.edu";
my $entity_name = "Paul Gioio";
my $debug_on = 0;
my $no_net = 0;
my $quick_on = 0;
my $filter_on = 1;


# initialize your data  api_key and cx
my $engine  = WWW::Google::CustomSearch->new(api_key => $api_key, cx => $cx);
open my $fh, "<", "badwords.txt" or die $!;

###############################################################################
sub searchable
{
    my ($msg) = @_;
# temp deprecated, must find better patterns that make sense
    return 1 if (length($msg)>1);
#return 0;

    return 0;
}
###############################################################################
sub juice
{
    my ($raw_msg) = @_;
    my $ret;

# Regular expression to filter snippet:
# - ending with a . or ? or !
# - when delimited by '.', shoult be a single '.'
# - non-greedy, min lenght 20
# - not containing ...

#$raw_msg =~ /(.*?)([\.|\?|!])/si;
#$raw_msg =~ /(.{20,}?)([\.|\?|!]{1})/si;

#
# Including multiple sentences separated by period, but not starting with ...
#([.]{3}[^.]+.)?(([^.]\.[^.]|[^.]){20,}?[.?!])[^.]

# Including multiple sentences separated by period
#((([^.]\.[^.])|([^.])){20,}?[.?!])[^.]
    
# Single sentence ending with period
#([^.]{20,}?[.?!])[^.]

#TODO: better way than adding extra char 
    $raw_msg = $raw_msg.'  ';

    if ($raw_msg =~ /([.]{3}[^.]+\.)|(([^.]\.[^.]|[^.]){20,}?[.?!])[^.]/si)
    {
	if (defined($2))
	{
	    $ret = $2;
	    $ret =~ s/\.$//si;

	    my $number = () = $ret =~ /\d+/gis;

	    return $ret if ($number<3);
	}
    }

    return "NOT_MATCH";

}
###############################################################################
sub sanity_check
{
    my ($msg) = @_;

    if (length($msg)<15)
    {
	print "\n --> Sanity check FAILED, discarding for short lenght..." if $debug_on;
	return 0;
    }

    if ($filter_on)
    {
	print "\n --> Applying badword filter..." if $debug_on;
	seek $fh, 0, 0;

	while (<$fh>) {
	    my $mi = $_;
	    $mi =~ s/\r|\n//g;
#print "\n MESSAGE IS $msg ";
#print "\n >>>> Filter checking for $mi ";
            if ($msg =~ /\b$mi\b/si)
	    {
		print "\n --> Sanity check FAILED, found forbidden word $mi" if $debug_on;
		return 0;
	    }
	}
    }

    print "\n--> Sanity check OK!" if $debug_on;
    return 1;
}

###############################################################################
sub nett
{
    my ($msg) = @_;

    print "\n DEBUG: ** Google API searching ** : $msg\n" if $debug_on;

    my $result = eval { $engine->search($msg) };

    if (!defined($result)) 
    {
	print "\n DEBUG: **UNDEF NET RESPONSE**, err: $@ " if $debug_on;
	return undef;
    }

    my $clean;
    my $n = 0;
    my @responses;


    foreach my $item (@{$result->items}) 
    {
	$clean = &juice($item->snippet);

	if ($debug_on)
	{
	    print "\n --------------------------------------------------------------";
	    print "\n Response n.$n";
	    print "\n --------------------------------------------------------------";
	    print "\n RAW: <<< ", $item->snippet, " >>>" if defined $item->snippet;
	    print "\n --------------------------------------------------------------";
	    print "\n CLEAN: <<< " , $clean, " >>>" if defined $clean;
	    print "\n --------------------------------------------------------------";
	}

	if (&sanity_check($clean)) 
	{
	    push @responses, $clean;
	    $n++;
	}
    }
    my $chosen= int(rand($n));
    return $responses[$chosen];
}

###############################################################################
sub typing
{
    my ($msg) = @_;
#sleep(int(length($msg)/10)) unless $quick_on;

    my $start = 0;
    my $count = 0;

    if (!$quick_on)
    {
	while ( $start<length($msg) )
	{
	    $count = int(rand(3)+1);
	    my $speed = (rand)*0.2;
	    sleep($count*$speed);
	    my $snippet = substr($msg,$start,$count);

	    print $snippet;
	    if ($snippet =~ /(.*?)\s/)
	    {
		if (rand(5)<1) 
		{
		    sleep(int(rand(3)));
		}
	    }

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
    system("clear");

    print "\n______________________________________________________\n";
    print "   Welcome to the c0n5c10u5n3t Project!  \n";
    print "______________________________________________________\n";
    print " Session local time: $now\n";
    sleep(1);
    print " Initializing system entity:  $entity_mail\n";
    sleep(1);
    print " Please wait\n";
    sleep(1);

    my $x = 10;

    while ($x--)
    {
	print ".";
	sleep(0.2);
    }

    print "\n Connected !\n";
    print "\n=====================================================\n";

    print "$entity_name: ";
    sleep(2);
#typing ("Hi, I'm doc Gioio, prof. Patti told me we have about 10 minutes,\n tell me something (family, work, hobby, ideas, etc...)");
    typing ("Hallo, I'm testing the network \n just a quick chat, tell me something (family, work, hobby, etc...)");
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
        scriptfile => "attitude.dat",
	debug      => 1, prompts_on => 1, memory_on  => 1,
	myrand     => sub { my $N = defined $_[0] ? $_[0] : 1;  rand($N); },
};

# typing($bot->{initial}->[0] . "\n");

my $true++;
my $now = localtime;
my $starting_time = time();

$now =~ s/\s/_/g;

open(LOG, ">> log_$now.txt");

my $last_msg = "none";
my $question_counter = 0;
my $last_to_go = 0;

while ($true) 
{
    select((select(LOG), $|=1)[0]);

    print "You: ";

    my $message = <STDIN>;

    $now = localtime;
    print LOG "[$now] You: $message";

    exit if ($last_to_go);
START:
    my $reasmb = $bot->transform($message);
    my $answer = $reasmb;  #already done if is not a NET response...

# check for NET response
    if ($reasmb=~/NET/)
    {
	print "\n  DEBUG--> selected NET meta-response: $reasmb" if ($debug_on);

	$reasmb =~ s/(.*)NET(.*)/$2/g;

	$reasmb =~ s/(.*)xnone(.*)/$1$2/g;

	if (&searchable($reasmb))
	{
	    my $search_result = &nett($reasmb);
	    if (!defined($search_result)) 
	    {
		print "\n  DEBUG--> skipping empty/undef search result of: $reasmb" if ($debug_on);
		goto SKIP_NET;
	    }
	    $answer = $search_result;
	}
	else #if not searchable (e.g. "yes" only response, too generic)
	{
	    print "\n  DEBUG--> skipping not searchable pattern: $reasmb" if ($debug_on);
SKIP_NET:
	    my $tmp_answer;
	    until ( ($tmp_answer = $bot->transform($message))!~/NET/  ) 
	    {
		print "\n DEBUG--> skipping NET response $tmp_answer" if ($debug_on);
	    };
	    $answer = $tmp_answer;
	} # not searchable
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


    print "$entity_name: ";
    sleep(length($message)*0.1+0.5) unless $quick_on;
    typing("$answer");
    $question_counter++;


    if ( (time() - $starting_time) >600 || $question_counter==15)
    {
	print "$entity_name: ";
	sleep(1);
	typing("Ok, that's all. Thank you for your collaboration. Bye");
	$last_to_go = 1;
    }
		

    $now = localtime;
    print LOG "[$now] $entity_name: $answer\n";
}

exit;
