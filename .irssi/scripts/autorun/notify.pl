#!/usr/bin/perl -w

##
## Put me in ~/.irssi/scripts, and then execute the following in irssi:
##
##       /load perl
##       /script load notify
##

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.01";
%IRSSI = (
    authors     => 'Luke Macken, Paul W. Frields',
    contact     => 'lewk@csh.rit.edu, stickster@gmail.com',
    name        => 'notify.pl',
    description => 'Use libnotify to alert user to hilighted messages',
    license     => 'GNU General Public License',
    url         => 'http://lewk.org/log/code/irssi-notify',
);
Irssi::settings_add_str('notify', 'notify_icon', 'gtk-dialog-info');
Irssi::settings_add_str('notify', 'notify_time', '5000');

sub hide_message {
    my @hideserver = ("bitlbee");
    my @hidechannel = ();
    my @hidesender = ();

    my ($server, $channel, $sender) = @_;

    if((grep /$server/, @hideserver) or (grep /$channel/, @hidechannel) or (grep /$sender/, @hidesender)){
        return 1;
    } else {
        return 0;
    }
}

sub sanitize {
  my ($text) = @_;
  $text =~ s/</&lt;/g;
  $text =~ s/>/&gt;/g;
  $text =~ s/'/&apos;/g;
  return $text;
}

sub notify {
    my ($server, $summary, $message) = @_;

    # Make the message entity-safe
    $summary = sanitize($summary);
    $message = sanitize($message);

    my $cmd = "EXEC - notify-send" .
        " --hint=int:transient:1" .
	" -i " . Irssi::settings_get_str('notify_icon') .
	" -t " . Irssi::settings_get_str('notify_time') .
	" -- '" . $summary . "'" .
	" '" . $message . "'";

    $server->command($cmd);
}
 
sub print_text_notify {
    my ($dest, $text, $stripped) = @_;
    my $server = $dest->{server};
    return if (!$server || !($dest->{level} & MSGLEVEL_HILIGHT));
    
    my $sender = $stripped;
    $sender =~ s/[^\[]*\[([^\]]*).*/\1/;
    my $summary = $dest->{target} . "：" . $sender;
    $stripped =~ s/^\[.[^\]]+\].// ;
    
    if(!hide_message($server->{tag}, $server->{target}, $sender)){
        notify($server, $summary, $stripped);
    }

}

sub message_private_notify {
    my ($server, $msg, $sender, $address) = @_;
    return if (!$server);
    
    if(!hide_message($server->{tag}, $server->{target}, $sender)){
        notify($server, "来自 ".$sender." 的私人消息", $msg);
    }
}

sub dcc_request_notify {
    my ($dcc, $sendaddr) = @_;
    my $server = $dcc->{server};

    return if (!$dcc);
    notify($server, "DCC 请求：".$dcc->{type}, $dcc->{nick});
}

Irssi::signal_add('print text', 'print_text_notify');
Irssi::signal_add('message private', 'message_private_notify');
Irssi::signal_add('dcc request', 'dcc_request_notify');
