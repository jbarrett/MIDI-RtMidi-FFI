#!/usr/bin/env perl
use strict;
use warnings;

use MIDI::RtMidi::FFI::ScorePlayer ();
use MIDI::Util qw(setup_score set_chan_patch);
use Music::Scales qw(get_scale_MIDI);

my $score = setup_score(bpm => 120);

my %common = ( score => $score );

MIDI::RtMidi::FFI::ScorePlayer->new(
  score    => $score,
  phrases  => [ \&treble, \&bass ],
  common   => \%common,
  repeats  => 4,
  sleep    => 0,
  loop     => 4,
  infinite => 0,
)->play;

sub bass {
  my ( %args ) = @_;

  my @pitches = (
    get_scale_MIDI( 'C', 2, 'pentatonic' ),
  );

  my $bass = sub {
    set_chan_patch( $args{score}, 0, 35 );

    for my $n ( 1 .. 4 ) {
      my $pitch = $pitches[ int rand @pitches ];
      $args{score}->n( 'hn', $pitch );
    }
  };

  return $bass;
}

sub treble {
  my ( %args ) = @_;

  my @pitches = (
    get_scale_MIDI( 'C', 4, 'major' ),
    get_scale_MIDI( 'C', 5, 'major' ),
  );

  my $treble = sub {
    set_chan_patch( $args{score}, 1, 0 );

    for my $n ( 1 .. 4 ) {
      my $pitch = $pitches[ int rand @pitches ];
      $args{score}->n( 'qn', $pitch );
    }
  };

  return $treble;
}
