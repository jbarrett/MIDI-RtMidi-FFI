use strict;
use warnings;

use Test2::V0;
use Test::Lib;
use Time::HiRes qw/ usleep time /;

use MIDI::RtMidi::FFI::Device;
my $dev = RtMidiOut->new( api_name => 'dummy' );
$dev->_init_timestamp;

use MIDI::RtMidi::FFI::TestUtils;

ok 1;

done_testing;
