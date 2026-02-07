use strict;
use warnings;

# Can I specify test count in Test2::V#?
use Test::More tests => 15;
use Time::HiRes qw/ usleep gettimeofday tv_interval /;

use MIDI::RtMidi::FFI::Device;
use Test::Lib;
use MIDI::RtMidi::FFI::TestUtils;

my $in = RtMidiIn->new( enable_14bit => 1 );
my $out = RtMidiOut->new( enable_14bit => 1 );
connect_devices( $in, $out );

my @tests = (
    [ control_change => 0xf, 0x1a, 0x3fff ],
    [ control_change => 0xf, 0x0f, 0x3210 ],
    [ control_change => 0xd, 0x00, 0x2222 ],
    [ control_change => 0xd, 0x01, 0x1111 ],
    [ control_change => 0xa, 0x1f, 0x1010 ],
    [ control_change => 0xa, 0x07, 0x999 ],
    [ control_change => 0x8, 0x12, 0x666 ],
    [ control_change => 0x3, 0x13, 0x7f ],
    [ control_change => 0x0, 0x1d, 0x00 ],
    # enable_14bit should have no effect on these - MSB/LSB always required
    [ pitch_wheel_change => 0x7, 0x1fff ],
    [ pitch_wheel_change => 0xe, -0x2000 ],
    [ pitch_wheel_change => 0x1, 0x0 ],
    [ song_position => 0x3fff ],
    [ song_position => 0x0666 ],
    [ song_position => 0x0000 ],
);

sub test_name {
    my $name = shift;
    join '-', $name, map { sprintf "0x%x", $_ } @_;
}

$out->send_event( @tests );

my $t = [ gettimeofday ];
while ( @tests ) {
    die "Messages did not arrive in good time"
        if ( tv_interval( $t ) > 1 );
    usleep( 1_000 );
    next unless my $event = $in->get_message_decoded;
    my $test = shift @tests;
    my $name = test_name( @{ $test } );
    is_deeply( $event, $test, $name );
}
