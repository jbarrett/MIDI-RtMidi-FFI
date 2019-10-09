Pre-alpha, not working software.

# SYNOPSIS

```perl
use MIDI::RtMidi::FFI::Device;

my $in = MIDI::RtMidi::FFI::Device->new( type => 'in', name => 'in' );
my $out = MIDI::RtMidi::FFI::Device->new( name => 'out' );

$out->open_virtual_port( 'foo' );
$in->open_port_by_name( qr/foo/i );

$out->send_event(note_on => 0, 0, 50, 64);
my $msg = $in->get_message;
```
