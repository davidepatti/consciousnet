#!/opt/local/bin/perl -w 

use Chatbot::Eliza;
use WWW::Google::CustomSearch;
use strict; 
use warnings;

my $api_key = 'AIzaSyAOZZHHWpMWo_cNt_iyCsmvLMa_XIEvofU';
my $cx      = '002983251636507551537:jfswnqh-cd8';
my $engine  = WWW::Google::CustomSearch->new(api_key => $api_key, cx => $cx);


my $entity_mail = "pgiogio\@mit.edu";
my $entity_name = "PGioio";
my $debug_on = 0;
my $net_on = 0;

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

    $msg =~ s/(.*)NET(.*)/$2/g;

    if ($debug_on)
    {
	print "\n SEARCHING: ";
	print $msg, "\n"; 
    }
    my $result  = $engine->search($msg);
    my $clean;
    my $n = 0;

    my @responses;

    foreach my $item ($result->items) 
    {
	$clean = &juice($item->snippet);
	push @responses, $clean;
	$n++;

	if ($debug_on)
	{
	    print "\nRAW---> ", $item->snippet, "\n\n" if defined $item->snippet;
	    print "\nCLEAN---> " , $clean, "\n\n";
	}
    }
    my $chosen= int(rand($n));
    $responses[$chosen];
}

###############################################################################
sub typing
{
    my ($msg,$delay) = @_;
    if ($delay)
    {
	sleep($delay);
    }
    print "$entity_name>$msg \n";
}

###############################################################################
sub greetings
{
    print "\n______________________________________________________\n";
    print "   c0n5c10u55n3t   v 02.10.2012 \n";
    print "______________________________________________________\n";
    
    print " > Connecting to system....\n";
    print " > entity: ", $entity_mail, "\n";
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

sub parse_cmdline
{
    for my $arg (@ARGV)
    {
	$debug_on = 1 if $arg eq "debug";
	$net_on = 1 if $arg eq "net";
    }

    print "debug = $debug_on";
    print "net = $net_on";

}


$|++;
&greetings;
&parse_cmdline;

my $bot = new Chatbot::Eliza {
	name       => "Paul", scriptfile => "language.txt",
	debug      => 1, prompts_on => 1, memory_on  => 1,
	myrand     => sub { my $N = defined $_[0] ? $_[0] : 1;  rand($N); },
};

print $bot->{initial}->[0] . "\n";

my $true++;

while ($true) 
{
    print "You> ";
    my $message = <STDIN>;
    $message = $bot->transform($message);

    if ($message=~/NET/)
    {
	$message = &ssnet($message)
    }

    if ($debug_on)
    {
	my $debugging  = $bot->debug_text;
	print $debugging;
	$bot->_debug_memory();
    }
    sleep(1);
    print $entity_name, ">$message\n";
}

exit;
