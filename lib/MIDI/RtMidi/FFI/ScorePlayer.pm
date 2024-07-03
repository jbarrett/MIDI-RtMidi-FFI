package MIDI::RtMidi::FFI::ScorePlayer {

    use strict;
    use warnings;

    use MIDI::RtMidi::FFI::Device ();
    use MIDI::Util qw/ get_microseconds score2events /;
    use Time::HiRes qw/ usleep /;

    sub new {
        my ( $class, %opts ) = @_;

        $opts{repeats}  ||= 1;
        $opts{sleep}    //= 1;
        $opts{loop}     ||= 1;
        $opts{infinite} //= 1;

        $opts{device} = RtMidiOut->new;

        # Linux: Timidity support requires timidity in daemon mode
        # If your distro does not install a service, do: timidity -iAD
        # FluidSynth is an alternative to Timidity++
        $opts{port} //= qr/wavetable|loopmidi|timidity|fluid/i;

        # MacOS: You can get General MIDI via DLSMusicDevice within
        # Logic or Garageband. You will need a soundfont containing
        # drum patches in '~/Library/Audio/Sounds/Banks/'
        # and DLSMusicDevice open in GarageBand / Logic with this
        # sound front selected.
        # DLSMusicDevice should receive input from the virtual port
        # opened below.
        # See MIDI::RtMidi::FFI::Device docs for more info.
        $opts{device}->open_virtual_port( 'foo' ) if $^O eq 'darwin';
        # Alternatively you can use FluidSynth
        $opts{device}->open_port_by_name( $opts{port} );

        bless \%opts, $class;
    }

    sub device { shift->{ device } }

    # This manipulates internals of MIDI::Score objects and
    # hashes used by drum-circle - doing this isn't a good
    # idea - skip to `sub play` to see the interesting piece
    # of this example.
    sub _reset_score {
        my ( $self ) = @_;
        # sorry
        $self->{score}->{ Score } = [
            grep { $_->[0] !~ /^note/ && $_->[0] !~ /^patch/ }
            @{ $self->{score}->{ Score } }
        ];
        ${ $self->{score}->{ Time } } = 0;
        $self->{common}{seen} = {}
            if exists $self->{common}{seen};
    }

    sub play {
        my ( $self ) = @_;
        for ( 1 .. $self->{loop} ) {
            $self->_sync_phrases;
            my $micros = get_microseconds($self->{score});
            my $events = score2events($self->{score});
            for my $event (@{ $events }) {
                next if $event->[0] =~ /set_tempo|time_signature/;
                if ( $event->[0] eq 'text_event' ) {
                    printf "%s\n", $event->[-1];
                    next;
                }
                my $useconds = $micros * $event->[1];
                usleep($useconds) if $useconds > 0 && $useconds < 1_000_000;
                $self->device->send_event( $event->[0] => @{ $event }[ 2 .. $#$event ] );
            }
            sleep( $self->{sleep} );
            $self->_reset_score;
            redo if $self->{infinite}; # Are we an infinite loop?
        }
    }

    # Build the code-ref MIDI of all phrases to be played
    sub _sync_phrases {
        my ( $self ) = @_;
        my @phrases;
        my $n = 1;
        push @phrases, $_->( %{ $self->{common} }, phrase => $n++ ) 
            for @{ $self->{phrases} };
        $self->{score}->synch( @phrases ) # Play the phrases simultaneously
            for 1 .. $self->{repeats};
    }

};

1;

__END__

=head1 NAME

MIDI::RtMidi::FFI::ScorePlayer

=head1 SYNOPSIS

  use MIDI::RtMidi::FFI::ScorePlayer ();
  use MIDI::Util qw(setup_score);

  my $score = setup_score();

  my %common = ( score => $score, seen => {}, etc => '...', );

  sub treble {
      my ( %args ) = @_;
      my $treble = sub {
          ...; # Add notes or rests to the score
      }
      return $treble;
  }
  sub bass {
      ...; # As above
  }

  MIDI::RtMidi::FFI::ScorePlayer->new(
      score    => $score,
      phrases  => [ \&treble, \&bass ], # phrase functions
      common   => \%common, # arguments to give to the phrase functions
      repeats  => 4, # number of repeated synched phrases (default: 1)
      sleep    => 2, # number of seconds to sleep between loops (default: 1)
      loop     => 4, # loop limit if finite (default: 1)
      infinite => 0, # loop infinitely or with the limit (default: 1)
  )->play;

=head1 DESCRIPTION

This module plays a MIDI score in real-time.

=head1 METHODS

=head2 new

Instantiate a new C<MIDI::RtMidi::FFI::ScorePlayer> object.

=head2 play

Play the MIDI score in real-time.

=head1 SEE ALSO

L<MIDI::RtMidi::FFI::Device>

L<MIDI::Util>

L<Time::HiRes>

=head1 CONTRIBUTORS

Gene Boggs <gene.boggs@gmail.com>

=cut
