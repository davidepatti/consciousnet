#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use Config;
use lib "$FindBin::Bin/local";
use lib "$FindBin::Bin/local/lib/perl5";
use lib "$FindBin::Bin/local/lib/perl5/$Config{archname}";

BEGIN {
    my $local_eliza = "$FindBin::Bin/local/Chatbot/Eliza.pm";
    my $repo_eliza = "$FindBin::Bin/Eliza.pm";

    if (-e $local_eliza) {
	require $local_eliza;
    }
    elsif (-e $repo_eliza) {
	require $repo_eliza;
    }
    else {
	require Chatbot::Eliza;
    }
}

use File::Spec;
use Getopt::Long qw(GetOptionsFromArray);
use HTTP::Request;
use JSON::PP qw(decode_json);
use LWP::UserAgent;
use POSIX;
use Time::HiRes qw(sleep);
use URI::Escape qw(uri_escape_utf8);

binmode STDIN, ":encoding(UTF-8)";
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

# Defaults for command line.
my $base_dir = $FindBin::Bin;
my $entity_mail = "gioio\@work";
my $entity_name = "PaulGioio";
my $metaresponse = File::Spec->catfile($base_dir, "annette.meta");
my $metaresponse_log_name = "annette.meta";
my $debug_on = 0;
my $no_net = 0;
my $quick_on = 0;
my $filter_on = 1;
my $timeout = 0;
my $rnnexp = File::Spec->catfile($base_dir, "annettexp_1.12.t7");
my $version = "0.10";
my $config_path = $ENV{CONSCIOUSNET_CONFIG} || File::Spec->catfile($base_dir, "consciousnet.conf");

my $bot;
my $config;
my $config_loaded = 0;

open my $fh, "<", File::Spec->catfile($base_dir, "badwords.txt") or die $!;

sub preprocess
{
    my ($user_input) = @_;
    my $ret = ucfirst($user_input || "");

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
# - when delimited by '.', should be a single '.'
# - including multiple sentences separated by period, but not starting with ...
# - non-greedy, min length 20
# - not containing ...

# TODO: better way than adding extra char
    $raw_msg = $raw_msg.'  ';

    if ($raw_msg =~ /([.]{3}[^.]+\.)?(([^.]\.[^.]|[^.]){20,}?[.?!])[^.]/si)
    {
	if (defined($2))
	{
	    $ret = $2;
	    $ret =~ s/\.$//si; # remove last .
	    $ret =~ s/\n//si;  # remove newlines
	    $ret =~ s/^\s+//;  # remove spaces at beginning

# Typical bad results.
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
	print "\n\t--> Sanity check FAILED: short length " if $debug_on;
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
sub load_config
###############################################################################
{
    return $config if $config_loaded;

    my %defaults = (
	brave_endpoint    => "https://api.search.brave.com/res/v1/web/search",
	brave_country     => "us",
	brave_search_lang => "en",
	brave_ui_lang     => "en-US",
	brave_safesearch  => "moderate",
	brave_spellcheck  => 1,
	page_size         => 5,
	http_timeout      => 10,
    );

    $config_loaded = 1;

    if (!-e $config_path)
    {
	print "\nDEBUG: config file not found at $config_path" if $debug_on;
	$config = \%defaults;
	return $config;
    }

    open my $cfg_fh, "<", $config_path or die "Cannot open $config_path: $!";
    while (my $line = <$cfg_fh>)
    {
	$line =~ s/\r?\n$//;
	$line =~ s/^\s+|\s+$//g;
	next if $line eq "" || $line =~ /^#/;

	my ($key, $value) = split(/\s*=\s*/, $line, 2);
	next if !defined($key) || !defined($value);

	$key =~ s/^\s+|\s+$//g;
	$value =~ s/^\s+|\s+$//g;
	$value =~ s/^['"]|['"]$//g;

	$defaults{$key} = $value;
    }
    close $cfg_fh;

    $config = \%defaults;
    return $config;
}

###############################################################################
sub config_value_set
###############################################################################
{
    my ($value) = @_;
    return defined($value) && $value ne "" && $value !~ /^YOUR_/;
}

###############################################################################
sub search_user_agent
###############################################################################
{
    my ($cfg) = @_;
    my $ua = LWP::UserAgent->new(
	agent   => "consciousnet/$version",
	timeout => $cfg->{http_timeout} || 10,
    );
    my %ssl_opts = (verify_hostname => 1);

    if (!$ENV{PERL_LWP_SSL_CA_FILE})
    {
	my $loaded_mozilla_ca = eval {
	    require Mozilla::CA;
	    Mozilla::CA->import();
	    1;
	};

	if ($loaded_mozilla_ca)
	{
	    $ssl_opts{SSL_ca_file} = Mozilla::CA::SSL_ca_file();
	}
	else
	{
	    print "\nDEBUG: Mozilla::CA is not installed; HTTPS may fail unless PERL_LWP_SSL_CA_FILE is set" if $debug_on;
	}
    }

    $ua->ssl_opts(%ssl_opts);
    $ua->env_proxy;
    return $ua;
}

###############################################################################
sub clean_search_text
###############################################################################
{
    my ($text) = @_;
    return "" if !defined($text);

    $text =~ s/<[^>]+>/ /g;
    $text =~ s/&quot;/"/g;
    $text =~ s/&#39;/'/g;
    $text =~ s/&apos;/'/g;
    $text =~ s/&amp;/&/g;
    $text =~ s/&lt;/</g;
    $text =~ s/&gt;/>/g;
    $text =~ s/\s+/ /g;
    $text =~ s/^\s+|\s+$//g;

    return $text;
}

###############################################################################
sub choose_search_response
###############################################################################
{
    my (@raw_responses) = @_;
    my @responses;

    for my $raw (@raw_responses)
    {
	my $snippet = clean_search_text($raw);
	next if $snippet eq "";

	my $clean = &snippet_juice($snippet);
	$clean = ucfirst($snippet) if $clean eq "NOT_MATCH";

	if ($debug_on)
	{
	    print "\n";
	    print "\nDEBUG: **************************************************************";
	    print "\nDEBUG: NET RAW: $snippet";
	    print "\nDEBUG: NET CLEAN: $clean";
	    print "\nDEBUG: --------------------------------------------------------------";
	}

	push @responses, $clean if &sanity_check($clean);
    }

    return undef if !@responses;
    return $responses[int(rand(scalar(@responses)))];
}

###############################################################################
sub brave_search
###############################################################################
{
    my ($msg, $cfg) = @_;

    my $api_key = $cfg->{brave_api_key} || $ENV{BRAVE_SEARCH_API_KEY};
    if (!config_value_set($api_key))
    {
	print "\nDEBUG: missing Brave Search key: set brave_api_key in consciousnet.conf or BRAVE_SEARCH_API_KEY" if $debug_on;
	return undef;
    }

    my $count = 0 + ($cfg->{page_size} || 5);
    my $url = ($cfg->{brave_endpoint} || "https://api.search.brave.com/res/v1/web/search")
	. "?q=" . uri_escape_utf8($msg)
	. "&count=" . uri_escape_utf8($count);

    $url .= "&country=" . uri_escape_utf8($cfg->{brave_country}) if config_value_set($cfg->{brave_country});
    $url .= "&search_lang=" . uri_escape_utf8($cfg->{brave_search_lang}) if config_value_set($cfg->{brave_search_lang});
    $url .= "&ui_lang=" . uri_escape_utf8($cfg->{brave_ui_lang}) if config_value_set($cfg->{brave_ui_lang});
    $url .= "&safesearch=" . uri_escape_utf8($cfg->{brave_safesearch}) if config_value_set($cfg->{brave_safesearch});
    $url .= "&spellcheck=" . uri_escape_utf8($cfg->{brave_spellcheck}) if config_value_set($cfg->{brave_spellcheck});

    print "\nDEBUG: Brave Search query: $msg\n" if $debug_on;

    my $request = HTTP::Request->new(GET => $url);
    $request->header("Accept" => "application/json");
    $request->header("X-Subscription-Token" => $api_key);

    my $response = search_user_agent($cfg)->request($request);

    if (!$response->is_success)
    {
	print "\nDEBUG: Brave Search request failed: " . $response->status_line . " " . $response->decoded_content if $debug_on;
	return undef;
    }

    my $payload = eval { decode_json($response->decoded_content) };
    if (!$payload)
    {
	print "\nDEBUG: Brave Search JSON parse failed: $@" if $debug_on;
	return undef;
    }

    my @snippets;
    my $results = ref($payload->{web}->{results}) eq "ARRAY" ? $payload->{web}->{results} : [];

    for my $result (@$results)
    {
	next if ref($result) ne "HASH";
	push @snippets, $result->{description} if defined $result->{description};
	push @snippets, $result->{title} if defined $result->{title};

	my $extra_snippets = ref($result->{extra_snippets}) eq "ARRAY" ? $result->{extra_snippets} : [];
	push @snippets, grep { defined $_ } @$extra_snippets;
    }

    return choose_search_response(@snippets);
}

###############################################################################
sub net_inject
###############################################################################
{
    my ($msg) = @_;
    my $cfg = load_config();

    return undef if $no_net;
    return brave_search($msg, $cfg);
}

###############################################################################
sub local_transform
###############################################################################
{
    my ($message) = @_;
    my $tmp_answer;

    for (1..30)
    {
	$tmp_answer = $bot->transform($message);
	return ucfirst($tmp_answer) if $tmp_answer !~ /NET/;
	print "DEBUG: skipping NET response $tmp_answer" if $debug_on;
    }

    return "Tell me more about that";
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

# Pause when typing particular last chars in the snippet.
	    if ($snippet =~ /[^.]\.(\s)?$/)
	    {
		sleep(1);
	    }

# As above, but not always.
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
    system("clear") if -t STDOUT;

    print "______________________________________________________\n";
    print "   Consciousnet System v.$version\n";
    print "______________________________________________________\n";
    sleep(0.5);
    print "\n--> Starting session time: $now\n";
    sleep(0.5);
    print "--> Contacting system entity:  $entity_name\n";

    $bot = new Chatbot::Eliza {
	    scriptfile => $metaresponse,
	    debug      => $debug_on, prompts_on => 1, memory_on  => 1,
	    myrand     => sub { my $N = defined $_[0] ? $_[0] : 1;  rand($N); },
    };
    if ( !($bot->name eq $entity_name) )
    {
	print "Cannot contact entity, please run ./setup.sh so the repository Eliza.pm is installed locally.\n";
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
    my @legacy_args;

    GetOptionsFromArray(
	\@ARGV,
	"debug"   => \$debug_on,
	"no-net"  => \$no_net,
	"no_net"  => \$no_net,
	"quick"   => \$quick_on,
	"filter"  => \$filter_on,
	"timeout" => \$timeout,
	"config=s" => \$config_path,
    ) or die "Invalid command line option\n";

    for my $arg (@ARGV)
    {
	push @legacy_args, $arg;
	$debug_on = 1 if $arg eq "debug";
	$no_net = 1 if $arg eq "no_net";
	$quick_on = 1 if $arg eq "quick";
	$filter_on = 1 if $arg eq "filter";
	$timeout = 1 if $arg eq "timeout";
	$config_path = $1 if $arg =~ /^--?config=(.+)$/;
    }

    @ARGV = @legacy_args;
}

######################################################################
# main source code
######################################################################
$|++;
&parse_cmdline;
&greetings;

my $true = 1;
my $now = localtime;
my $starting_time = time();
my $log_dir = File::Spec->catdir($base_dir, "logs");

$now =~ s/\s/_/g;

if (!-d $log_dir) {
    mkdir $log_dir or die "Cannot create $log_dir: $!";
}
open(LOG, ">>", File::Spec->catfile($log_dir, "log_$now.$metaresponse_log_name.txt")) or die $!;
binmode LOG, ":encoding(UTF-8)";

my $last_msg = "";
my $question_counter = 0;
my $last_to_go = 0;

while ($true)
{
    print "\tYou: ";
    my $message = <STDIN>;
    last if !defined $message;
    $message = &preprocess($message);

    $now = localtime;
    select((select(LOG), $|=1)[0]);
    print LOG "[$now] You: $message";

# If timeout enabled.
    exit if ($last_to_go);

# Quit message.
    if ($message=~/(.*)see you later/si)
    {
	print "\t$entity_name: ";
	sleep(0.5);
	typing("ok, bye bye");
	exit;
    }

START:
    my $reasmb = $bot->transform($message);
    my $answer = ucfirst($reasmb);  # Already done if is not a NET response.

# Check for NET metaresponse.
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
	    $answer = local_transform($message);
	}
    }

# Check for Recurrent experience.
    if ($reasmb=~/REXP/)
    {
	print "\nDEBUG: selected REXP meta-response: $reasmb" if ($debug_on);

	$message =~ s/(.*)REXP (.*)/$2/g;
	$message =~ s/\n//si;

	my $thcmd = "th sample.lua $rnnexp -temperature 0.5 -primetext \"\@\@\@: $message ___\" ";
	print "\n$thcmd\n";
	print "\n REXP responses currently unsupported, quitting\n";
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
