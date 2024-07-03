# MIDI::RtMidi::FFI

Perl bindings for [Gary P. Scavone's RtMidi library](https://www.music.mcgill.ca/~gary/rtmidi/), realtime MIDI input/output across Linux, Macintosh OS X, and Windows.

`MIDI::RtMidi::FFI::Device` is included - this adds an OO interface, plus support for RPN/NRPN, 14-bit CC control change, convenience methods for port management, and decoding / encoding MIDI messages in a friendly, human-readable format.

## Installing

With [cpanminus](https://metacpan.org/pod/App::cpanminus):

```
$ cpanm MIDI::RtMidi::FFI
```

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
$device->open_port_by_name( qr/wavetable|loopmidi|timidity|fluid/i );

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

Complete documentation for the current version may be found on the [MIDI::RtMidi::FFI::Device MetaCPAN page](https://metacpan.org/pod/MIDI::RtMidi::FFI::Device).
There are also a number of [examples](tree/main/examples/).

## Help! I don't hear anything!

RtMidi requires a hardware or software synth to play music. If your system lacks one of these, try [FluidSynth](https://www.fluidsynth.org/) or [TiMidity++](https://timidity.sourceforge.net/).
Specific instructions for your system should be easily found.

- [Getting started with fluidsynth](https://github.com/FluidSynth/fluidsynth/wiki/GettingStarted)
- [Example Command Lines to start fluidsynth](https://github.com/FluidSynth/fluidsynth/wiki/ExampleCommandLines)
- [FluidR3\_GM.sf2 Professional](https://musical-artifacts.com/artifacts/738) - a large, high quality soundfont
- [RLNDGM.SF2](https://musical-artifacts.com/artifacts/724) - a small but complete soundfont

[VirtualMIDISynth](http://coolsoft.altervista.org/en/virtualmidisynth) can be used on Windows if you wish to use soundfonts beyond the default GS Wavetable.

## Bugs, Feedback

[Open an issue](https://github.com/jbarrett/MIDI-RtMidi-FFI/issues)
or [start a discussion](https://github.com/jbarrett/MIDI-RtMidi-FFI/discussions)!

## Copyright, License

This software is copyright (c) 2024 by John Barrett.

This is free software; you can redistribute it and/or modify it under the
[same terms as the Perl 5 programming language system itself](https://dev.perl.org/licenses/).
