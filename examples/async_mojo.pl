#!/usr/bin/env perl

use v5.36;

use Mojo::IOLoop;
use MIDI::RtMidi::FFI::Device;

my $midi_in = RtMidiIn->new();
$midi_in->open_port_by_name( qr/sz|loop/i );

my $fh = $midi_in->get_fh;
my $stream = Mojo::IOLoop::Stream->new( $fh );
$stream->on(
    read => sub ( $stream, $bytes ) {
        say unpack 'H*', $bytes;
    }
);
$stream->start;

my $tick = 0;
Mojo::IOLoop->recurring( 1 => sub { say "Tick " . $tick++; } );

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
