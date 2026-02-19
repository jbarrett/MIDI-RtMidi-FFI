#!/usr/bin/env perl

use v5.36;

use IO::Async::Timer::Periodic;
use IO::Async::Routine;
use IO::Async::Channel;
use IO::Async::Loop;
use Future::AsyncAwait;
use MIDI::RtMidi::FFI::Device;

my $loop = IO::Async::Loop->new;
my $midi_ch = IO::Async::Channel->new;

my $midi_rtn = IO::Async::Routine->new(
    channels_out => [ $midi_ch ],
    code => sub {
        my $midi_in = MIDI::RtMidi::FFI::Device->new( type => 'in' );
        $midi_in->open_port_by_name( qr/LKMK3|oxy/i );

        $midi_in->set_callback_decoded(
            sub( $ts, $msg, $event ) {
                $midi_ch->send( $event );
            }
        );

        sleep;
    }
);
$loop->add( $midi_rtn );

$SIG{TERM} = sub { $midi_rtn->kill('TERM') };

async sub process_midi_events {
    while ( my $event = await $midi_ch->recv ) {
        say join " ", $event->@*;
    }
}

my $tick = 0;
$loop->add( IO::Async::Timer::Periodic->new(
    interval => 1,
    on_tick => sub { say "Tick " . $tick++; },
)->start );

$loop->await( process_midi_events );
