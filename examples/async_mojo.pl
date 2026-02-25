#!/usr/bin/env perl

use v5.36;

use Mojo::IOLoop;
use MIDI::RtMidi::FFI::Device;
use MIDI::Stream::Decoder;

my $midi_in = RtMidiIn->new();
$midi_in->open_port_by_name( qr/sz|lkmk3/i );
my $fh = $midi_in->get_fh;

my $decoder = MIDI::Stream::Decoder->new;
$decoder->attach_callback( all => sub( $event ) {
    say join ' ', $event->dt, $event->as_arrayref->@*
} );

my $stream = Mojo::IOLoop::Stream->new( $fh );
$stream->timeout( 0 );
$stream->on(
    read => sub ( $stream, $midi_bytes ) {
        $decoder->decode( $midi_bytes );
    }
);
$stream->start;

my $tick = 0;
Mojo::IOLoop->recurring( 1 => sub { say "Tick " . $tick++; } );

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
