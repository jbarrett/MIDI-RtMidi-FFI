use strict;
use warnings;

use Test2::V0;
use Test::Lib;
use MIDI::RtMidi::FFI::TestUtils;

use MIDI::RtMidi::FFI::Device;
my ( $in, $out ) = ( newdevice( 'in' ), newdevice() );
isa_ok( $_, 'MIDI::RtMidi::FFI::Device' ) for ( $in, $out );

my $msgs = [
    [ note_on             => 0x05, 0x7F, 0x3A ],
    [ note_off            => 0x03, 0x7F, 0x00 ],
    [ key_after_touch     => 0x05, 0x7F, 0x7A ],
    [ control_change      => 0x0B, 0x06, 0x76 ],
    [ patch_change        => 0x03, 0x3A ],
    [ channel_after_touch => 0x0A, 0x7A ],
    [ pitch_wheel_change  => 0x0F, 0x1B13 ],
    [ sysex_f0            => [ 0x48, 0x65, 0x6c, 0x6c, 0x6f ] ],
    [ timecode            => 0x7e ],
    [ 'clock' ],
    [ 'start' ],
    [ 'continue' ],
    [ 'stop' ],
    [ 'active_sensing' ],
    [ 'system_reset' ],
];

sub round_trip {
    my ( $msg ) = @_;
    $in->decode_message( $out->encode_message( @{ $msg } ) );
}

for my $msg ( @{ $msgs } ) {
    is round_trip( $msg ), $msg, "Round-trip decode OK for $msg->[0]";
}

done_testing;
