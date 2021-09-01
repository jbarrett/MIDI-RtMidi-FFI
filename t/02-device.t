use strict;
use warnings;

use Test2::V0;
use Time::HiRes qw/ usleep /;

use FindBin;
use lib "$FindBin::RealBin/lib/";
use MIDI::RtMidi::FFI::TestUtils;

my ( $in, $out ) = ( newdevice( 'in' ), newdevice() );
isa_ok( $_, 'MIDI::RtMidi::FFI::Device' ) for ( $in, $out );

subtest event => sub {
    plan skip_all => 'Cannot open virtual ports on MS-Windows' if $^O eq 'MSWin32';

    connect_devices( $in, $out );

    my @msgs = ( "\x90\x40\x5A", "\x80\x40\x5A" );
    $out->send_event(note_on => 0x40, 0x5a);
    usleep( 10_000 );
    $out->send_event(note_off => 0x40, 0x5a);
    my @msgsin = drain_msgs( $in, scalar @msgs );

    is( msgs2hex( @msgs ), msgs2hex( @msgsin ), 'get message order' );
};

done_testing;
