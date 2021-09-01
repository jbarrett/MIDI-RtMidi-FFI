use strict;
use warnings;

use Test2::V0;
use Time::HiRes qw/ usleep /;

use FindBin;
use lib "$FindBin::RealBin/lib/";

use MIDI::RtMidi::FFI::TestUtils;

my ( $in, $out ) = ( newdevice( 'in' ), newdevice() );
isa_ok( $_, 'MIDI::RtMidi::FFI::Device' ) for ( $in, $out );

my @events = (
    [ note_on => 0x40, 0x7f ],
    [ note_off => 0x40, 0 ],
    [ pitch_wheel_change => 0x1f40 ],
    [ control_change => 0x01, 0x5f ],
    [ key_after_touch => 0x40, 0x5f ],
);

subtest event => sub {
    plan skip_all => 'Cannot open virtual ports on MS-Windows' if $^O eq 'MSWin32';

    connect_devices( $in, $out );

    for my $event ( @events ) {
        $out->send_event( @{ $event } );
        usleep 1000;
        my $inevent = $in->get_event;
        is( $event, $inevent, 'Event round-trip ok for ' . $event->[0] );
    }
};

done_testing;

