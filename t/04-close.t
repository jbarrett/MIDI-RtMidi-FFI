use strict;
use warnings;

use Test::More;
use MIDI::RtMidi::FFI::Device;
use Time::HiRes qw/ usleep /;

my $dev = MIDI::RtMidi::FFI::Device->new( api_by_name => 'dummy' );

$dev->open_port( 0, 'dummy port' );

usleep 10_000;

$dev->close_port;

ok(1);

done_testing;
