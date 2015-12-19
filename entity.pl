#!/opt/local/bin/perl -w 

use Chatbot::Eliza;
use WWW::Google::CustomSearch;
use POSIX;
use Time::HiRes qw(sleep);
use Data qw($api_key $cx);

use strict; 
use warnings;


#defaults for command line
my $entity_mail = "gioio\@work";
my $entity_name = "PaulGioio";
my $metaresponse = "metaresponse.meta";
my $debug_on = 0;
my $no_net = 0;
my $quick_on = 0;
my $filter_on = 1;
my $timeout = 0;
my $rnnexp = "annettexp_1.12.t7";
my $version = 0.9;

my $bot;


# initialize your data  api_key and cx
my $engine  = WWW::Google::CustomSearch->new(api_key => $api_key, cx => $cx);
open my $fh, "<", "badwords.txt" or die $!;


sub preprocess
{
    my ($user_input) = @_;
    my $ret = ucfirst($user_input);

    $ret =~ s/%/ percent/sig;
    $ret =~ s/\.$//si;
    $ret =~ s/^\s+//;

    return $ret;
}

###############################################################################
sub snippet_juice
###############################################################################
{
    my ($raw_msg) = @_;
    my $ret;

# Regular expression to filter snippet:
# - ending with a . or ? or !
# - when delimited by '.', shoult be a single '.'
# - Including multiple sentences separated by period, but not starting with ...
# - non-greedy, min lenght 20
# - not containing ...

#TODO: better way than adding extra char 
    $raw_msg = $raw_msg.'  ';

    if ($raw_msg =~ /([.]{3}[^.]+\.)?(([^.]\.[^.]|[^.]){20,}?[.?!])[^.]/si)
    {
	if (defined($2))
	{
	    $ret = $2;
	    $ret =~ s/\.$//si; # remove last .
	    $ret =~ s/\n//si;  # remove newlines
	    $ret =~ s/^\s+//;  # remove spaces at beginning

# typical bad results
	    $ret =~ s/Best Answer://si; 
	    $ret =~ s/Update://si;

	    return ucfirst($ret);


	}
    }
    return "NOT_MATCH";
}
###############################################################################
sub sanity_check
###############################################################################
{
    my ($msg) = @_;

    my $numbers = () = $msg =~ /\d+/gis;
    if ($numbers > 3)
    {
	print "\n\t--> Sanity check FAILED: too much numbers " if $debug_on;
	return 0;
    }

    my @text_words = split(/\s+/, $msg);
    my $num_words = scalar(@text_words);

    if ($num_words<4)
    {
	print "\n\t--> Sanity check FAILED: short lenght " if $debug_on;
	return 0;
    }

    if ($filter_on)
    {
	seek $fh, 0, 0;

	while (<$fh>) {
	    my $mi = $_;
	    $mi =~ s/\r|\n//g;
            if ($msg =~ /\b$mi\b/si)
	    {
		print "\n\t--> Sanity check FAILED: found forbidden word $mi" if $debug_on;
		return 0;
	    }
	}
    }
    return 1;
}

###############################################################################
sub net_inject
###############################################################################
{
    my ($msg) = @_;

    print "\nDEBUG: Google API searching: $msg\n" if $debug_on;

    my $result = eval { $engine->search($msg) };

    if (!defined($result))
    {
	print "\nDEBUG: UNDEF result in NET RESPONSE, err: $@ " if $debug_on;
	return undef;
    }
    
    if (!defined($result->items))
    {
	print "\nDEBUG: UNDEF items in  NET RESPONSE, err: $@ " if $debug_on;
	return undef;
    }

    my $clean;
    my $n = 0;
    my @responses;

    foreach my $item (@{$result->items}) 
    {
	$clean = &snippet_juice($item->snippet);

	if ($debug_on)
	{
	    print "\n";
	    print "\nDEBUG: **************************************************************";
	    print "\nDEBUG: NET Response n.$n";
	    print "\nDEBUG: --------------------------------------------------------------";
	    print "\nDEBUG: RAW: ", $item->snippet , " " if defined $item->snippet;
	    print "\nDEBUG: --------------------------------------------------------------";
	    print "\nDEBUG: CLEAN: $clean" if defined $clean;
	    print "\nDEBUG: --------------------------------------------------------------";
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
###############################################################################
{
    my ($msg) = @_;
    my $start = 0;
    my $count = 0;

    if (!$quick_on)
    {
	while ( $start<length($msg) )
	{
	    $count = int(rand(2)+1);
	    my $speed = (rand)*0.2;
	    sleep($count*$speed);
	    my $snippet = substr($msg,$start,$count);

	    print $snippet;

# pause when typing particular last chars in the snippet
	    if ($snippet =~ /[^.]\.(\s)?$/)
	    {
		sleep(1);
	    }

# as above, but not always
	    if ($snippet =~ /(\s|\.|,|:)$/)
	    {
		if (rand(4)<1) 
		{
		    sleep(0.5);
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
###############################################################################
{
    my $now = localtime;
    system("clear");

    print "______________________________________________________\n";
    print "   Consciousnet System v.$version\n";
    print "______________________________________________________\n";
    sleep(0.5);
    print "\n--> Starting session time: $now\n";
    sleep(0.5);
    print "--> Contacting system entity:  $entity_name\n";

    $bot = new Chatbot::Eliza {
	    scriptfile => $metaresponse,
	    debug      => 1, prompts_on => 1, memory_on  => 1,
	    myrand     => sub { my $N = defined $_[0] ? $_[0] : 1;  rand($N); },
    };
    if ( !($bot->name eq $entity_name) )
    {
	print "Cannot contact entity, please replace Eliza.pm with the provided repository version...\n";
	exit;
    }
    sleep(0.5);
    print "--> Here I am... \n";
    if (defined $rnnexp)
    {
	print "--> Trying to remember my past [$rnnexp] ";
	if (-e $rnnexp)
	{
	    print " ...Ok!\n";
	}
	else
	{
	    print " ...sorry, I can't remember\n";
	}
    }
    else
    {
	print " No past to remember...\n";
    }

    sleep(0.5);

    print "--> Ready to exist\n";
    print "\n=====================================================\n";

    print "\t$entity_name: ";
    sleep(0.5);
    typing ("Hi, I'm Paul Gioio, I'm testing my existence. Tell me about something (family, work, hobby, etc...)");
}

###############################################################################
sub parse_cmdline
###############################################################################
{
    for my $arg (@ARGV)
    {
	$debug_on = 1 if $arg eq "debug";
	$no_net = 1 if $arg eq "no_net";
	$quick_on = 1 if $arg eq "quick";
	$filter_on = 1 if $arg eq "filter";
	$timeout = 1 if $arg eq "timeout";
    }

}

######################################################################
# main source code
######################################################################
$|++;
&parse_cmdline;
&greetings;

my $true++;
my $now = localtime;
my $starting_time = time();

$now =~ s/\s/_/g;

open(LOG, ">> log_$now.$metaresponse.txt");

my $last_msg = "";
my $question_counter = 0;
my $last_to_go = 0;

while ($true) 
{
    print "\tYou: ";
    my $message = <STDIN>;
    $message = &preprocess($message);

    $now = localtime;
    select((select(LOG), $|=1)[0]);
    print LOG "[$now] You: $message";

# if timeout enabled
    exit if ($last_to_go);

# quit message
    if ($message=~/(.*)see you later/si) 
    {
	print "\t$entity_name: ";
	sleep(0.5);
	typing("ok, bye bye");
	exit;
    }
	
START:
    my $reasmb = $bot->transform($message);
    my $answer = ucfirst($reasmb);  #already done if is not a NET response...

# check for NET metaresponse
    if ($reasmb=~/NET/)
    {
	print "\nDEBUG: selected NET meta-response: $reasmb" if ($debug_on);

	$reasmb =~ s/(.*)NET(.*)/$2/g;
	$reasmb =~ s/(.*)xnone(.*)/$1$2/g;

	my $search_result = &net_inject($reasmb);

	if (defined($search_result)) 
	{
	    $answer = ucfirst($search_result);
	}
	else
	{
	    print "\nDEBUG: skipping empty/undef search result of: $reasmb" if ($debug_on);
	    my $tmp_answer;
	    until ( ($tmp_answer = $bot->transform($message))!~/NET/  ) 
	    {
		print "DEBUG: skipping NET response $tmp_answer" if ($debug_on);
	    };
	    $answer = ucfirst($tmp_answer);
	}
    }
#Check for Recurrent experience
    if ($reasmb=~/REXP/)
    {
	print "\nDEBUG: selected REXP meta-response: $reasmb" if ($debug_on);

	$message =~ s/(.*)REXP (.*)/$2/g;
	$message =~ s/\n//si;

	my $thcmd = "th sample.lua $rnnexp -temperature 0.5 -primetext \"\@\@\@: $message ___\" ";
	print "\n$thcmd\n";
	print "\n REXP rexponses currently unsupported, quitting\n";
	exit;
    }
    if ($debug_on)
    {
	my $debugging  = $bot->debug_text;
	print $debugging;
	$bot->_debug_memory();
    }

    if ($answer eq $last_msg)
    {
	print "\nDEBUG: skipping repeated: $answer" if ($debug_on);
	goto START;
    }

    $last_msg = $answer;

    print "\t$entity_name: ";
    sleep(length($message)*0.05+0.5) unless $quick_on;
    typing("$answer");
    $question_counter++;

    if ($timeout)
    {
	if ( (time() - $starting_time) >600 || $question_counter==15)
	{
	    print "\t$entity_name: ";
	    sleep(0.5);
	    typing("Ok, that's all. Thank you for your collaboration. Bye!");
	    $last_to_go = 1;
	}
    }
		

    $now = localtime;
    print LOG "[$now] $entity_name: $answer\n";
}

exit;
