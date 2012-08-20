# This TTYtter extension implements the lcdnotify notification method.
# When the notification method is initalized by TTYtter, the init_lcd()
#   subrouting is called - creating the LCDd/lcdproc screen for twitter
#   and displaying a test message.
#
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
# Version 1.0

################################
## DEBUG MODE             ######
## set lcdnotify to 1     ######
## for verbose debug msgs ######
my $lcdnotify_testing=0;  ######
if ($lcdnotify_testing)   ######
{                         ######
	use Data::Dumper; ######
}                         ######
################################

# scroller coords for line2, line3 and line4
my $line2coords="1 2";
my $line3coords="1 3 20 3 m 2";
my $line4coords="1 4 20 4 m 2";

use IO::Socket;

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
		# create dm screen - intial priority LOW
		print $lcd_handle "screen_add twitter_dm\n";
		print $lcd_handle "screen_set twitter_dm -name twitter_dm -priority 224\n";
		print $lcd_handle "widget_add twitter_dm name title\n";
		print $lcd_handle "widget_add twitter_dm line2 string\n";
		print $lcd_handle "widget_add twitter_dm line3 scroller\n";
		print $lcd_handle "widget_add twitter_dm line4 scroller\n";
		
		# Set initial messages on twitter screen
		if ($lcdnotify_testing) 
		{
		print "widget_set twitter line2 $line2coords \"lcdnotify.pl loaded.\"\n";
		print "widget_set twitter line3 $line3coords \"********************\"\n";
		print "widget_set twitter line4 $line4coords \"--------------------\"\n";
		}
		print $lcd_handle "widget_set twitter name lcdnotify.pl\n";
		print $lcd_handle "widget_set twitter line2 $line2coords \"lcdnotify.pl loaded.\"\n";
		print $lcd_handle "widget_set twitter line3 $line3coords \"********************\"\n";
		print $lcd_handle "widget_set twitter line4 $line4coords \"--------------------\"\n";
		if ($lcdnotify_testing) {print "LCD Initialized.\n";}
	}
	else
	{ 
		die "Failed to connect to lcdproc server ($!).  Are you sure it's running ?\n"; 
		#socket enema
		$lcd_handle->autoflush(1);
		return 0;
	}
	return 1;
}

# This sub will spit the mssage out to the LCD screen - breaking it down in to 20 character lines
# line2 is string and has characters 1,20
# line3 is scroller and has characters 21,39 (if they exist)
# line4 is scroller and has characters 39+ (if they exist)
sub handle_notification {
	my $class=shift;
	my $message_hash=shift;
	if ($lcdnotify_testing) {print "Inside handle_notification\n";}
	# if ($lcdnotify_testing) {print Dumper($message_hash);}
	# # handle various classes of tweet differently - this is mostly to strip out the garbage.
	# # DEPRECIATED - using the hash is more elegant since all the variables are in there
	# # no need to regexp is out
	# if ($class eq "DM") 
	# {
		 # # direct message - strip out the crap
		# $message =~m/\[.*\]\[(.*)\/.*]\W(.*)/;
		# ($username, $tweet)=($1,$2);
		# if ($lcdnotify_testing) {print "\nDM 1- $1\n2- $2\n\n)";}
	# } 
	# elsif ($class eq "default")
	# {
		# $message =~ /.*\<(.*)\>\W(.*)/;
		# ($username, $tweet)=($1,$2);
		# if ($lcdnotify_testing) {print "default \n1- $1\n2- $2\n\n)";}
	# } else
	# {
		# $tweet=$message;
	# }
	$username=&descape($message_hash->{'user'}->{'screen_name'});
	$tweet=&descape($message_hash->{'text'});
	if ($lcdnotify_testing) {print "username: $username --- tweet:\n$tweet\n";}
	
	# certain characters don't play nice with the regexp below
	# strip out new lines, and the slanty ' character
	
	# Clear the old lines out - this is important if the next tweet is less then 41 characters
	($line1, $line2, $line3)="";
	
	# break down the tweet in to LCd friendly lines
	# new regex (.{0,20})(.{0,20})\s(.*)
	# $1 is first 20 characters
	# $2 is next 20 characters, but will not break up a word
	# $3 is the rest of the string

	$tweet=~m/(.{0,20})(.{0,20})\s(.*)/;
	$line2=$1;
	$line3=$2;
	$line4=$3." -- ";
	# now display the tweet
	if ($lcdnotify_testing) {print "broken down tweet: \nline2: $line2 \nline3: $line3 \nline4: $line4 \n";}
	if ($lcd_handle)
	{ 
		if ($lcdnotify_testing) 
		{
			print "Successfully connected to lcdproc server.\n"; 
			print "hello\n";
			print "widget_set twitter name \"$username\"\n";
			print "widget_set twitter line2 $line2coords \"$line2\"\n";
			print "widget_set twitter line3 $line3coords \"$line3\"\n";
			print "widget_set twitter line4 $line4coords \"$line4\"\n";
		}
		print $lcd_handle "hello\n";
		print $lcd_handle "widget_set twitter name \"$username\"\n";
		print $lcd_handle "widget_set twitter line2 $line2coords \"$line2\"\n";
		print $lcd_handle "widget_set twitter line3 $line3coords \"$line3\"\n";
		print $lcd_handle "widget_set twitter line4 $line4coords \"$line4\"\n";
	} else {
		die "connection failure at";
	}
}

# This sub is called when TTYtter sends a notification and -notifytype=lcdnotify
sub notifier_lcdnotify {
	# return 1 if(!$ENV{'DISPLAY'});
	$lcdnotify_testing=1;
	my $class = shift;
	my $text = shift;
	my $ref = shift;
	if ($lcdnotify_testing==1) {print "\nTEXT: $text\n";}
	chomp($text);
	if (!defined($class) || !defined($notify_tool_path)) {
		# We are being asked to initalize by TTYtter
		if (!defined($class)) {
			if ($lcdnotify_testing) {print "Calling init_lcd()\n"}
			if (!init_lcd()) {
				print "\n******\ninitlcd() failure\n*****\n";
				die "Init_lcd failed at";
			}
			# don't pass to handler if initalizing
			return 1;
		}
	}
	
	if ($lcdnotify_testing) {print $stdout "\npath: $notify_tool_path - $class- \"$username\" \"$tweet\"\n\n";}
	# old method of dumping to log file
	#system("$notify_tool_path","$class","\<$username\>","$tweet");
	if ($lcdnotify_testing) {print "calling handle_notification\n";}
	handle_notification($class,$ref);
	return 1;
}
$shutdown = sub {
	# ttytter is shutting down - kill the open connection
	print $lcd_handle "bye\n";
	if ($lcdnotify_testing) {print "shutting down - bye sent.\n";}
	my $ref = shift;
	
	# Pass the shutdown sequence back to the default handler
	&defaultshutdown($ref);
};

# Return 1
1;
