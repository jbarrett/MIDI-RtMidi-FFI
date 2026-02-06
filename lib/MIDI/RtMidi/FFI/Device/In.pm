use v5.26;
use warnings;
use Feature::Compat::Class;
use experimental qw/ signatures /;

class MIDI::RtMidi::FFI::Device::In :isa( MIDI::RtMidi::FFI::AbstractDevice );

# ABSTRACT: OO interface for MIDI::RtMidi::FFI input devices

use MIDI::Stream::Decoder;
use MIDI::RtMidi::FFI ':all';
use Carp qw/ croak carp /;

field $ignore_sysex   :param = 1;
field $ignore_timing  :param = 1;
field $ignore_sensing :param = 1;

field $decoder :param = MIDI::Stream::Decoder->new;

field $callback;

sub build_device( $class, $api, $name ) {
    my $device = rtmidi_in_create( $api, $name, MIDI::RtMidi::FFI::BUFFER_SIZE );
    croak "Error creating device" if !$device || !$device->ok;
    $device;
}

ADJUST {
    $self->ignore_types( $ignore_sysex, $ignore_timing, $ignore_sensing );
}

=encoding UTF-8

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

See L<MIDI::RtMidi::FFI::Device> for methods common to all device types.

=head2 new

Construct new instance.

    my $midiin = MIDI::RtMidi::FFI::Device::In->new( %options );

=over 4

=item *

B<ignore_sysex> -
Ignore incoming SysEx messages (defaults to true)

=item *

B<ignore_timing> -
Ignore incoming timing messages (defaults to true)

=item *

B<ignore_sensing> -
Ignore incoming active sensing messages (defaults to true)

=item *

B<decoder> -
An optional MIDI Event decoder with the same interface as L<MIDI::Stream::Decoder> -
useful for passing your own decoder configurations.

=back

=cut

=head2 set_callback

    $device->set_callback( sub( $dt, $msg ) {
        # handle $msg here
    } );

Sets a callback to be executed when an incoming MIDI message is
received. Your callback receives the time which has elapsed since the previous
event in seconds, alongside the MIDI message.

B<NB> As a callback may occur at any point in your program's flow, the program
should probably not be doing much when it occurs. That is, programs handling
RtMidi callbacks should be asleep the callback is triggered. See L</get_fh>
for integrating rtmidi into evnet loops.

See the examples included with this dist for some ideas on how to incorporate
callbacks into your program.

=cut

method set_callback( $cb ) {
    $self->cancel_callback;
    $callback = rtmidi_in_set_callback( $self->device, $cb );
}

=head2 set_callback_decoded

    $device->set_callback_decoded( sub( $dt, $msg, $event ) {
        # handle $msg / $event here
    } );

Same as L</set_callback>, though also attempts to decode the message, and pass
that to the callback as an array ref. The original
message is also sent in case this fails.

=cut

method set_callback_decoded( $cb ) {
    $decoder->cancel_callbacks( 'all' );
    $decoder->attach_callback->(
        all => sub( $dt, $event ) {
            $cb->( $dt, $event->as_arrayref );
            $decoder->continue;
        }
    );
    $self->set_callback( sub( $dt, $msg ) { $self->decode_message( $msg ) } );
}

=head2 cancel_callback

    $device->cancel_callback();

Removes the callback from your device.

=cut

method cancel_callback {
    return unless $callback;
    undef $callback;
    rtmidi_in_cancel_callback( $self->device );
}

=head2

    my $fh = $device->get_fh;
    # ...then add a notifier to your event loop

This uses the rtmidi callback mechanism to write MIDI bytes to a pipe as
the arrive. This method returns the other end of the pipe as a nonblocking
L<IO::Handle> instance. This can then be added 

B<NB> This receives raw MIDI bytes, not decoded events with timestamps.
This cannot be used in conjunction with L</set_callback> or 
L</set_callback_decoded>.

=cut

method get_fh {
    $self->cancel_callback;
    $callback = callback_fh( $self->device );
}

=head2 ignore_types

    $device->ignore_types( $ignore_sysex, $ignore_timing, $ignore_sensing );
    $device->ignore_types( (1)x3 );

Type 'in' only. Set message types to ignore.

=cut

method ignore_types( $sysex, $timing, $sensing ) {
    ( $ignore_sysex, $ignore_timing, $ignore_sensing ) = ( $sysex, $timing, $sensing );
    rtmidi_in_ignore_types( $self->device, $sysex, $timing, $sensing );
}

=head2 ignore_sysex

    $device->ignore_sysex( 1 );
    $device->ignore_sysex( 0 );

Type 'in' only. Set whether or not to ignore sysex messages.

=cut

method ignore_sysex( $new_ignore_sysex ) {
    $self->ignore_types( $new_ignore_sysex, $ignore_timing, $ignore_sensing );
}

=head2 ignore_timing

    $device->ignore_timing( 1 );
    $device->ignore_timing( 0 );

Type 'in' only. Set whether or not to ignore clock/timing messages.

=cut

method ignore_timing( $new_ignore_timing ) {
    $self->ignore_types( $ignore_sysex, $new_ignore_timing, $ignore_sensing );
}

=head2 ignore_sensing

    $device->ignore_sensing( 1 );
    $device->ignore_sensing( 0 );

Type 'in' only. Set whether or not to ignore active sensing messages.

=cut

method ignore_sensing( $new_ignore_sensing ) {
    $self->ignore_types( $ignore_sysex, $ignore_timing, $new_ignore_sensing );
}

=head2 get_message

    $device->get_message();

Type 'in' only. Gets the next message from the queue, if available.

=cut

method get_message {
    rtmidi_in_get_message( $self->device );
}

=head2 get_message_decoded

    $device->get_message_decoded();

Type 'in' only. Gets the next message from the queue, if available, decoded
as an event. See L</decode_message> for what to expect from incoming events.

=cut

method get_message_decoded {
    $self->decode_message( $self->get_message );
}

=head2 get_event

Alias for L</get_message_decoded>, for backwards compatibility.

=cut

*get_event = \&get_message_decoded;

=head2 decode_message

    my @events = $device->decode_message( $msg );

Decodes the passed MIDI byte string with L<MIDI::Stream::Decoder>.

=cut

my $_midi_event_name = method( $event ) {
    $event->[0] = $self->name_to_midi_event( $event->[0] );
    $event;
};

method decode_message( $msg ) {
    return unless $decoder->decode( $msg );
    $self->$_midi_event_name( $decoder->fetch_one_event->as_arrayref );
}

method get_current_api {
    rtmidi_in_get_current_api( $self->device );
}

method DESTROY {
    $self->close_port;
    $self->cancel_callback;
    MIDI::RtMidi::FFI::_cleanup( $self->device );
    # rtmidi_in_free( $self->device );
}

1;
