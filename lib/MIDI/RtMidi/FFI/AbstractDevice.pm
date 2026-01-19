use v5.26;
use warnings;
use Feature::Compat::Class;
use experimental qw/ signatures /;

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
};

field $name :param :reader = "RtMidi Client " . __CLASS__;
field $api_name :param = 'unspecified';
field $api :param = $api_by_name->( $api_name )->[1];
field $port_name :reader;

field $device :reader = __CLASS__->build_device( $api, $name );

ADJUST {
    confess __CLASS__ . " may not be instantiated directly"
        if __CLASS__ eq __PACKAGE__;
}

method ok( $ok = undef ) { $device->ok( defined $ok ? $ok : () ) }
method msg  { $device->msg }
method data { $device->data }
method ptr  { $device->ptr }

method open_virtual_port( $virtual_port_name ) {
    confess "Virtual ports unsupported on this platform"
        if $self->get_current_api == RTMIDI_API_WINDOWS_MM;
    $self->ok(1);

    rtmidi_open_virtual_port( $device, $virtual_port_name );

    if ( $self->ok ) {
        $port_name = $virtual_port_name;
        return 1;
    }

    confess "Error opening virtual port: " . $self->msg;
}

method open_port( $port_number, $open_port_name ) {
    confess "Invalid port number ($port_number)"
        if ( $port_number < 0 || $port_number >= $self->get_port_count );
    $self->ok(1);

    rtmidi_open_port( $device, $port_number, $open_port_name );

    if ( $self->ok ) {
        $port_name = $open_port_name;
        return 1;
    }

    croak("Error opening port: " . $self->msg);
}

1;
