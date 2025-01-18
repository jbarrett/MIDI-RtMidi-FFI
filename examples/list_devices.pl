#!/usr/bin/env perl

use strict;
use warnings;

use MIDI::RtMidi::FFI::Device;

my $midi_in = RtMidiIn->new;
my $devices_in = $midi_in->get_all_port_names;

my $midi_out = RtMidiIn->new;
my $devices_out = $midi_out->get_all_port_names;

print "Input devices:\n";
print join "\n", keys $devices_in->%*;
print "\n\n";
print "Output devices:\n";
print join "\n", keys $devices_out->%*;
print "\n";
