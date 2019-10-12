use strict;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::RealBin/lib/";

use MIDI::RtMidi::FFI::TestUtils;
use MIDI::Event;

my ( $in, $out ) = ( newdevice( 'in' ), newdevice() );
isa_ok( $_, 'MIDI::RtMidi::FFI::Device' ) for ( $in, $out );

subtest virtualport => sub {
    plan skip_all => 'Cannot open virtual ports on MS-Windows' if $^O eq 'MSWin32';

    connect_devices( $in, $out );

    my @msgs = ( "\x90\x40\x5A", "\x80\x40\x5A" );
    $out->send_message( $_ ) for ( @msgs );
    my @msgsin = drain_msgs( $in, scalar @msgs );

    is_deeply( msgs2hex( @msgs ), msgs2hex( @msgsin ), 'get message order' );
};

done_testing;
