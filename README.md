# SYNOPSIS

```perl
use MIDI::RtMidi::FFI::Device;

my $in = MIDI::RtMidi::FFI::Device->new( type => 'in', name => 'in' );
my $out = MIDI::RtMidi::FFI::Device->new( name => 'out' );

$out->open_virtual_port( 'foo' );
$in->open_port_by_name( qr/foo/i );

$out->send_event(note_on => 50, 64);
my $msg = $in->get_message;
```

Or using a callback:

```perl
use MIDI::RtMidi::FFI::Device;
use Time::HiRes qw/ usleep /;

my $in = MIDI::RtMidi::FFI::Device->new( type => 'in', name => 'in' );
my $out = MIDI::RtMidi::FFI::Device->new( name => 'out' );

$out->open_virtual_port( 'foo' );
$in->open_port_by_name( qr/foo/ );

$in->set_callback(
    sub {
        my ( $timestamp, $msg, $data ) = @_;
        die $data unless $data eq 'some data';
        my $bytes =
            join '',
            map { sprintf "%02x", ord $_ }
            split '', $msg;
        print "Got $bytes at $timestamp\n";
    },
    'some data'
);

$out->send_message( "\x90\x40\x5A" );
usleep 1000; # small (or no) gaps between messages cause odd issues.
$out->send_event(note_off => 0x40, 0x5a);

usleep 10000; # allow callbacks to finish
```
