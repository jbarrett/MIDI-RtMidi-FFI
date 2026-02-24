use strict;
use warnings;
use experimental qw/ signatures /;

use Test2::V0;
use Test::Lib;
use Test2::Require::Module 'Future::IO';
use Test2::Require::Module 'Future::AsyncAwait';
use Time::HiRes qw/ gettimeofday tv_interval /;

use MIDI::RtMidi::FFI::Device;
use MIDI::RtMidi::FFI::TestUtils;

use Future::IO;
use Future::AsyncAwait;
use MIDI::Stream::Decoder;

plan skip_all => "Sanity check failed" unless sanity_check;
plan skip_all => 'Cannot open virtual ports on this platform' if no_virtual;

my ( $in, $out ) = ( RtMidiIn->new, RtMidiOut->new );
connect_devices( $in, $out );
$in->ignore_timing( 0 );

my @tests = (
    [ note_on => 0xf, 0x33, 0x44 ],
    [ control_change => 0xe, 0x22, 0x11 ],
    [ note_off => 0x1, 0x33, 0x00 ],
);

my @msg = $out->encode( \@tests );
my $fh = $in->get_fh;

my $decoder = MIDI::Stream::Decoder->new(
    callback => sub( $event ) {
        is( $event->as_arrayref, shift @tests );
    }
);

plan scalar @tests;

async sub test {
    while( @tests and my $bytes = await Future::IO->read( $fh, $in->bufsize ) ) {
        $decoder->decode( $bytes );
    }
}

$out->send_message( @msg );
Future->wait_any( Future::IO->sleep( 1 ), test() )->get;

