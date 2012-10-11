# This TTYtter extension implements the lcdnotify notification method.
# When the notification method is initalized by TTYtter, the init_lcd()
#   subrouting is called - creating the LCDd/lcdproc screen for twitter
#   and displaying a test message.
#
# When a notification is sent by TTYtter to notify_lcdnotify(), 
#    we pass the class and the tweet hash (raw tweet date) to handle_notification()
#
# handle_notification takes the class and the hash - this will provide granular control
#	over how classes are handled. Default behaviour is to break the hash in to
#	username, and tweet text - then the subroutine passes the information to the socket
#	that displays the tweet on the LCD screen.
#
# USAGE: start ttytter with -exts=/path/to/lcdnotify.pl and -notifytype=lcdnotify
#		Optional: -notifies=(notification types, eg: me, default, reply, dm)
#
# Created 8/17/2012 - Chris Taylor (@shockwaver)
# Version 1.01

use IO::Socket;
use Switch;

# scroller coords for line2, line3 and line4
my $line2coords="1 2";
my $line3coords="1 3 20 3 m 2";
my $line4coords="1 4 20 4 m 2";

# This will initalize the LCD screen when the script/extension is loaded.
sub init_lcd {
	print "lcdnotify.pl Attempting to connect to lcdproc server... \n";
	if ($lcd_handle = IO::Socket::INET->new(Proto     => "tcp",
										PeerAddr  => "localhost",
										PeerPort  => "13666"))
	{ 
		print "Successfully connected to lcdproc server.\n"; 

		print $lcd_handle "hello\n";
		print $lcd_handle "client_set -name twitter\n";
		print $lcd_handle "screen_add twitter\n";
		print $lcd_handle "screen_set twitter -name twitter\n";
		print $lcd_handle "widget_add twitter name title\n";
		print $lcd_handle "widget_add twitter line2 string\n";
		print $lcd_handle "widget_add twitter line3 scroller\n";
		print $lcd_handle "widget_add twitter line4 scroller\n";

		print $lcd_handle "widget_set twitter name lcdnotify.pl\n";
		print $lcd_handle "widget_set twitter line2 $line2coords \"lcdnotify.pl loaded.\"\n";
		print $lcd_handle "widget_set twitter line3 $line3coords \"********************\"\n";
		print $lcd_handle "widget_set twitter line4 $line4coords \"--------------------\"\n";
		# set mode as utf-8
		binmode($lcd_handle, ":utf8");
	}
	else
	{ 
		die "Failed to connect to lcdproc server ($!).  Are you sure it's running ?\n"; 
		#clean up the socket
		$lcd_handle->autoflush(1);
		return 0;
	}
	return 1;
}

sub shutdown_lcd {
	# kill the socket to the LCD screen
	print $lcd_handle "bye\n";
}

# This sub will spit the mssage out to the LCD screen - breaking it down in to 20 character lines
# line2 is string and has characters 1,20
# line3 is scroller and has characters 21,39 (if they exist)
# line4 is scroller and has characters 39+ (if they exist)
sub handle_notification {
	my $class=shift;
	my $message_hash=shift;

	$username=&descape($message_hash->{'user'}->{'screen_name'});
	$tweet=&descape($message_hash->{'text'});
	if ($lcdnotify_testing) {print "username: $username --- tweet:\n$tweet\n";}
	
	# Clear the old lines out - this is important if the next tweet is less then 41 characters
	($line1, $line2, $line3)="";
	
	print "init tweet: $tweet\n";
	# replace unicode punctuation (open and close quote, apostrophe, etc) with asciii versions
	# as LCD screen does not display those characters.
	# single quotes (left and right):
	$tweet=~s/\x{2018}|\x{2019}/'/g;
	print "first replace: $tweet\n";
	# double quotes (several unicode versions):
	$tweet=~s/\x{201C}|\x{201D}|\x{201f}|\x{301D}\x{301E}|\x{FF02}/"/g;
	print "second replace: $tweet\n";
	
	# strip newline characters - causes issues when passing to LCD
	$tweet=~s/\n/ /g;
	
	#replace double quotes with escaped double quotes
	# $tweet=~s/"/\"/g;
	
	# break down the tweet in to LCd friendly lines
	# new regex (.{0,20})(.{0,20})\s(.*)
	# $1 is first 20 characters
	# $2 is next 20 characters, but will not break up a word at the end
	# $3 is the rest of the string
	$tweet=~m/(.{0,20})(.{0,20})\s(.*)/;
	
	$line2=$1;
	# if we have a match on part two
	if ($2) {$line3=$2;}
	#if the match is on part 3, and part 2
	if ($3 && $2) {$line4=$3." -- ";}
	#if the match is on part 3, and not on part 2
	if ($3 && !$2) {$line3=$3; $line4=" ";}

	# escape double quotes
	$line2=~s/"/\"/g;
	$line3=~s/"/\"/g;
	$line4=~s/"/\"/g;
	
	# now display the tweet
	if ($lcd_handle)
	{ 
		print $lcd_handle "hello\n";
		print $lcd_handle "widget_set twitter name \"$username\"\n";
		# Clear the screen before showing the tweet - this should prevent overlap issues
		print $lcd_handle "widget_set twitter line2 $line2coords \" \"\n";
		print $lcd_handle "widget_set twitter line3 $line3coords \" \"\n";
		print $lcd_handle "widget_set twitter line4 $line4coords \" \"\n";
		# Display the tweet strings
		print $lcd_handle "widget_set twitter line2 $line2coords \"$line2\"\n";
		print $lcd_handle "widget_set twitter line3 $line3coords \"$line3\"\n";
		print $lcd_handle "widget_set twitter line4 $line4coords \"$line4\"\n";
	} else {
		die "connection failure at";
	}
}

# This sub is called when TTYtter sends a notification and -notifytype=lcdnotify
sub notifier_lcdnotify {
	
	my $class = shift;
	my $text = shift;
	my $ref = shift;
	
	chomp($text);
	if (!defined($class) || !defined($notify_tool_path)) {
		# We are being asked to initalize by TTYtter
		if (!defined($class)) {
			if (!init_lcd()) {
				print "\n******\ninitlcd() failure\n*****\n";
				die "Init_lcd failed at";
			}
			# don't pass to handler if initalizing
			return 1;
		}
	}

	# pass the class and tweet reference to the handler function
	handle_notification($class,$ref);
	return 1;
}
$shutdown = sub {
	# ttytter is shutting down - kill the open connection
	shutdown_lcd();
	my $ref = shift;
	
	# Pass the shutdown sequence back to the default handler
	&defaultshutdown($ref);
};

# Return 1
1;
