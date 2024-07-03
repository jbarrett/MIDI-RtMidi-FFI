package MIDI::RtMidi::FFI::ScorePlayer {
    use strict;
    use warnings;

    # use if $ENV{USER} eq 'gene', lib => map { "$ENV{HOME}/repos/$_/lib" } qw(MIDI-RtMidi-FFI);
    # use if $ENV{USER} eq 'gene', lib => map { "$ENV{HOME}/sandbox/$_/lib" } qw(MIDI-Util);

    use MIDI::RtMidi::FFI::Device ();
    use MIDI::Util qw/ get_microseconds score2events /;
    use Time::HiRes qw/ usleep /;

    sub new {
        my ( $class, %opts ) = @_;
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
            grep { $_->[0] !~ /^note/ }
            @{ $self->{score}->{ Score } }
        ];
        ${ $self->{score}->{ Time } } = 0;
        $self->{common}{seen} = {}
            if exists $self->{common}{seen};
    }

    sub play {
        my ( $self ) = @_;
        while( 1 ) {
            my $score = $self->_score_phrases;
            my $micros = get_microseconds($score);
            my $events = score2events($score);
            for my $event (@{ $events }) {
                next if $event->[0] =~ /set_tempo|time_signature/;
                if ( $event->[0] eq 'text_event' ) {
                    printf "%s\n", $event->[-1];
                    next;
                }
                my $useconds = $micros * $event->[1];
                usleep($useconds) if ( $useconds > 0 && $useconds < 1_000_000 );
                $self->device->send_event( $event->[0] => @{ $event }[ 2 .. $#$event ] );
            }
            sleep(2);
            $self->_reset_score;
        }
    }

    # Build the code-ref MIDI of all phrases to be played
    sub _score_phrases {
        my ( $self ) = @_;
        my @phrases;
        push @phrases, $self->{phrase_cb}->( %{ $self->{common} }, phrase => $_ )
            for 1 .. $self->{phrases};
        $self->{score}->synch( @phrases ); # Play the phrases simultaneously
        return $self->{score};
    }

};

__END__

=head1 NAME

ScorePlayer

=head1 SYNOPSIS

  use MIDI::RtMidi::FFI::ScorePlayer ();
  use MIDI::Util qw(setup_score);

  my $score = setup_score();

  my %common = ( seen => {}, etc => '...', );

  sub phrase_generator {
      # Add notes and rests to the score given a set of
      # common arguments and a phrase number, then
      # generate ALL phrases.
  }

  ScorePlayer->new(
      score     => $score,
      phrases   => $n,
      phrase_cb => \&phrase_generator,
      common    => \%common,
  )->play;

=head1 DESCRIPTION

TBD

=head1 SEE ALSO

TBD

=head1 AUTHOR

JBARRETT

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by John Barrett.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
