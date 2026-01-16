use v5.26;
use warnings;
use Feature::Compat::Class;

class
    MIDI::RtMidi::FFI::AbstractDevice;

use MIDI::RtMidi::FFI ':all';
use Carp qw/ confess carp /;

my $rtmidi_api_names = {
    unspecified => [ "Unknown",            RTMIDI_API_UNSPECIFIED ],
    core        => [ "CoreMidi",           RTMIDI_API_MACOSX_CORE ],
    alsa        => [ "ALSA",               RTMIDI_API_LINUX_ALSA ],
    jack        => [ "Jack",               RTMIDI_API_UNIX_JACK ],
    winmm       => [ "Windows MultiMedia", RTMIDI_API_WINDOWS_MM ],
    dummy       => [ "Dummy",              RTMIDI_API_RTMIDI_DUMMY ],
    web         => [ "Web MIDI API",       RTMIDI_API_WEB_MIDI_API ],
    winuwp      => [ "Windows UWP",        RTMIDI_API_WINDOWS_UWP ],
    amidi       => [ "Android MIDI API",   RTMIDI_API_ANDROID ],
};

my $api_by_name = sub( $api_name ) {
    $rtmidi_api_names->{ $api_name } // [];
}

field $name :param :reader = "RtMidi Client " . __CLASS__;
field $api_name :param = undef;
field $api :param = $api_by_name->( $api_name // 'unspecified' )->[1];

field $device :reader = __CLASS__->build_device( $api, $name );

ADJUST {
    confess __CLASS__ . " may not be instantiated directly"
        if __CLASS__ eq __PACKAGE__;
}

1;
