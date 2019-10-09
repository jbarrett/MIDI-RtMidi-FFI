use strict;
use warnings;
package MIDI::RtMidi::FFI::Device;

use MIDI::RtMidi::FFI ':all';
use MIDI::Event;
use Carp;

sub new {
    my ( $class, @args ) = @_;
    my $self = ( @args == 1 and ref $args[0] eq 'HASH' )
        ? bless( $args[0], $class )
        : bless( { @args }, $class );
    $self->{type} //= 'out';
    croak "Unknown type : $self->{type}" unless $self->{type} eq 'in' || $self->{type} eq 'out';
    $self->_create_device;
    return $self;
}

sub ok   { $_[0]->{device}->ok }
sub msg  { $_[0]->{device}->msg }
sub data { $_[0]->{device}->data }
sub ptr  { $_[0]->{device}->ptr }

sub open_virtual_port {
    my ( $self, $port_name ) = @_;
    rtmidi_open_virtual_port( $self->{device}, $port_name );
}

sub open_port {
    my ( $self, $port_number, $port_name ) = @_;
    rtmidi_open_port( $self->{device}, $port_number, $port_name );
}

sub get_ports_by_name {
    my ( $self, $name ) = @_;
    my @ports = grep {
        my $pn = $self->get_port_name( $_ );
        ref $name eq 'Regexp'
            ? $pn =~ $name
            : $pn eq $name
    } 0..($self->get_port_count-1);
    return @ports;
}

sub open_port_by_name {
    my ( $self, $name, $portname ) = @_;
    $portname //= $self->{type} . '-' . time();
    if ( ref $name eq 'ARRAY' ) {
        for ( @{ $name } ) {
            return if $self->open_port_by_name( $_ );
        }
    }
    else {
        my @ports = $self->get_ports_by_name( $name );
        return 0 unless @ports;
        return !$self->open_port( $ports[0], $portname );
    }
}

sub close_port {
    my ( $self ) = @_;
    rtmidi_close_port( $self->{device} );
}

sub get_port_count {
    my ( $self ) = @_;
    rtmidi_get_port_count( $self->{device} );
}

sub get_port_name {
    my ( $self, $port_number ) = @_;
    rtmidi_get_port_name( $self->{device}, $port_number );
}

sub get_current_api {
    my ( $self ) = @_;
    my $api_dispatch = {
        rtmidi_in_get_current_api => \&rtmidi_in_get_current_api,
        rtmidi_out_get_current_api => \&rtmidi_out_get_current_api,
    };
    my $fn = "rtmidi_$self->{type}_get_current_api";
    croak "Unknown device type : $self->{type}" unless $api_dispatch->{ $fn };
    $api_dispatch->{ $fn }->( $self->{device} );
}

sub set_callback {
    my ( $self, $cb, $data ) = @_;
    croak "Unable to set_callback for device type : $self->{type}" unless $self->{type} eq 'in';
    $self->{callback} = rtmidi_in_set_callback( $self->{device}, $cb, $data );
}

sub cancel_callback {
    my ( $self ) = @_;
    croak "Unable to cancel_callback for device type : $self->{type}" unless $self->{type} eq 'in';
    rtmidi_in_cancel_callback( $self->{device} );
}

sub ignore_types {
    my ( $self, $sysex, $time, $sense ) = @_;
    croak "Unable to ignore_types for device type : $self->{type}" unless $self->{type} eq 'in';
    rtmidi_in_ignore_types( $self->{device}, $sysex, $time, $sense );
}

sub get_message {
    my ( $self ) = @_;
    croak "Unable to get_message for device type : $self->{type}" unless $self->{type} eq 'in';
    rtmidi_in_get_message( $self->{device}, $self->{queue_size_limit} );
}

sub send_message {
    my ( $self, $msg ) = @_;
    croak "Unable to send_message for device type : $self->{type}" unless $self->{type} eq 'out';
    rtmidi_out_send_message( $self->{device}, $msg );
}

sub send_event {
    my ( $self, @event ) = @_;
    my $msg = MIDI::Event::encode( [[@event]], { never_add_eot => 1 } );
    $self->send_message( ${ $msg } );
}

sub _create_device {
    my ( $self ) = @_;
    my $create_dispatch = {
        rtmidi_out_create_default => \&rtmidi_out_create_default,
        rtmidi_out_create => \&rtmidi_out_create,
        rtmidi_in_create_default => \&rtmidi_in_create_default,
        rtmidi_in_create => \&rtmidi_in_create,
    };
    my $fn = "rtmidi_$self->{type}_create";
    $fn = "${fn}_default" if !$self->{api} && !$self->{name} && !$self->{queue_size_limit};
    croak "Unknown type : $self->{type}" unless $create_dispatch->{ $fn };

    $self->{queue_size_limit} //= 1024;
    $self->{device} = $create_dispatch->{ $fn }->( $self->{api}, $self->{name}, $self->{queue_size_limit} );
}

sub DESTROY {
    my ( $self ) = @_;
    my $free_dispatch = {
        rtmidi_in_free => \&rtmidi_in_free,
        rtmidi_out_free => \&rtmidi_out_free
    };
    my $fn = "rtmidi_$self->{type}_free";
    croak "Unable to free type : $self->{type}" unless $free_dispatch->{ $fn };
    $free_dispatch->{ $fn }->( $self->{device} );
}

1;