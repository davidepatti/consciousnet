#!/opt/local/bin/perl -w 

use Chatbot::Eliza;
use WWW::Google::CustomSearch;
use POSIX;

use strict; 
use warnings;

my $api_key = 'AIzaSyAOZZHHWpMWo_cNt_iyCsmvLMa_XIEvofU';
my $cx      = '002983251636507551537:jfswnqh-cd8';
my $engine  = WWW::Google::CustomSearch->new(api_key => $api_key, cx => $cx);


my $entity_mail = "pgiogio\@mit.edu";
my $entity_name = "PGioio";
my $debug_on = 0;
my $net_on = 0;
my $quick_on = 0;

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
    $raw_msg =~ /(.*?)([\.|\?])/i;
    my $msg = "$1$2";
}
###############################################################################
sub ssnet
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
	if (length($clean)>11)
	{
	    push @responses, $clean;
	    $n++;
	}

	if ($debug_on)
	{
	    print "\nDEBUG:RAW--> ", $item->snippet, "\n" if defined $item->snippet;
	    print "\nDEBUG:CLEAN--> " , $clean, "\n";
	}
    }
    my $chosen= int(rand($n));
    $responses[$chosen];
}

###############################################################################
sub typing
{
    my ($msg) = @_;
    sleep(int(length($msg)/10)) unless $quick_on;
    print "$entity_name> $msg \n";
}

###############################################################################
sub greetings
{
    my $now = localtime;

    print "\n______________________________________________________\n";
    print "   c0n5c10u55n3t   v 02.10.2012 \n";
    print "______________________________________________________\n";
    print " Session local time: $now\n";
    
    print " > Connecting to system entity: ", $entity_mail, "\n";
    print " > PLEASE WAIT\n";

    my $x = 10;

    while ($x--)
    {
	print ".";
	sleep(0.1);
    }

    print "\n OK !\n";

    print "\n=====================================================\n";

    typing ("Hi there, I'm doctor Gioio, prof. Patti told me we have about 3-4 minutes....");
    typing ("Tell me something about you (family, work, hobby, ideas, etc...)");
}

sub parse_cmdline
{
    for my $arg (@ARGV)
    {
	$debug_on = 1 if $arg eq "debug";
	$net_on = 1 if $arg eq "net";
	$quick_on = 1 if $arg eq "quick";
    }

}

######################################################################
$|++;
&parse_cmdline;
&greetings;

my $bot = new Chatbot::Eliza {
	name       => "Paul", scriptfile => "language.txt",
	debug      => 1, prompts_on => 1, memory_on  => 1,
	myrand     => sub { my $N = defined $_[0] ? $_[0] : 1;  rand($N); },
};

# typing($bot->{initial}->[0] . "\n");

my $true++;

open(LOG, ">> log.txt");

while ($true) 
{
    select((select(LOG), $|=1)[0]);
    print "You> ";
    my $message = <STDIN>;
    print LOG $message;

    my $answer = $bot->transform($message);

# check for net powered knowledge answers
    if ($answer=~/NET/)
    {
	$answer =~ s/(.*)NET(.*)/$2/g;
	if (&searchable($answer))
	{
	    $answer = &ssnet($answer)
	}
	else
	{
	    print "\n  DEBUG--> skipping not searchable $answer" if ($debug_on);
	    my $tmp_answer;
	    until ( ($tmp_answer = $bot->transform($answer))!~/NET/) 
	    {
		print "\n DEBUG--> skipping NET powered response $tmp_answer" if ($debug_on);
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
    sleep(1) if (!$quick_on);
    typing("$answer\n");
    print LOG "$entity_name> $answer\n";
}

exit;
