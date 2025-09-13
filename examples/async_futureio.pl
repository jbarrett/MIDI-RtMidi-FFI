#!/usr/bin/env perl

use v5.36;

use IO::Async::Loop;
use Future::IO;
use Future::IO::Impl::IOAsync;
use Future::AsyncAwait;
use Time::HiRes qw/ time /;
use MIDI::RtMidi::FFI::Device;

my $loop = IO::Async::Loop->new;
my $midi_in = RtMidiIn->new();
$midi_in->open_port_by_name( qr/sz|loop/i );

async sub msg {
    my $fh = $midi_in->get_fh;
    my $size = $midi_in->{ bufsize };
    while ( my $bytes = await Future::IO->read( $fh, $size ) ) {
        say unpack 'H*', $bytes;
    }
}

async sub tick {
    my $tick = 0;
    while ( 1 ) {
        await Future::IO->alarm( time + 1 );
        say "Tick " . $tick++;
    }
}

$loop->await_all( tick msg );
