#!/usr/bin/env perl

use v5.36;

use IO::Async::Loop;
use IO::Async::Stream;
use IO::Async::Timer::Periodic;
use MIDI::RtMidi::FFI::Device;

my $loop = IO::Async::Loop->new;
my $midi_in = RtMidiIn->new();
$midi_in->open_port_by_name( qr/sz/i );

my $stream = IO::Async::Stream->new(
    read_fileno => $midi_in->get_fd,
    on_read => sub ( $self, $buffref, $eof ) {

        say unpack 'H*', $$buffref;

        $$buffref = "";
        return 0;
    }
);

my $tick = 0;
$loop->add( IO::Async::Timer::Periodic->new(
    interval => 1,
    on_tick => sub { say "Tick " . $tick++; },
)->start );

$loop->add( $stream );
$loop->run;
