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
# Version 1.0

# ################################
# ## DEBUG MODE             ######
# ## set lcdnotify to 1     ######
# ## for verbose debug msgs ######
# my $lcdnotify_testing=1;  ######
# if ($lcdnotify_testing)   ######
# {                         ######
	# use Data::Dumper; ######
# }                         ######
# ################################
print "test\n";
use IO::Socket;
use Switch;
use Encode;

# scroller coords for line2, line3 and line4
my $line2coords="1 2";
my $line3coords="1 3 20 3 m 2";
my $line4coords="1 4 20 4 m 2";

# hook for /lcdnotify commands
$addaction = sub {
	my $command = shift;

	# check passed command to see if it is /lcdnotify - and strip /lcdnotify
	if ($command =~ s#^/lcdnotify ##) {
		# Is there anything after the /lcdnotify command?
		if (length($command)) {
			switch ($command) {
				case "disable" 		{$lcdnotify_enabled=0;
										shutdown_lcd();
										print $stdout "lcdnotify disabled.\n";
										return 1;}
				case "enable"  		{$lcdnotify_enabled=1;
										init_lcd();
										print $stdout "lcdnotify enabled.\n";
										return 1;}
				case "dm"			{dm_setting(); return 1;}
				case "dm enable"	{dm_setting("enable"); return 1;}
				case "dm disable"	{dm_setting("disable"); return 1;}
				case "debug"		{
										if ($lcdnotify_testing) {
											print "lcdnotify - debug mode DISABLED.\n";
											$lcdnotify_testing=0;
										} else {
											print "lcdnotify - debug mode ENABLED.\n";
											$lcdnotify_testing=1;
										}
										return 1;
									}
				case "help"			{print_help();
										return 1;}
				else				{print_help();
										return 1;}
			}
		} 
		else
		{
			print_help();
			return 1;
		}
	}
	return 0;
};

sub print_help {
	print $stdout   "lcdnotify extension, by \@shockwaver.\n".
					"   /lcdnotify help         - shows this help.\n".
					"   /lcdnotify disable      - disables lcdnotify and releases the lcd screen.\n".
					"   /lcdnotify enable       - enables lcdnotify and reinitalizes the lcd screen.\n".
					"   /lcdnotify dm           - shows status of dm notifications.\n".
					"   /lcdnotify dm enable    - enabled seperate dm screen on LCD.\n".
					"   /lcdnotify dm disable   - disables seperate dm screen on LCD (default).\n".
					"   /lcdnotify debug        - toggles verbose debug messages.\n";
	return 1;
}

# check the dm setting, or set it to enable/disable
sub dm_setting {
	$dm_command=shift || "status";
	if ($dm_command eq "status") {
		if ($dm_enabled) {
			print $stdout "lcdnotify - Seperate DM LCD screen is enabled.\n";
			return;
		} else {
			print $stdout "lcdnotify - Seperate DM LCD screen is disabled.\n";
			return;
		}
	} elsif ($dm_command eq "enable") {
		$dm_enabled=1;
		# create dm screen - intial priority LOW
		print $lcd_handle "screen_add twitter_dm\n";
		print $lcd_handle "screen_set twitter_dm -name twitter_dm -priority 224\n";
		print $lcd_handle "widget_add twitter_dm name title\n";
		print $lcd_handle "widget_add twitter_dm line2 string\n";
		print $lcd_handle "widget_add twitter_dm line3 scroller\n";
		print $lcd_handle "widget_add twitter_dm line4 scroller\n";
		if ($lcdnotify_testing) {print "dm lcd screen init - priority set low. - dm_enabled: $dm_enabled\n";}
		print $stdout "lcdnotify - DM LCD screen enabled.\n";
	} elsif ($dm_command eq "disable") {
		$dm_enabled=0;
		# delete the dm screen from the LCD
		print $lcd_handle "screen_del twitter_dm\n";
		if ($lcdnotify_testing) {print "dm lcd screen deleted. - dm_enabled: $dm_enabled\n";}
		print $stdout "lcdnotify - DM LCD screen disabled.\n";
	}
}

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

sub shutdown_lcd {
	print $lcd_handle "bye\n";
	if ($lcdnotify_testing) {print "shutting down - bye sent.\n";}
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

	$username=&descape($message_hash->{'user'}->{'screen_name'});
	$tweet=&descape($message_hash->{'text'});
	if ($lcdnotify_testing) {print "username: $username --- tweet:\n$tweet\n";}
	
	# certain characters don't play nice with the regexp below
	# strip out new lines, and the slanty ' character
	
	# Clear the old lines out - this is important if the next tweet is less then 41 characters
	($line1, $line2, $line3)="";
	
	# strip newline characters - causes issues when passing to LCD
	$tweet=~s/\n/ /g;
	
	# break down the tweet in to LCd friendly lines
	# new regex (.{0,20})(.{0,20})\s(.*)
	# $1 is first 20 characters
	# $2 is next 20 characters, but will not break up a word at the end
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
			print "widget_set twitter line2 $line2coords \"$line2\"\n" encode('utf-8' => $line2);
			print "widget_set twitter line3 $line3coords \"$line3\"\n" encode('utf-8' => $line3);
			print "widget_set twitter line4 $line4coords \"$line4\"\n" encode('utf-8' => $line4);
		}
		print $lcd_handle "hello\n";
		print $lcd_handle "widget_set twitter name \"$username\"\n";
		# handle unicode utf-8 characters without warning
		print $lcd_handle "widget_set twitter line2 $line2coords \"$line2\"\n" encode('utf-8' => $line2);
		print $lcd_handle "widget_set twitter line3 $line3coords \"$line3\"\n" encode('utf-8' => $line3);
		print $lcd_handle "widget_set twitter line4 $line4coords \"$line4\"\n" encode('utf-8' => $line4);
	} else {
		die "connection failure at";
	}
}

# This sub is called when TTYtter sends a notification and -notifytype=lcdnotify
sub notifier_lcdnotify {
	# return 1 if(!$ENV{'DISPLAY'});
	
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
			#turn on notifications at start time
			$lcdnotify_enabled=1;
			# $lcdnotify_testing=0;
			# don't pass to handler if initalizing
			return 1;
		}
	}
	
	# is lcdnotify_enabled false? if so, don't send notification.
	if ($lcdnotify_testing) {print "LCDNOTIFY_ENABLED: $lcdnotify_enabled\n";}
	if (!$lcdnotify_enabled) {
		if ($lcdnotify_testing) {print "lcdnotify_enabled: $lcdnotify_enabled - skipping notification.\n";}
		return 1;
	}
	
	if ($lcdnotify_testing) {print $stdout "\npath: $notify_tool_path - $class- \"$username\" \"$tweet\"\n\n";}
	if ($lcdnotify_testing) {print "calling handle_notification\n";}
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
