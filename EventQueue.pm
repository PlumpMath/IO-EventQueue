package IO::EventQueue;

use base Exporter;
our @EXPORT_OK = qw(EV_FD EV_RE EV_WR EV_RM EV_MASK EV_RBYTES EV_WBYTES
	EV_RWBYTES EV_RCLOSED EV_RCONN EV_WCLOSED EV_WCONN EV_OOB EV_FIN
	EV_RESET EV_TIMEOUT EV_DMASK watchevent modwatch waitevent);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

our $VERSION = "0.99_01";

=head1 NAME

IO::EventQueue - Darwin Event Queue - wait for events on multiple sockets 
simultaneously - UNTESTED

=head1 SYNOPSIS

    # THIS MODULE HAS NOT YET BEEN TESTED AT ALL

    use IO::EventQueue ':all';

    watchevent EV_FD, fileno SOCK1, EV_RE;
    watchevent EV_FD, fileno SOCK2, EV_RE | EV_WR | EV_EX;

    my ($type, $fd, $rcnt, $wcnt, $ecnt, $eventbits) = waitevent;
    print "$rcnt bytes available on fd $fd\n"  if $eventbits & EV_RBYTES;

    if (my @ev = waitevent 2.5) { }	# wait at most 2.5 seconds

    modwatch EV_FD, $fd, EV_RE;		# change/reactivate event watch
    modwatch EV_FD, $fd, EV_RM;		# remove event watch

=head1 DESCRIPTION

Provides perl access to the Event Queue on Mac OS X or Darwin, as an 
efficient and scalable replacement for 4-arg select().

Early draft, completely untested.  It could probably use a cleaner interface 
too.. something that doesn't involve manually managing fd numbers :-)

=head1 FUNCTIONS

=over 4

=item watchevent TYPE, REFNUM, EVENTMASK

Add an event watch for given event source.  The only type currently supported 
is EV_FD, with the C<REFNUM> being the file descriptor of a socket.  Returns 
true if successful, otherwise sets $! and returns false.

The event mask consists of one or more of the bits EV_RD, RV_WR, EV_EX or'ed 
together; their meaning is analogous to 4-arg select().

Calling watchevent when an event has already been installed will cause an 
error (EINVAL).

=item modwatch TYPE, REFNUM, EVENTMASK

Change the eventmask of an event watch.  You need this to re-activate an 
event watch after receiving an event using C<waitevent>, which clears the 
event mask.  You can also remove an event watch entirely by passing EV_RM as 
the event mask.

=item waitevent TIMEOUT

=item waitevent

Wait for any watched event to occur, or until the timeout expires.  The timeout 
is in seconds and may be fractional.  If the timeout is undef or omitted, 
waitevent waits forever (or until interrupted by a signal).

If an error or timeout occurs, waitevent returns an empty list and sets $! (to 
0 for timeout).  Otherwise it returns a 6-element list:  (TYPE, REFNUM, RCNT, 
WCNT, ECNT, EVENTMASK).  TYPE and REFNUM identify the event source (TYPE is 
always EV_FD currently).

The returned event mask has one of the bits EV_RD, EV_WR, EV_EX set, and may 
optionally have one or more other event bits set, described below.

The RCNT and WCNT might indicate something like how many bytes can be read / 
written (and perhaps RCNT might indicate how many connections are pending for 
the EV_RD|EV_RCONN event) but I haven't checked.  ECNT is currently unused.

=back

=head1 Event bits

=over 4

=item EV_RBYTES

Data is available for reading data.

=item EV_WBYTES

Buffer space is available for writing data.

=item EV_OOB

Out of band data is available to be read.

=item EV_RCLOSED

Socket has been shutdown for reading.

=item EV_WCLOSED

Socket has been shutdown for writing.

=item EV_RCONN

An incoming connection is available to be accepted.

=item EV_WCONN

An asynchronous connect has successfully completed.

=item EV_FIN

The remote side has closed the connection.  Data may still be available for 
reading, and you may still write data.

=item EV_RESET

The connection has been refused or ungracefully closed.

=item EV_TIMEOUT

An asynchronous operation has timed out.

=back

=head1 KNOWN ISSUES

Once again, this code is completely untested.  As in, I haven't even called 
any of the functions a single time.  I was just in the mood to write it.

It compiles. :-)

=head1 AUTHOR

Matthijs van Duin <xmath@cpan.org>

Copyright (C) 2003  Matthijs van Duin.  All rights reserved.
This program is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

use constant EV_FD => 1;

use constant EV_RE   =>   1;
use constant EV_WR   =>   2;
use constant EV_EX   =>   4;
use constant EV_RM   =>   8;
use constant EV_MASK => 0xf;

use constant EV_RBYTES  => 0x100;
use constant EV_WBYTES  => 0x200;
use constant EV_RWBYTES => (EV_RBYTES|EV_WBYTES);
use constant EV_RCLOSED => 0x400;
use constant EV_RCONN   => 0x800;
use constant EV_WCLOSED => 0x1000;
use constant EV_WCONN   => 0x2000;
use constant EV_OOB     => 0x4000;
use constant EV_FIN     => 0x8000;
use constant EV_RESET   => 0x10000;
use constant EV_TIMEOUT => 0x20000;
use constant EV_DMASK   => 0xffffff00;

use constant SYS_watchevent => 231;
use constant SYS_waitevent => 232;
use constant SYS_modwatch => 233;

sub watchevent {
	my ($type, $handle, $mask) = @_;
	my $evreq = pack "iix4i4", $type, $fd;
	return syscall SYS_watchevent, $evreq, 0+$mask;
}

sub modwatch {
	my ($type, $handle, $mask) = @_;
	my $evreq = pack "iix4i4", $type, $fd;
	return syscall SYS_modwatch, $evreq, 0+$mask;
}

sub waitevent {
	my ($timeout) = @_;
	if (defined $timeout) {
		$timeout = 0  if $timeout < 0;
		$timeout = pack "ll", $timeout, $timeout * 10**6 % 10**6;
	} else {
		$timeout = 0;
	}
	my $evreq = pack "iix4i4";
	my $res = syscall SYS_waitevent, $evreq, $timeout;
	$! = 0  if $res > 0;
	return $res ? () : unpack "iix4i4", $evreq;
	# returned: ($type, $handle, $rcnt, $wcnt, $ecnt, $eventbits)
}

1;
