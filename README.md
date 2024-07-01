# MIDI::RtMidi::FFI;

Perl bindings for [Gary P. Scavone's RtMidi library](https://www.music.mcgill.ca/~gary/rtmidi/)
- Real-time MIDI input and output.

## Using

```perl
use MIDI::RtMidi::FFI::Device;

# Create a new device instance
my $device = RtMidiOut->new;

# Open a "virtual port" - this is a virtual MIDI device which may be
# connected to directly from external synths and software.
# This is unsupported on Windows.
$device->open_virtual_port( 'foo' );

# An alternative to opening a virtual port is connecting to an available
# MIDI device on your system, such as a loopback device, or virtual or
# hardware synth. Your device must be connected to some sort of synth to
# make noise.
$device->open_port_by_name( qr/wavetable|loopmidi|timidity|dls/i );

# Now that a port is open we can start to send MIDI messages, such as
# this annoying sequence
while ( 1 ) {
    # Send Middle C (0x3C) to channel 0, strong velocity (0x7A)
    $device->note_on( 0x00, 0x3C, 0x7A );
    
    # Send a random control change value to Channel 0, CC 1
    $device->cc( 0x00, 0x01, int rand( 128 ) );
    
    sleep 1;
    
    # Stop playing Middle C on channel 0
    $device->note_off( 0x00, 0x40 );
    
    sleep 1;
}
```

## Installing

With [cpanminus](https://metacpan.org/pod/App::cpanminus):

```
$ cpanm MIDI::RtMidi::FFI
```

## Bugs, Feedback

[Open an issue](https://github.com/jbarrett/MIDI-RtMidi-FFI/issues)
or [start a discussion](https://github.com/jbarrett/MIDI-RtMidi-FFI/discussions).
