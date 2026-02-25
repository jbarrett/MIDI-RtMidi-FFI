use strict;
use warnings;

use Test2::V0;
use Test::Lib;
use Time::HiRes qw/ usleep tv_interval gettimeofday /;

use MIDI::RtMidi::FFI::TestUtils;
use MIDI::RtMidi::FFI::Device;
use experimental qw/ signatures /;

plan skip_all => "Sanity check failed" unless sanity_check;
plan skip_all => 'Cannot open virtual ports on this platform' if no_virtual;

# Do not like ... but if we send multiple messages, send calls clash with
# callback calls, resulting in SEGV or even weirder crashes.
# librtmidi on MacOS and Windows does not *readibly* allow concatenated
# events, so here we are.
plan skip_all => 'Concatenated msg support required' if $^O eq 'darwin' || $^O eq 'MSWin32';

my $out = RtMidiOut->new;

sub events {
    [ note_on  => 0xf, 0x40, 0x7f ],
    [ note_off => 0xf, 0x40, 0x7f ],
    [ control_change => 0xe, 0x6f, 0x3d ],
    [ key_after_touch => 0xb, 0x3e, 0x7f ],
    [ polytouch => 0xc, 0x1b, 0x6f ],
    [ patch_change => 0x1, 0x02 ],
    [ program_change => 0x1, 0x02 ],
    [ pitch_wheel_change => 0x8, 0x1fff ],
    [ pitch_bend => 0x8, -0x0345 ],
    [ channel_after_touch => 0x7, 0x3e ],
    [ aftertouch => 0x7, 0x3e ],
};

my @events = events;
my $msg = join '', $out->encode_message( \@events );

subtest midi_event_callback => sub {
    my $in = RtMidiIn->new( retain_events => 0 );
    my @events = events;
    connect_devices( $in, $out );
    my @tests = map { [ $in->name_to_midi_event( shift @{ $_ } ), @{ $_ } ] } @events;

    $in->set_callback_decoded( sub( $ts, $msg, $event ) {
        is( $event, shift @tests );
    });

    plan scalar @events;

    $out->send_message( $msg );
    usleep( 50_000 );
};

subtest midi_stream_callback => sub {
    my $in = RtMidiIn->new( remap_event_names => 0 );
    my @events = events;
    connect_devices( $in, $out );
    my @tests = map { [ $in->name_from_midi_event( shift @{ $_ } ), @{ $_ } ] } @events;

    $in->set_callback_decoded( sub( $ts, $msg, $event ) {
        is( $event, shift @tests );
    });

    plan scalar @events;

    $out->send_message( $msg );
    usleep( 50_000 );
};

done_testing;
