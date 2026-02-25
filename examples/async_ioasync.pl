#!/usr/bin/env perl

use v5.36;

use IO::Async::Loop;
use IO::Async::Stream;
use IO::Async::Timer::Periodic;
use MIDI::RtMidi::FFI::Device;
use MIDI::Stream::Decoder;

my $midi_in = RtMidiIn->new();
$midi_in->open_port_by_name( qr/sz|lkmk3/i );
my $fh = $midi_in->get_fh;

my $decoder = MIDI::Stream::Decoder->new;
$decoder->attach_callback( all => sub( $event ) {
    say join ' ', $event->dt, $event->as_arrayref->@*;
} );

my $loop = IO::Async::Loop->new;
my $stream = IO::Async::Stream->new(
    read_handle => $fh,
    on_read => sub( $self, $buffref, $eof ) {
        $decoder->decode( $$buffref );
        $$buffref = "";
    }
);
$loop->add( $stream );

my $tick = 0;
$loop->add( IO::Async::Timer::Periodic->new(
    interval => 1,
    on_tick => sub { say "Tick " . $tick++; },
)->start );

$loop->run;
