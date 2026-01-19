use v5.26;
use warnings;
use Feature::Compat::Class;

class MIDI::RtMidi::FFI::Device::Out :isa( MIDI::RtMidi::FFI::AbstractDevice );

# ABSTRACT: OO interface for MIDI::RtMidi::FFI output deviced

use MIDI::Stream::Encoder;
use MIDI::RtMidi::FFI ':all';
use Carp qw/ confess carp /;

field $encoder = MIDI::Stream::Encoder->new;

=encoding UTF-8

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 send_message

    $device->send_message( $msg );

Sends a message - MIDI bytes - on the device's open port.

=cut

method  send_message( $msg ) {
    rtmidi_out_send_message( $self->device, $msg );
}

=head2 encode_message

    my $msg = $device->encode_message( note_on => 0x00, 0x40, 0x5a )
    $device->encode_message( @event );

Attempts to encode the passed message with L<MIDI::Stream::Encoder>.

=cut

method encode_message( @event ) {
    $encoder->encode( @event );
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


1;
