use strict;
use warnings;

use Test2::V0;
use List::Util qw/ pairs /;

use MIDI::RtMidi::FFI::Device;
my $dev = RtMidiOut->new( api_name => 'dummy' );
$dev->_init_timestamp;

sub do_tests {
    my $tests = shift;
    my $mode = $dev->get_14bit_mode // 'disabled';
    my $num = 0;
    for my ( $test ) ( pairs @{ $tests } ) {
        my @msg  = @{ $test->key };
        my $res  = $test->value;
        my $decoded = $dev->decode_message( scalar $dev->encode_message( @msg ) );
        my $value = ref $res eq 'ARRAY'
            ? $res->[-1]
            : 0;
        is(
            $decoded,
            $res,
            sprintf( "Decoded 0x%X", $value )
        );
    }
}

$dev->set_14bit_mode( 'midi' );
my $tests = [
    [ control_change => 0x01, 0x06, 0x7F ], undef,
    [ control_change => 0x01, 0x06, 0x26 ], [ control_change => 0x01, 0x06, 0x1300 ],
    [ control_change => 0x01, 0x26, 0x37 ], [ control_change => 0x01, 0x06, 0x1337 ],
    [ control_change => 0x01, 0x06, 0x27 ], [ control_change => 0x01, 0x06, 0x1380 ],
    [ control_change => 0x01, 0x26, 0x37 ], [ control_change => 0x01, 0x06, 0x13B7 ],
    [ control_change => 0x01, 0x26, 0x36 ], [ control_change => 0x01, 0x06, 0x13B6 ],
];
do_tests( $tests );

$dev->set_14bit_mode( 'await' );
$tests = [
    [ control_change => 0x02, 0x06, 0x03 ], undef,
    [ control_change => 0x02, 0x06, 0x57 ], undef,
    [ control_change => 0x02, 0x26, 0x2D ], [ control_change => 0x02, 0x06, 0x2BAD ],
    [ control_change => 0x02, 0x06, 0x77 ], undef,
    [ control_change => 0x02, 0x26, 0x2D ], [ control_change => 0x02, 0x06, 0x3BAD ],
    [ control_change => 0x02, 0x26, 0x2E ], [ control_change => 0x02, 0x06, 0x3BAE ],
];
do_tests( $tests );

$dev->set_14bit_mode( 'backwards' );
$tests = [
    [ control_change => 0x02, 0x28, 0x03 ], undef,
    [ control_change => 0x02, 0x28, 0x6F ], undef,
    [ control_change => 0x02, 0x08, 0x7B ], [ control_change => 0x02, 0x08, 0x3DEF ],
];
do_tests( $tests );


done_testing;
