use strict;
use warnings;

use Test2::V0;
use Test::Lib;
use Time::HiRes qw/ usleep /;

use MIDI::RtMidi::FFI::TestUtils;

plan skip_all => "Sanity check failed" unless sanity_check;

my ( $in, $out ) = ( newdevice( 'in' ), newdevice() );
isa_ok( $_, 'MIDI::RtMidi::FFI::Device' ) for ( $in, $out );

subtest event => sub {
    plan skip_all => 'Cannot open virtual ports on this platform' if no_virtual;

    connect_devices( $in, $out );

    $in->ignore_sysex( 0 );
    $out->send_message_encoded( sysex => 'Hello, World!' );
    usleep 200;
    is( $in->get_message_decoded->[1], [ 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2c, 0x20, 0x57, 0x6f, 0x72, 0x6c, 0x64, 0x21 ] );

    $in->ignore_sysex( 1 );
    $out->send_message_encoded( sysex => 'Hello, World!' );
    usleep 200;
    is( $in->get_message_decoded, undef );
};

done_testing;
