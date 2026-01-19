use v5.26;
use warnings;

package MIDI::RtMidi::FFI::Device;

# ABSTRACT: OO interface for MIDI::RtMidi::FFI

=encoding UTF-8

=head1 SYNOPSIS

    use MIDI::RtMidi::FFI::Device;
    
    # Create a new device instance
    my $device = RtMidiOut->new;
    
    # Open a "virtual port" - this is a virtual MIDI device which may be
    # connected to directly from external synths and software.
    # This is unsupported on Windows.
    $device->open_virtual_port( 'foo' );
    
    # An alternative to opening a virtual port is connecting to an available
    # MIDI device on your system, such as a loopback device, or virtual or
    # hardware synth. Your device must be connected to some sort of synth to
    # make noise.
    $device->open_port_by_name( qr/wavetable|loopmidi|timidity|fluid/i );
    
    # Now that a port is open we can start to send MIDI messages, such as
    # this annoying sequence
    while ( 1 ) {
        # Send Middle C (0x3C) to channel 0, strong velocity (0x7A)
        $device->note_on( 0x00, 0x3C, 0x7A );
        
        # Send a random control change value to Channel 0, CC 1
        $device->cc( 0x00, 0x01, int rand( 128 ) );
        
        sleep 1;
        
        # Stop playing Middle C on channel 0
        $device->note_off( 0x00, 0x40 );
        
        sleep 1;
    }

=head1 DESCRIPTION

MIDI::RtMidi::FFI::Device is an OO interface for L<MIDI::RtMidi::FFI> to help
you manage devices, ports and MIDI events.

See L<MIDI::RtMidi::FFI::Device::In> and L<MIDI::RtMidi::FFI::Device::Out> for
documentation on methods specific to input and output devices respectively.

=cut

use MIDI::RtMidi::FFI ':all';
use Time::HiRes qw/ time /;
use Carp qw/ carp confess /;

our $VERSION = '0.00';

my $function_lookup = { reverse %{ $byte_lookup } };

=head1 METHODS

=head2 new

    my $device = MIDI::RtMidi::FFI::Device->new( %options );
    my $midiin = RtMidiIn->new( %options );
    my $midiout = RtMidiOut->new( %options );

Returns a new MIDI::RtMidi::FFI::Device object. RtMidiIn and RtMidiOut are
provided as shorthand to instantiate L<MIDI::RtMidi::FFI::Device::In> and
L<MIDI::RtMidi::FFI::Device::Out> respectively. Valid attributes:

=over 4

=item *

B<type> -
Device type : 'in' or 'out' (defaults to 'out')

This option is invalid if directly instantiating RtMidiIn, RtMidiOut,
L<MIDI::RtMidi::FFI::Device::In>, or L<MIDI::RtMidi::FFI::Device::Out>.

=item *

B<name> -
Device / Client name

=item *

B<api> -
MIDI API to use. This should be a L<RtMidiApi constant|MIDI::RtMidi::FFI/"RtMidiApi">.
By default the device should use the first compiled API available. See search
order notes in
L<Using Simultaneous Multiple APIs|https://caml.music.mcgill.ca/~gary/rtmidi/index.html#multi>
on the RtMidi website.

=item *

B<api_name> -
MIDI API to use by name. One of 'alsa', 'jack', 'core', 'winmm' or 'dummy'.

=back

=cut

sub new {
    my $class = shift;
    my %args = ( @_ == 1 and ref $_[0] eq 'HASH' )
        ? $_[0]->%*
        : @_;
    warn "14 bit modes are no longer supported" if delete $args{ '14bit_mode' };
    delete $args{ type } eq 'in'
        ? RtMidiIn->new( %args )
        : RtMidiOut->new( %args );
}

=head2 ok, msg, data, ptr

    warn $device->msg unless $device->ok;

Getters for RtMidiWrapper device struct members

=head2 open_virtual_port

    $device->open_virtual_port( $name );

Open a virtual device port. A virtual device may be connected to other MIDI
software, just as with a hardware device. The name is an arbitrary name of
your choosing, though it is perhaps safest if you stick to plain ASCII for
this.

This method will not work on Windows. See L</Virtual Devices and Windows>
for details and possible workarounds.


=head2 open_port

    $device->open_port( $port, $name );

Open a (numeric) port on a device, with a name of your choosing.

See L</open_port_by_name> for a potentially more flexible option.

=head2 get_ports_by_name

    $device->get_ports_by_name( $name );
    $device->get_ports_by_name( qr/name/ );
    $device->open_port_by_name( [ $name, $othername, qr/anothername/ ] );

Returns a list of port numbers matching the supplied name criteria.

=cut

sub get_ports_by_name {
    my ( $self, $name ) = @_;
    my @ports;
    if ( ref $name eq 'ARRAY' ) {
        for ( @{ $name } ) {
            push @ports, $self->get_ports_by_name( $_ );
        }
    }
    else {
        push @ports, grep {
            my $pn = $self->get_port_name( $_ );
            ref $name eq 'Regexp'
                ? $pn =~ $name
                : $pn eq $name
        } 0..($self->get_port_count-1);
    }
    @ports;
}

=head2 open_port_by_name

    $device->open_port_by_name( $name );
    $device->open_port_by_name( qr/name/ );
    $device->open_port_by_name( [ $name, $othername, qr/anothername/ ] );

Opens the first port found matching the supplied name criteria.

=cut

sub open_port_by_name {
    my ( $self, $name, $portname ) = @_;
    $portname //= $self->{type} . '-' . time();
    my @ports = $self->get_ports_by_name( $name );
    croak "No available device found matching supplied criteria" unless @ports;
    $self->open_port( $ports[0], $portname );
}

=head2 get_all_port_nums

    $device->get_all_port_nums();

Return a hashref of ports visible to the device, of the form { port number => port name }

=cut

sub get_all_port_nums {
    my ( $self ) = @_;
    +{
        map { $_ => $self->get_port_name( $_ ) }
        0..$self->get_port_count-1
    };
}

=head2 get_all_port_names

    $device->get_all_port_names();

Return a hashref of ports visible to the device, of the form { port name => port number }

=cut

sub get_all_port_names {
    my ( $self ) = @_;
    +{
        reverse %{ $self->get_all_port_nums }
    }
}

=head2 print_ports

    $device->print_ports();
    $device->print_ports( $handle );

Prints the port number and name of all ports visible to the device.

=cut

sub print_ports {
    my ( $self, $handle ) = @_;
    $handle //= *STDOUT;
    my $ports = $self->get_all_port_nums;
    for my $port_num ( sort { $a <=> $b } keys %{ $ports } ) {
        print $handle "$port_num: $ports->{ $port_num }\n";
    }
}

=head2 close_port

    $device->close_port();

Closes the currently open port

=cut

sub close_port {
    my ( $self ) = @_;
    $self->ok(1);

    rtmidi_close_port( $self->{device} );

    return 1 if $self->ok;

    croak "Error closing port: " . $self->msg;
}

=head2 get_port_count

    $device->get_port_count();

Return the number of available MIDI ports to connect to.

=cut

sub get_port_count {
    my ( $self ) = @_;
    rtmidi_get_port_count( $self->{device} );
}

=head2 get_port_name

    $self->get_port_name( $port );

Returns the corresponding device name for the supplied port number.

=cut

sub get_port_name {
    my ( $self, $port_number ) = @_;
    my $name = rtmidi_get_port_name( $self->{device}, $port_number );
    $name =~ s/\0$//;
    return $name;
}

=head2 get_current_api

    $device->get_current_api();

Returns the MIDI API in use for the device.

This is a L<RtMidiApi constant|MIDI::RtMidi::FFI/"RtMidiApi">.

=cut

sub get_current_api {
    my ( $self ) = @_;
    my $api_dispatch = {
        rtmidi_in_get_current_api => \&rtmidi_in_get_current_api,
        rtmidi_out_get_current_api => \&rtmidi_out_get_current_api,
    };
    my $fn = "rtmidi_$self->{type}_get_current_api";
    croak "Unknown device type : $self->{type}" unless $api_dispatch->{ $fn };
    $api_dispatch->{ $fn }->( $self->{device} );
}

=head2 get_timestamp

    $device->get_timestamp;

Returns the time since the first MIDI message was processed

=cut

sub get_timestamp {
    time - shift->{ initial_ts };
}

sub _init_timestamp {
    shift->{ initial_ts } //= time;
}

=head2 set_last_event

    $device->set_last_event( control_change => 2, 6, 127 );

Set the last event explicitly. This event should represent a single 7-bit MIDI
message, not a composite value such as 14 bit CC.

=cut

sub set_last_event {
    my ( $self, @event ) = @_;
    return if @event < 2;
    my $value = pop @event;
    my $event = shift @event;
    my $event_spec = join '-', @event;
    $self->{ last_event }->{ $event }->{ $event_spec } = { val => $value, ts => $self->get_timestamp };
}

=head2 set_last

An alias for set_last_event

=cut

*set_last = \&set_last_event;

=head2 get_last_event

    my $last_event = $device->get_last_event( control_change => $channel, $cc );
    # ... Do something with $last_event->{ val } and $last_event->{ ts }

Returns a hashref containing details on the last event matching the specified
parameters, if it exists.
Hashref keys include the value (val) and timestamp (ts).

=cut

sub get_last_event {
    my ( $self, $event, @spec ) = @_;
    $self->{ last_event }->{ $event }->{ join '-', @spec };
}

=head2 get_last

An alias for get_last_event

=cut

*get_last = \&get_last_event;

=head2 purge_last_events

    $device->purge_last_events( 'control_change' );

Delete all cached events for the event type.

=cut

sub purge_last_events {
    my ( $self, $event ) = @_;
    return unless $event;
    delete $self->{last_event}->{ $event };
}

sub port_name { $_[0]->{port_name}; }

=head2 open_rpn

    $device->open_rpn( $channel, $msb, $lsb );
    $device->open_rpn( 1, 0, 1 );

Open a Registered Parameter Number (RPN) for setting with later control change
messages for CC6. This method will also close any open RPN or NRPN.

=cut

sub open_rpn {
    my ( $self, $channel, $msb, $lsb ) = @_;
    $self->close_rpn( $channel );
    $self->{ open_rpn }->{ $channel } = [ $msb, $lsb ];
    $self->cc( $channel, 101, $msb );
    $self->cc( $channel, 100, $lsb );
}

=head2 open_nrpn

    $device->open_rpn( $channel, $msb, $lsb );
    $device->open_rpn( 1, 0, 1 );

Open a Non-Registered Parameter Number (NRPN) for setting with later control
change messages for CC6. This method will also close any open RPN or NRPN.

=cut

sub open_nrpn {
    my ( $self, $channel, $msb, $lsb ) = @_;
    $self->close_nrpn( $channel );
    $self->{ open_nrpn }->{ $channel } = [ $msb, $lsb ];
    $self->cc( $channel, 99, $msb );
    $self->cc( $channel, 98, $lsb );
}

=head2 close_rpn

    $device->close_rpn( $channel );

Close any open RPN on the given channel.

=cut

sub close_rpn {
    my ( $self, $channel ) = @_;
    delete $self->{ open_rpn }->{ $channel };
    delete $self->{ open_nrpn }->{ $channel };
    $self->cc( $channel, 101, 127 );
    $self->cc( $channel, 100, 127 );
}

=head2 close_nrpn

    $device->close_rpn( $channel );

Close any open NRPN on the given channel.

=cut

*close_nrpn = \&close_rpn;

=head2 get_rpn

    $device->get_nrpn( $channel );

Get the currently open RPN for the given channel.

=cut

sub get_rpn {
    my ( $self, $channel ) = @_;
    $self->{ open_rpn }->{ $channel };
}

=head2 get_nrpn

    $device->get_rpn( $channel );

Get the currently open RPN for the given channel.

=cut

sub get_nrpn {
    my ( $self, $channel ) = @_;
    $self->{ open_nrpn }->{ $channel };
}

=head2 send_rpn

    $device->send_rpn( $channel, $msb, $lsb, $value );

Send a single value for the given RPN. This method is suitable for individual
settings accessed via RPN. It will open the RPN, send the passed value to
CC6 on the passed channel, then close the RPN.

A 14 bit value is expected if rpn_14bit_mode is set.

=cut

sub send_rpn {
    my ( $self, $channel, $msb, $lsb, $value ) = @_;
    $self->open_rpn( $channel, $msb, $lsb );
    $self->cc( $channel, 0x06, $value );
    $self->close_rpn( $channel );
}

=head2 rpn

    $device->rpn( $channel, $msb, $lsb, $value );

An alias for L</send_rpn>.

=cut

*rpn = \&send_rpn;

=head2 send_nrpn

    $device->send_nrpn( $channel, $msb, $lsb, $value );

Send a single value for the given NRPN. This method is suitable for single
setting values accessed via NRPN. It will open the NRPN, send the passed value
to CC6 on the passed channel, then close the NRPN.

A 14 bit value is expected if nrpn_14bit_mode is set.

If sending modulation to a NRPN, calling L</open_nrpn> and sending a stream of
control change messages separately is recommended:

    $device->open_nrpn( $channel, 1, 1 );
    $device->cc( $channel, 6, $value )
    # ...more cc() calls here
    $device->close_nrpn( $channel );

=cut

sub send_nrpn {
    my ( $self, $channel, $msb, $lsb, $value ) = @_;
    $self->open_nrpn( $channel, $msb, $lsb );
    $self->cc( $channel, 0x06, $value );
    $self->close_nrpn( $channel );
}

=head2 nrpn

    $device->nrpn( $channel, $msb, $lsb, $value );

An alias for L</send_nrpn>.

=cut

*nrpn = \&send_nrpn;

=head2 get_rpn_14bit_mode

    $self->get_rpn_14bit_mode;

Get the currently in-use RPN 14 bit mode.

=cut

sub get_rpn_14bit_mode { $_[0]->{ 'rpn_14bit_mode' } }
*get_rpn_14bit_callback = \&get_rpn_14bit_mode;

=head2 get_nrpn_14bit_mode

    $self->get_nrpn_14bit_mode;

Get the currently in-use NRPN 14 bit mode.

=cut

sub get_nrpn_14bit_mode { $_[0]->{ 'nrpn_14bit_mode' } }
*get_nrpn_14bit_callback = \&get_nrpn_14bit_mode;

=head2 set_rpn_14bit_mode

    $device->set_rpn_14bit_mode( 'await' );
    $device->set_rpn_14bit_mode( $callback );
    $device->set_rpn_14bit_mode( $callback, 'no purge' );

Sets the RPN 14 bit mode. See L</14-bit Control Change Modes>, similar to
L</set_14bit_mode>.

=cut

sub set_rpn_14bit_mode {
    my ( $self, $mode, $nopurge ) = @_;
    $self->purge_last_events( 'control_change' ) unless $nopurge;
    $self->{ 'rpn_14bit_mode' } = $mode;
}
*set_rpn_14bit_callback = \&set_rpn_14bit_mode;

=head2 set_nrpn_14bit_mode

    $device->set_nrpn_14bit_mode( 'await' );
    $device->set_nrpn_14bit_mode( $callback );
    $device->set_nrpn_14bit_mode( $callback, 'no purge' );

Sets the NRPN 14 bit mode. See L</14-bit Control Change Modes>, similar to
L</set_14bit_mode>.

=cut

sub set_nrpn_14bit_mode {
    my ( $self, $mode, $nopurge ) = @_;
    $self->purge_last_events( 'control_change' ) unless $nopurge;
    $self->{ 'nrpn_14bit_mode' } = $mode;
}
*set_nrpn_14bit_callback = \&set_nrpn_14bit_mode;

=head2 disable_rpn_14bit_mode

    $device->disable_rpn_14bit_mode;
    $device->disable_rpn_14bit_mode( 'no purge' );

Disables the RPN 14 bit mode. See L</14-bit Control Change Modes>.

=cut

sub disable_rpn_14bit_mode {
    my ( $self, $nopurge ) = @_;
    $self->purge_last_events( 'control_change' ) unless $nopurge;
    delete $self->{ 'rpn_14bit_mode' };
}
*disable_rpn_14bit_callback = \&disable_rpn_14bit_mode;

=head2 disable_nrpn_14bit_mode

    $device->disable_nrpn_14bit_mode;
    $device->disable_nrpn_14bit_mode( 'no purge' );

Disables the NRPN 14 bit mode. See L</14-bit Control Change Modes>.

=cut

sub disable_nrpn_14bit_mode {
    my ( $self, $nopurge ) = @_;
    $self->purge_last_events( 'control_change' ) unless $nopurge;
    delete $self->{ 'nrpn_14bit_mode' };
}
*disable_nrpn_14bit_callback = \&disable_nrpn_14bit_mode;

=head2 note_off, note_on, control_change, patch_change, key_after_touch, channel_after_touch, pitch_wheel_change, sysex_f0, sysex_f7, sysex, clock, start, stop, continue

Wrapper methods for L</send_message_encoded>, e.g.

    $device->note_on( 0x00, 0x40, 0x5a );

is equivalent to:

    $device->send_message_encoded( note_on => 0x00, 0x40, 0x5a );

=cut

sub note_off { shift->send_event( note_off => @_ ) };
sub note_on { shift->send_event( note_on => @_ ) };
sub control_change { shift->send_event( control_change => @_ ) };
sub patch_change { shift->send_event( patch_change => @_ ) };
sub key_after_touch { shift->send_event( key_after_touch => @_ ) };
sub channel_after_touch { shift->send_event( channel_after_touch => @_ ) };
sub pitch_wheel_change { shift->send_event( pitch_wheel_change => @_ ) };
sub sysex_f0 { shift->send_event( sysex_f0 => @_ ) };
sub sysex_f7 { shift->send_event( sysex_f7 => @_ ) };
sub sysex { shift->send_event( sysex => @_ ) };
sub clock { shift->send_event( clock => @_ ) };
sub start { shift->send_event( start => @_ ) };
sub stop { shift->send_event( stop => @_ ) };
sub continue { shift->send_event( continue => @_ ) };

=head2 cc

An alias for control_change.

=cut

*cc = \&control_change;

my $free_dispatch = {
    in  => \&rtmidi_in_free,
    out => \&rtmidi_out_free
};
sub DESTROY {
    my ( $self ) = @_;
    my $fn = $free_dispatch->{ $self->{type} };
    # croak "Unable to free type : $self->{type}" unless $fn;
    # There is an extant issue around the Perl object lifecycle and C++ object lifecycle.
    # If we free the RtMidiPtr here, a double-free error may occur on process exit.
    # https://github.com/jbarrett/MIDI-RtMidi-FFI/issues/8
    #
    # For now, cancel the callback and close the port, then trust the process ...
    $self->cancel_callback;
    $self->close_port;
    MIDI::RtMidi::FFI::_cleanup( $self->{device} );
    # $fn->( $self->{device} );
}

{
    package RtMidiIn;
    use strict; use warnings;
    sub new {
        shift;
        require MIDI::RtMidi::FFI::Device::In;
        MIDI::RtMidi::FFI::Device::In->new( @_ );
    }
}

{
    package RtMidiOut;
    use strict; use warnings;
    sub new {
        shift;
        require MIDI::RtMidi::FFI::Device::Out;
        MIDI::RtMidi::FFI::Device::Out->new( @_ );
    }
}

1;

#__END__

=head1 14 bit Control Change Modes

14 bit Control Change messages are achieved by sending a pair of 7-bit
messages. Only CCs 0-31 can send / receive 14-bit messages. The most
significant byte (or MSB or coarse control) is sent on the desired CC.
The least significant byte (or LSB or fine control) is sent on that
CC + 32. 14 bit allows for a control value between 0 and 16,383.

For example, to I<manually> set CC 6 on channel 0 to the value 1,337 you
would do something like:

    my $value = 1_337;
    my $msb = $value >> 7 & 0x7F;
    my $lsb = $value & 0x7F;
    $sevice->cc( 0, 6, $msb );
    $sevice->cc( 0, 38, $lsb );

If receving 14 bit Control Change, you would need to cache the MSB
value for the geven CC and channel, then combine it later with the
matching LSB, something like:

    $device->set_callback_decoded( sub {
        my ( $ts, $msg, $event ) = @_;
        state $last_msb;

        if ( $event->[0] eq 'control_change' ) {
            my $cc_value;
            my ( $channel, $cc, $value ) = @{ $event }[ 1..3 ];
            if ( $channel < 32 ) {
                # Cache MSB
                $last_msb->[ $channel ]->[ $cc ] = $value;
            }
            elsif ( $channel < 64 ) {
                my $msb = $last_msb->[ $channel ]->[ $cc ];
                $cc_value = $msb << 7 | $value & 0x7F;
            }
            else {
                $cc_value = $value;
            }
            if ( defined $cc_value ) {
                # ... do something with $cc_value here
            }
        }
        # ... process other events here
    } );

Some problems emerge with this approach. The first is MIDI standards -
deficiencies in, and deviation from.

For example, the MIDI 1.0 Detailed Specification states:

I<
"If both the MSB and LSB are sent initially, a subsequent fine adjustment only
requires the sending of the LSB. The MSB does not have to be retransmitted. If
a subsequent major adjustment is necessary the MSB must be transmitted again.
When an MSB is received, the receiver should set its concept of the LSB to
zero."
>

Let's break this down. I<"If 128 steps of resolution is sufficient the second
byte (LSB) of the data requires the sending of the LSB. The MSB does not have
to be retransmitted.">. The decoding callback above I<should> cater for this,
as the cached MSB will persist for multiple LSB transmissions. So far, so OK.

I<"If a subsequent major adjustment is necessary the MSB must be transmitted
again."> - again, this is fine - it fits in with expectations so far.

I<"When an MSB is received, the receiver should set its concept of the LSB
to zero">. This, to me, is ambiguous. Should our CC now be set to
C<( $msb << 7 ) + 0>? Or is it an instruction to forget any existing LSB value and
await the transmission of a fresh one before constructing a CC value?

With the former approach you could imagine a descending control passing a
MSB threshold, then jumping to a value aligned with the floor value of
the new lower MSB,
before jumping back up when the next LSB is received. The latter approach
seems to make more sense to me as it would avoid such jumps.

Some implementations skip transmission of the MSB where it would be zero.
That is for values < 128, no MSB is sent. If the controller starts at zero,
no MSB value would be cached. If the cached MSB happens to be invalid when
small values are sent (that is, the device *never* sends MSB for values
< 128), then we must resort to heuristic detection for crossing of this
MSB threshold (a large jump in LSB).

Some implementations send LSB first, MSB second. If a LSB/MSB pair is sent
each time, this is easily handled. If a pair is sent, then fine control
is sent subsequently via LSB we have a problem. When we cross a MSB threshold,
we need to wait for the new MSB value before we can construct the complete
CC value. This means we need to somehow know when to stop performing fine
control with new LSB values, and await a new MSB value - we are back to
heuristic detection, looking for LSB jumps.

All to say, there are some ambiguities in how this is handled, and there
are endless variations between different devices and implementations.

The second problem is needing to write explicit 14 bit message handling in
each project individually. This module intends to obviate some of this by
providing 14 bit message handling out of the box, with a number of
compatibility options. Currently, these options are mostly derived from
reading manuals and forum posts - testing and feedback appreciated!

=head2 For Output (Sending)

When sending 14 bit CC, multiple messages must potentially be constructed,
then sent individually. A number of options on handling this are built into
this module.

=head3 midi (recommended)

This implements the MIDI 1.0 specification. MSB values are
only sent where they have changed. LSB values are always sent. Messages
are in MSB/LSB order.

=head3 await

Equivalent to 'midi' when sending messages.

=head3 pair

Always sends a complete pair of messages for each controller change,
in MSB/LSB order.

=head3 backwards

Sends a complete pair of messages for each controller change, in
LSB/MSB order.

=head3 backwait

Sends messages in LSB/MSB order. MSB values are only sent when they have
changed.

=head3 doubleback

"Double backwards" mode. Sends a complete pair of messages for each controller
change, in MSB/LSB order, with the MSB value on the B<high> controller number.

=head3 bassack

"Bass-ackwards" mode.  Sends a complete pair of messages for each controller
change, in LSB/MSB order, with the MSB value on the B<high> controller number.

=head3 Callback

You may also provide your own callback to send 14 bit Control Change. This
callback will receive the following parameters:

=over 4

=item *

B<device> - This instance of the device.

=item *

B<channel> - The channel to send the message on, 0-15.

=item *

B<controller> - The receiving controller, 0-31.

=item *

B<value> - A 14 bit CC value, 0-16383.

=back

To take a simple example, imagine we wanted a callback which implemented the
MIDI standard:

    sub callback {
        my ( $device, $channel, $controller, $value ) = @_;
        my $msb = $value >> 7 & 0x7F;
        my $lsb = $value & 0x7F;
        my $last_msb = $device->get_last( control_change => $channel, $controller );
        if ( !defined $last_msb || $last_msb->{ val } != $msb ) {
            $device->send_message_encoded_cb( control_change => $channel, $controller, $msb )
        }
        $device->send_message_encoded_cb( control_change => $channel, $controller | 0x20, $lsb );
    }
    
    my $out = RtMidiOut->new( 14bit_callback => \&callback );
    
    # The sending of this message will be handled by your callback.
    $out->cc( 0x00, 0x06, 0x1337 );

Callbacks should not call the send_message_encoded, send_event, control_change
or cc methods as these may invoke further 14 bit message handling, potentially
causing an
infinite loop. The L</send_message_encoded_cb> method exists for sending
messages within 14 bit CC callbacks.

=head2 For Input (Decoding)

When decoding 14 bit Control Change messages involves coalescing a pair of
7 bit messages which may not appear in a strict order. One value must be
cached and combined with one or more values which arrive later.

The following decode modes are built in:

=head3 midi

This implements the strictest interpretation of the MIDI 1.0 specification.
LSB messages are combined with the last sent MSB. If no MSB has yet been
received, the value will be < 128. When a new MSB is received, LSB is
reset to zero and a new value is returned.

=head3 await (recommended)

This is the same as 'midi' mode, but it always awaits a LSB message before
returning a value.

This is likely the most compatible and reliable mode for decoding.

=head3 pair

Expects a pair of values in MSB/LSB order. This is equivalent to the 'await'
mode, as that can adequately decode messages sent using this approach.

=head3 backwards

Expects a pair of values in LSB/MSB order. New values are only returned on
receipt of the MSB.

=head3 backwait

Expects an initial pair in LSB/MSB order, with additional fine control sent
as additional LSB messages. This uses a heuristic to guess when to wait for
new MSB values.

=head3 doubleback

"Double backwards" mode. Expects messages in MSB/LSB ordered pairs with MSB
on the B<high> controller number. New values are returned on incoming LSB
messages.

=head3 bassack

"Bass-ackwards" mode. Expects messages in LSB/MSB ordered pairs with MSB on
the B<high> controller number. New values are returned on incoming MSB
messages.

=head3 Callback

You may also provide your own callback to send 14 bit Control Change. This
callback will receive the following parameters:

=over 4

=item *

B<device> - This instance of the device.

=item *

B<channel> - The channel the message was sent on, 0-15.

=item *

B<controller> - The receiving controller, 0-63.

=item *

B<value> - A 7 bit CC value, 0-127.

=back

Imagine we have a device which is MIDI 1.0 compatible, but does not send a new
MSB value of zero for values < 128. We need to somehow detect a large swings in
LSB, then assume the MSB has been set to zero. For extra credit, let's only do
this only when the controller has tended towards the low end of the scale.

Wrapping a built-in decoder is possible with the L</resolve_cc_decoder>
method.

    my $callback = sub {
        my ( $device, $channel, $controller, $value ) = @_;
        my $method = $device->resolve_cc_decoder( 'await' );
        
        # Pass MSB through;
        return $device->$method( $channel, $controller, $value ) if $controller < 32;
        
        my $last_msb = $device->get_last( control_change => $channel, $controller - 32 );
        # If we start low, we never get a MSB
        my $last_msb_value = $last_msb->{ val } // 0;
        
        # Pass LSB through if we are not at the low end of the dial
        return $device->$method( $channel, $controller, $value ) if $last_msb_value > 3; # magic number
        
        # Explicitly set a MSB of 0 if there has been a large jump in LSB
        my $last_lsb = $device->get_last( control_change => $channel, $controller );
        my $diff = abs( $last_lsb->{ val } - $value );
        $device->set_last( control_change => $channel, $controller - 32, 0 ) if $diff > 100;
        
        # Finally, process the value
        $device->$method( $channel, $controller, $value );
    };
    
    my $in = RtMidiIn->new( 14bit_callback => $callback );
    $in->set_callback_decoded ( sub {
        my ( $ts, $msg, $event ) = @_;
        # For 14 bit CC, $event will contain a message decoded by your callback
    } );

One issue with the above implementation is that the heuristic magic numbers
are untuned - they would require some real world testing and tuning, and may
even vary depending on play styles or input source. Another issue is that
this scenario is (I think) likely rare and probably does not need specific
handling.

=head1 Some MIDI Terms

There are terms specific to MIDI which are somewhat overloaded by this
interface. I will try to disambiguate them here.

=head2 Device

A MIDI device, virtual or physical, is required to mediate MIDI messages.  That
is, you may not simply connect RtMidi to another piece of software without a
virtual or loopback device in between, e.g. via the L</open_virtual_port>
method. RtMidi may talk to connected physical devices directly, without the use
of a virtual device. The same is true of any software-defined virtual or
loopback devices external to your software, RtMidi may connect directly to
these.

"Virtual device" and "virtual port" are effectively interchangeable
terms when using RtMidi - each
MIDI::RtMidi::FFI::Device may represent a single input or output port,
so any virtual device instantiated has a single virtual port.

See L</Virtual Devices and Windows> for caveats and workarounds for virtual
device support on that platform.

=head2 Port

Every MIDI device has at least one port for Input and/or Output.
In hardware, connections between ports are usually 1:1. Some software
implementations allow for multiple connections to a port.

There is a special Output port usually called "MIDI Thru" or
"MIDI Through" which mirrors every message sent to a given Input port.

=head2 Channel

Each port has 16 channels, numbered 0-15, which are used to route messages
to specifically configured instruments, modules or effects.

Channel must be specified in any message related to performance, such as
"note on" or "control change".

=head2 Messages and Events

A MIDI message is a (usually) short series of bytes sent on a port, instructing
an instrument on how to behave - which notes to play, when, how loudly, with which
timbral variations & expression, and so on. They may also contain configuration
info or some other sort of instruction.

In this module "events" usually refer to incoming message bytes decoded into a
descriptive sequence of values, or a mechanism for turning these descriptive
sequences into message bytes for ouput.

=head2 General MIDI and Soundfonts

General MIDI is a specification which standardises a single set of musical
instruments, accessed via the "patch change" command. Any of 128 instruments
may be assigned to any of 16 channels, with the exception of channel 10
(0x09) which is reserved for percussion.

Soundfonts are banks of sampled instruments which may be loaded by a General
MIDI compatible softsynth. These can be quite large and complex, though they
usually tend to be small and cheesy. If you remember 90s video game
music or web pages playing .mid files, you're on the right track.

Some implementations also support DLS files, which are similar to soundfonts,
though unlike soundfonts the specification is freely available.

=head1 Virtual Devices and Windows

Windows currently (as of June 2024) lacks built-in support for on-the-fly
creation of virtual MIDI devices. While
L<Windows MIDI Services|https://microsoft.github.io/MIDI/>
will offer dynamic virtual loopback, alongside MIDI 2.0 support, it is a
work in progress.

This situation has resulted in some confusion for MIDI users on Windows,
and a number of solutions exist to work around the issue.

=head2 Loopback Devices

Virtual loopback drivers allow for the
creation of external ports which may be connected to by each participant
in the MIDI conversation.

Rather than create a virtual port, you connect your Perl code to a
virtual loopback device, and connect your DAW or synth to the other side
of the loopback device.

The best currently working virtual loopback drivers based on my research are:

L<loopMIDI|https://www.tobias-erichsen.de/software/loopmidi.html> by
Tobias Erichsen

L<Sbvmidi|https://springbeats.com/sbvmidi/> by Springbeats

L<LoopBe|https://www.nerds.de/en/loopbe1.html> by nerds.de

In my own experience loopMIDI is the simplest and most flexible option,
allowing for arbitrary numbers of devices, with arbitrary names.

You should review the licensing terms of any software you choose to
incorporate into your projects to ensure it is appropriate for your use case.
Each of the above is free for personal, non-commercial use.

=head2 General MIDI

A General MIDI synth called "Microsoft GS Wavetable Synth" should be available
for direct connection on Windows. While the sounds are basic, it can act as a
useful device for testing. This should play a middle-C note on the default
piano instrument:

    use MIDI::RtMidi::FFI::Device;
    my $device = RtMidiOut->new;
    $device->open_port_by_name( qr/gs\ wavetable/i );
    $device->note_on( 0x00, 0xc3, 0x7f );
    sleep( 1 );
    $device->note_off( 0x00, 0xc3 );

=head1 General MIDI on Linux

The days of consumer sound cards containing their own wavetable banks are
behind us.  These days, General MIDI is usually supported in software.

A commonly available General MIDI soft-synth is
L<TiMidity++|https://timidity.sourceforge.net/> - a version is likely packaged
for your distro. This package may or
may not install a timidity service (it may be packaged separately as
timidity-daemon). If not, you can quickly make a timidity port available by
running:

    $ timidity -iAD

You may also need to install and configure a soundfont for TiMidity++.

Another option is FluidSynth, which should also be packaged for any given
distro. To run FluidSynth you'll need a SF2 or SF3 soundfont file. See
L<Getting started with fluidsynth|https://github.com/FluidSynth/fluidsynth/wiki/GettingStarted>
and
L<Example Command Lines to start fluidsynth|https://github.com/FluidSynth/fluidsynth/wiki/ExampleCommandLines>.
L<FluidR3_GM.sf2 Professional|https://musical-artifacts.com/artifacts/738>
is a high quality sound font with a complete set of General MIDI instruments.

A typical FluidSynth invocation on Linux might be:

    $ fluidsynth -a pulseaudio -m alsa_seq -g 1.0 your_soundfont.sf2

=head1 General MIDI on MacOS

An Audio Unit named DLSMusicDevice is available for use within GarageBand,
Logic, and other Digital Audio Workstation (DAW) software on MacOS.

If you wish to use banks other than the default QuickTime set, place
them in C<~/Library/Audio/Sounds/Banks/>. You may now create a new track
within GarageBand or Logic with the DLSMusicDevice instrument, and
select your Sound Bank within the settings for this instrument.

The next step is to open a virtual port, which should autoconnect within
your DAW and be ready to send performance info to DLSMusicDevice:

    # Open virtual port with a name of your choosing
    $device->open_virtual_port('My Snazzy Port');
    # Send middle C
    $device->note_on( 0x00, 0xc3, 0x7f );
    sleep( 1 );
    $device->note_off( 0x00, 0xc3 );

The 'MUS 214: MIDI Composition' channel on YouTube has a
L<Video on setting up DLSMusicDevice in Logic|https://youtu.be/YIb-H10yzyI>.

A potential alternative option is FluidSynth. This has more limited support for
DLS banks but should load SF2/3 banks just fine. See L</General MIDI on Linux>
for links to get started using FluidSynth. A typical FluidSynth invocation on
MacOS might be:

    % fluidsynth -a coreaudio -m coremidi your_soundfont.sf2

=head1 KNOWN ISSUES

The callback interface does not currently work on threaded perls. Most, if not
all, perls currently built for Windows are threaded. I have been working around
this with a non-threaded Perl built within the cygwin environment with
perlbrew.

Use of L<MIDI::Event> is a bit of a hack for convenience, exploiting the
similarity of realtime MIDI messages and MIDI song file messages. It may break
in unexpected ways if used for large SysEx messages or other "non-music"
events, though should be fine for encoding and decoding note, pitch, aftertouch
and CC messages.

Test coverage, both automated testing and hands-on testing, is limited. Some
elements of this module (especially around 14 bit CC and (N)RPN) are based on
reading, and probably often misreading, MIDI specifications, device
documentation and forum posts. Issues in the GitHub repo are more than
welcome, even if just to ask questions. You may also find me in #perl-music
on irc.perl.org - look for fuzzix.

This software has been fairly well exercised on Linux and Windows, but not
so much on MacOS / CoreMIDI. I am interested in feedback on successes
and failures on this platform.

NRPN and 14 bit CC have not been tested on real hardware, though they work
well in the "virtual" domain - for controlling software-defined instruments.

L<Currently open MIDI::RtMidi::FFI issues on GitHub|https://github.com/jbarrett/MIDI-RtMidi-FFI/issues>

=head1 SEE ALSO

L<RtMidi|https://caml.music.mcgill.ca/~gary/rtmidi/>

L<Sound on Sound's MIDI Basics series|https://www.soundonsound.com/series/midi-basics>

L<MIDI CC & NRPN database|https://midi.guide/>

L<Phil Rees Music Tech page on NRPN/RPN|http://www.philrees.co.uk/nrpnq.htm>

L<MIDI::RtMidi::FFI>

L<MIDI::Event>

=head1 CONTRIBUTING

L<https://github.com/jbarrett/MIDI-RtMidi-FFI>

All comments and contributions welcome.

=head1 BUGS AND SUPPORT

Please direct all requests to L<https://github.com/jbarrett/MIDI-RtMidi-FFI/issues>

=head1 CONTRIBUTORS

=over 4

=item *

Gene Boggs <gene@cpan.org>

=back

=cut
