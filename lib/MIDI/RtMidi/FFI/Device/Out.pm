use v5.26;
use warnings;
use Feature::Compat::Class;
use experimental qw/ signatures /;

class MIDI::RtMidi::FFI::Device::Out :isa( MIDI::RtMidi::FFI::AbstractDevice );

# ABSTRACT: OO interface for MIDI::RtMidi::FFI output deviced

use MIDI::Stream::Encoder;
use MIDI::RtMidi::FFI ':all';
use Carp qw/ croak carp /;

field $encoder = MIDI::Stream::Encoder->new;

sub build_device( $class, $api, $name ) {
    my $device = rtmidi_out_create( $api, $name );
    croak "Error creating device" if !$device || !$device->ok;
    $device;
}

=encoding UTF-8

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

See L<MIDI::RtMidi::FFI::Device> for methods common to all device types.

=head2 send_message

    $device->send_message( $msg );

Sends a message - MIDI bytes - on the device's open port.

=cut

method send_message( $msg ) {
    rtmidi_out_send_message( $self->device, $msg );
}

=head2 encode_message

    my $msg = $device->encode_message( note_on => 0x00, 0x40, 0x5a )
    $device->encode_message( @event );

Attempts to encode the passed message with L<MIDI::Stream::Encoder>.

=cut

my $_midi_event_name = method( $event ) {
    $event->[0] = $self->name_from_midi_event( $event->[0] );
    $event;
};

method encode_message( @event ) {
    if ( ref $event[0] eq 'ARRAY' ) {
        return join '', map { $self->encode_message( $_->@* ) } @event;
    }
    $encoder->encode( $self->$_midi_event_name( \@event ) );
}

=head2 send_message_encoded

    $device->send_message_encoded( @event );
    # Event, channel, note, velocity
    $device->send_message_encoded( note_on => 0x00, 0x40, 0x5A );
    $device->send_message_encoded( control_change => 0x01, 0x1F, 0x3F7F );
    $device->send_message_encoded( sysex => "Hello, computer?" );

Sends an event to the open port.

=cut

method send_message_encoded( @event ) {
    $self->send_message( $self->encode_message( @event ) );
}

=head2 send_event

Alias for L</send_message_encoded>, for backwards compatibility.

=cut

*send_event = \&send_message_encoded;

=head2 panic

    $device->panic( $channel );
    $device->panic( 0x00 );

Send an "All MIDI notes off" (CC 123) message to the specified channel.
If no channel is specified, the message is sent to all channels.

=cut

sub panic {
    my ( $self, $channel ) = @_;
    my @channels = defined $channel
        ? ( $channel )
        : ( 0..15 );
    $self->cc( 123, $_, 0 ) for @channels;
}

=head2 PANIC

    $device->PANIC( $channel );
    $device->PANIC( 0x00 );

Send 'note_off' to all 128 notes on the specified channel.
If no channel is specified, the message is sent to all channels.

B<Warning:> This method has the potential to flood buffers!
It should be a recourse of last resort - consider L</panic>,
it'll probably work.

=cut

sub PANIC {
    my ( $self, $channel ) = @_;
    my @channels = defined $channel
        ? ( $channel )
        : ( 0..15 );
    for my $ch ( @channels ) {
        $self->note_off( $ch, $_ ) for 0..127;
    }
}

method get_current_api {
    rtmidi_out_get_current_api( $self->device );
}

=head2 note_off, note_on, control_change, patch_change, key_after_touch, channel_after_touch, pitch_wheel_change, sysex_f0, sysex_f7, sysex, clock, start, stop, continue

Wrapper methods for L</send_message_encoded>, e.g.

    $device->note_on( 0x00, 0x40, 0x5a );

is equivalent to:

    $device->send_message_encoded( note_on => 0x00, 0x40, 0x5a );

=cut

method note_off { $self->send_event( note_off => @_ ) };
method note_on { $self->send_event( note_on => @_ ) };
method control_change { $self->send_event( control_change => @_ ) };
method patch_change { $self->send_event( patch_change => @_ ) };
method key_after_touch { $self->send_event( key_after_touch => @_ ) };
method channel_after_touch { $self->send_event( channel_after_touch => @_ ) };
method pitch_wheel_change { $self->send_event( pitch_wheel_change => @_ ) };
method sysex_f0 { $self->send_event( sysex_f0 => @_ ) };
method sysex_f7 { $self->send_event( sysex_f7 => @_ ) };
method sysex { $self->send_event( sysex => @_ ) };
method clock { $self->send_event( clock => @_ ) };
method start { $self->send_event( start => @_ ) };
method stop { $self->send_event( stop => @_ ) };
method continue { $self->send_event( continue => @_ ) };

=head2 cc

An alias for control_change.

=cut

*cc = \&control_change;

method DESTROY {
    $self->close_port;
    #rtmidi_out_free( $self->device );
}


1;
