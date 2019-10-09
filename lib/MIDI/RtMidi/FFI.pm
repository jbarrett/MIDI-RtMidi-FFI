use strict;
use warnings;
package MIDI::RtMidi::FFI;
use base qw/ Exporter /;

{
package RtMidiWrapper;
use FFI::Platypus::Record;

record_layout(
    opaque => 'ptr',
    opaque => 'data',
    bool   => 'ok',
    string => 'msg'
);
}

use FFI::Platypus;
use FFI::CheckLib;
use FFI::Platypus::Buffer qw/ scalar_to_buffer buffer_to_scalar /;
use FFI::Platypus::Memory qw/ malloc free /;

my $ffi = FFI::Platypus->new;
$ffi->lib( find_lib_or_die( lib => 'rtmidi' ) );
# rtmidi_api_name, rtmidi_api_display_name not found?
$ffi->ignore_not_found(1);

$ffi->type("record(RtMidiWrapper)" => 'RtMidiPtr');
$ffi->type("record(RtMidiWrapper)" => 'RtMidiInPtr');
$ffi->type("record(RtMidiWrapper)" => 'RtMidiOutPtr');

# enum RtMidiApi
use constant RTMIDI_API_UNSPECIFIED  => 0;
use constant RTMIDI_API_MACOSX_CORE  => 1;
use constant RTMIDI_API_LINUX_ALSA   => 2;
use constant RTMIDI_API_UNIX_JACK    => 3;
use constant RTMIDI_API_WINDOWS_MM   => 4;
use constant RTMIDI_API_RTMIDI_DUMMY => 5;
use constant RTMIDI_API_NUM          => 6;
$ffi->type(enum => 'RtMidiApi');

# enum RtMidiErrorType
use constant RTMIDI_ERROR_WARNING           => 0;
use constant RTMIDI_ERROR_DEBUG_WARNING     => 1;
use constant RTMIDI_ERROR_UNSPECIFIED       => 2;
use constant RTMIDI_ERROR_NO_DEVICES_FOUND  => 3;
use constant RTMIDI_ERROR_INVALID_DEVICE    => 4;
use constant RTMIDI_ERROR_MEMORY_ERROR      => 5;
use constant RTMIDI_ERROR_INVALID_PARAMETER => 6;
use constant RTMIDI_ERROR_INVALID_USE       => 7;
use constant RTMIDI_ERROR_DRIVER_ERROR      => 8;
use constant RTMIDI_ERROR_SYSTEM_ERROR      => 9;
use constant RTMIDI_ERROR_THREAD_ERROR      => 10;
$ffi->type(enum => 'RtMidiErrorType');

$ffi->attach( rtmidi_get_compiled_api => ['enum*', 'unsigned int'] => 'int' );
$ffi->attach( rtmidi_api_display_name => ['int'] => 'string' );
$ffi->attach( rtmidi_api_name => ['int'] => 'string' );
$ffi->attach( rtmidi_compiled_api_by_name => ['string'] => 'int' );
$ffi->attach( rtmidi_open_port => ['RtMidiPtr', 'int', 'string'] => 'void' );
$ffi->attach( rtmidi_open_virtual_port => ['RtMidiPtr', 'string'] => 'void' );
$ffi->attach( rtmidi_close_port => ['int'] => 'void' );
$ffi->attach( rtmidi_get_port_count => ['RtMidiPtr'] => 'int' );
$ffi->attach( rtmidi_get_port_name => ['RtMidiPtr', 'int'] => 'string' );
$ffi->attach( rtmidi_in_create_default => ['void'] => 'RtMidiInPtr' );
$ffi->attach( rtmidi_in_create => ['int', 'string', 'unsigned int'] => 'RtMidiInPtr' );
$ffi->attach( rtmidi_in_free => ['RtMidiInPtr'] => 'void' );
$ffi->attach( rtmidi_in_get_current_api => ['RtMidiInPtr'] => 'int' );
$ffi->attach( rtmidi_in_cancel_callback => ['RtMidiInPtr'] => 'void' );
$ffi->attach( rtmidi_in_ignore_types => ['RtMidiInPtr','bool','bool','bool'] => 'void' );
$ffi->attach( rtmidi_out_create_default => ['void'] => 'RtMidiOutPtr' );
$ffi->attach( rtmidi_out_create => ['int', 'string'] => 'RtMidiOutPtr' );
$ffi->attach( rtmidi_out_free => ['RtMidiOutPtr'] => 'void' );
$ffi->attach( rtmidi_out_get_current_api => ['RtMidiOutPtr'] => 'int' );
$ffi->attach(
    rtmidi_in_get_message =>
    ['RtMidiInPtr','opaque','size_t*'] =>
    'double',
    sub {
        my ( $sub, $dev, $size ) = @_;
        $size //= 1024;
        my $str = malloc $size;
        $sub->( $dev, $str, \$size );
        my $msg = buffer_to_scalar( $str, $size );
        free $str;
        return $msg;
    }
);
$ffi->attach(
    rtmidi_out_send_message =>
    ['RtMidiOutPtr','opaque','int']
    => 'int',
    sub {
        my ( $sub, $dev, $str ) = @_;
        my ( $buffer, $bufsize ) = scalar_to_buffer $str;
        $sub->( $dev, $buffer, $bufsize );
    }
);

$ffi->type('(double,opaque,size_t,string)->void' => 'RtMidiCCallback');
$ffi->attach( rtmidi_in_set_callback => ['RtMidiInPtr','RtMidiCCallback','string'] => 'void', sub {
    my ( $sub, $dev, $cb, $data ) = @_;
    my $callback = sub {
        my ( $timestamp, $inmsg, $size, $data ) = @_;
        my $msg = buffer_to_scalar $inmsg, $size;
        $cb->( $timestamp, $msg, $data );
    };
    my $closure = $ffi->closure($callback);
    $sub->( $dev, $closure, $data );
    return $closure;
} );

our @EXPORT_OK = (qw/
    RTMIDI_API_UNSPECIFIED
    RTMIDI_API_MACOSX_CORE
    RTMIDI_API_LINUX_ALSA
    RTMIDI_API_UNIX_JACK
    RTMIDI_API_WINDOWS_MM
    RTMIDI_API_RTMIDI_DUMMY
    RTMIDI_API_NUM
    RTMIDI_ERROR_WARNING
    RTMIDI_ERROR_DEBUG_WARNING
    RTMIDI_ERROR_UNSPECIFIED
    RTMIDI_ERROR_NO_DEVICES_FOUND
    RTMIDI_ERROR_INVALID_DEVICE
    RTMIDI_ERROR_MEMORY_ERROR
    RTMIDI_ERROR_INVALID_PARAMETER
    RTMIDI_ERROR_INVALID_USE
    RTMIDI_ERROR_DRIVER_ERROR
    RTMIDI_ERROR_SYSTEM_ERROR
    RTMIDI_ERROR_THREAD_ERROR
    rtmidi_get_compiled_api
    rtmidi_api_display_name
    rtmidi_api_name
    rtmidi_compiled_api_by_name
    rtmidi_open_port
    rtmidi_open_virtual_port
    rtmidi_close_port
    rtmidi_get_port_count
    rtmidi_get_port_name
    rtmidi_in_create_default
    rtmidi_in_create
    rtmidi_in_free
    rtmidi_in_get_current_api
    rtmidi_in_cancel_callback
    rtmidi_in_ignore_types
    rtmidi_in_get_message
    rtmidi_out_create_default
    rtmidi_out_create
    rtmidi_out_free
    rtmidi_out_get_current_api
    rtmidi_out_send_message
    rtmidi_in_set_callback
    rtmidi_out_send_message_buf
    rtmidi_in_get_message_buf
/);

our %EXPORT_TAGS = ( all => \@EXPORT_OK );
