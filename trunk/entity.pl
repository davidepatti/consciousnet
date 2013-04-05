#!/opt/local/bin/perl -w 

use Chatbot::Eliza;
use WWW::Google::CustomSearch;
use strict; 
use warnings;

my $api_key = 'AIzaSyAOZZHHWpMWo_cNt_iyCsmvLMa_XIEvofU';
my $cx      = '002983251636507551537:jfswnqh-cd8';
my $engine  = WWW::Google::CustomSearch->new(api_key => $api_key, cx => $cx);


my $entity = "pgiogio\@mit.edu\n";

sub ssnet
{
    my ($msg) = @_;

    $msg =~ s/(.*)NET(.*)/$1$2/g;

    print "\n SEARCHING: ";
    print $msg; 
    my $result  = $engine->search($msg);

    foreach my $item ($result->items) {
	print "---> ", $item->snippet, "\n" if defined $item->snippet;
    }
}

sub typing
{
    my ($msg,$delay) = @_;
    if ($delay)
    {
	sleep($delay);
    }
    print "PAUL: $msg \n";
}

sub greetings
{
    print "\n______________________________________________________\n";
    print "   c0n5c10u55n3t   v 02.10.2013 \n";
    print "______________________________________________________\n";
    
    print " > Connecting to system....\n";
    print " > entity: ", $entity;
    print " PLEASE WAIT\n";

    my $x = 10;

    while ($x--)
    {
	print ".";
	sleep(0.1);
    }

    print "\n OK !\n";

    print "\n=====================================================\n";
    sleep(0);

    typing ("Hi there, I'm Paul Gioio",1);
    typing ("prof. Patti told me we have about 3-4 minutes....",1);
    typing ("Don't care about argument, let's talk in freedom");
    typing ("Tell me something about you (family, work, hobby, ideas, etc...)");
}


$|++;
&greetings;

my $bot = new Chatbot::Eliza {
	name       => "Paul", scriptfile => "language.txt",
	debug      => 1, prompts_on => 1, memory_on  => 1,
	myrand     => sub { my $N = defined $_[0] ? $_[0] : 1;  rand($N); },
};

print $bot->{initial}->[0] . "\n";

my $true++;

while ($true) 
{
    print "You: ";
    my $message = <STDIN>;

    if ($message=~/NET/)
    {
	$message = &ssnet($message)
    }
    else
    {
	$message = $bot->transform($message);
	my $debugging  = $bot->debug_text;
	print $debugging;
	$bot->_debug_memory();
    }
    sleep(1);
    print "$message\n";
}

exit;
