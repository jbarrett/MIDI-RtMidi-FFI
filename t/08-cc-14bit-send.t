use strict;
use warnings;

use Test2::V0;
use Test::Lib;
use Time::HiRes qw/ usleep time /;

use MIDI::RtMidi::FFI::Device;
my $dev = RtMidiOut->new( api_name => 'dummy' );
$dev->_init_timestamp;

use MIDI::RtMidi::FFI::TestUtils;

plan skip_all => "Sanity check failed" unless sanity_check;
plan skip_all => 'Cannot open virtual ports on this platform' if no_virtual;

my ( $in, $out ) = ( RtMidiIn->new, RtMidiOut->new );
connect_devices( $in, $out );

sub test_cc {
    my $mode = $out->get_14bit_mode // 'disabled';
    my ( $tests ) = @_;
    my $testnum = 0;
    for my $test ( @{ $tests } ) {
        ++$testnum;
        for my $outmsg ( @{ $test->{ out } } ) {
            $out->send_message_encoded( control_change => @{ $outmsg } );
        }
        my $t = time;
        while ( 1 ) {
            if ( time - $t > .5 ) {
                ok 0, "Timed out waiting for message $mode:$testnum";
                last;
            }
            my $inmsg = $in->get_message_decoded;
            if ( $inmsg ) {
                my $intest = shift @{ $test->{ in } };
                is( $inmsg, [ control_change => @{ $intest } ], "$mode:$testnum" );
                last unless @{ $test->{ in } };
            }
            usleep 1000;
        }
    }
}

my $tests = [
    {
        out => [ [ 0x01, 0x06, 0x1337 ] ],
        in  => [ [ 0x01, 0x06, 0x1337 >> 7 ], [ 0x01, 0x06 | 0x20, 0x1337 & 0x7F ] ],
    },
    {   # Can send our own fine adjust to channel > 31
        out => [ [ 0x01, 0x06 | 0x20, 0x39 ] ],
        in  => [ [ 0x01, 0x06 | 0x20, 0x39 ] ],
    },
    {   # No new MSB
        out => [ [ 0x01, 0x06, 0x1333 ] ],
        in  => [ [ 0x01, 0x06 | 0x20, 0x1333 & 0x7F ] ],
    },
    {
        out => [ [ 0x00, 0x00, 0x0000 ] ],
        in  => [ [ 0x00, 0x00, 0x00 ], [ 0x00, 0x00, 0x00 ] ],
    },
    {
        out => [ [ 0x0F, 0x1F, 0x3FFF ] ],
        in  => [ [ 0x0F, 0x1F, 0x3FFF >> 7 ], [ 0x0F, 0x1F | 0x20, 0x3FFF & 0x7F ] ],
    },
    

];

$out->set_14bit_mode( 'await' ); # same as 'midi'
test_cc( $tests );


# Fix this - SIGSEGV if don't explicitly tear down instances
undef $in; undef $out;

done_testing;
