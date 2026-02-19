use strict;
use warnings;

use Test2::V0;
use Test::Lib;
use Time::HiRes qw/ usleep gettimeofday tv_interval /;

use MIDI::RtMidi::FFI::Device;
use MIDI::RtMidi::FFI::TestUtils;

plan skip_all => "Sanity check failed" unless sanity_check;
plan skip_all => 'Cannot open virtual ports on this platform' if no_virtual;

my ( $in, $out ) = ( RtMidiIn->new, RtMidiOut->new );
connect_devices( $in, $out );

my @tests = (
    {
        name => "All 14 bit RPN",
        rpn => [ 0x0f, 0x0101, 0x1fff ],
        cc  => [ [ 0x0f, 0x65, 0x01 ],
                 [ 0x0f, 0x64, 0x02 ],
                 [ 0x0f, 0x06, 0x7f ],
                 [ 0x0f, 0x26, 0x3f ],
                 [ 0x0f, 0x65, 0x7f ],
                 [ 0x0f, 0x64, 0x7f ] ],
    },
    {
        name => "Separate RPN MSB/LSB",
        rpn => [ 0x0f, [ 0x01, 0x02 ], 0x1fff ],
        cc  => [ [ 0x0f, 0x65, 0x01 ],
                 [ 0x0f, 0x64, 0x02 ],
                 [ 0x0f, 0x06, 0x7f ],
                 [ 0x0f, 0x26, 0x3f ],
                 [ 0x0f, 0x65, 0x7f ],
                 [ 0x0f, 0x64, 0x7f ] ],
    },
    {
        name => "Separate RPN value MSB/LSB",
        rpn => [ 0x0f, [ 0x01, 0x02 ], [ 0x7f, 0x3f ] ],
        cc  => [ [ 0x0f, 0x65, 0x01 ],
                 [ 0x0f, 0x64, 0x02 ],
                 [ 0x0f, 0x06, 0x7f ],
                 [ 0x0f, 0x26, 0x3f ],
                 [ 0x0f, 0x65, 0x7f ],
                 [ 0x0f, 0x64, 0x7f ] ],
    },
    {
        name => "RPN value MSB only",
        rpn => [ 0x0f, [ 0x01, 0x02 ], [ 0x7f ] ],
        cc  => [ [ 0x0f, 0x65, 0x01 ],
                 [ 0x0f, 0x64, 0x02 ],
                 [ 0x0f, 0x06, 0x7f ],
                 [ 0x0f, 0x65, 0x7f ],
                 [ 0x0f, 0x64, 0x7f ] ],
    },
    {
        name => "RPN MSB only, LSB is filled with 0x00",
        rpn => [ 0x0f, [ 0x01 ], [ 0x7f ] ],
        cc  => [ [ 0x0f, 0x65, 0x01 ],
                 [ 0x0f, 0x64, 0x00 ],
                 [ 0x0f, 0x06, 0x7f ],
                 [ 0x0f, 0x65, 0x7f ],
                 [ 0x0f, 0x64, 0x7f ] ],
    },

    # Same again, but "nerpins":
    # https://www.philrees.co.uk/nrpnq.htm
    {
        name => "All 14 bit NRPN",
        nrpn => [ 0x0f, 0x0101, 0x1fff ],
        cc   => [ [ 0x0f, 0x63, 0x01 ],
                  [ 0x0f, 0x62, 0x02 ],
                  [ 0x0f, 0x06, 0x7f ],
                  [ 0x0f, 0x26, 0x3f ],
                  [ 0x0f, 0x65, 0x7f ],
                  [ 0x0f, 0x64, 0x7f ] ],
    },
    {
        name => "Separate NRPN MSB/LSB",
        nrpn => [ 0x0f, [ 0x01, 0x02 ], 0x1fff ],
        cc   => [ [ 0x0f, 0x63, 0x01 ],
                  [ 0x0f, 0x62, 0x02 ],
                  [ 0x0f, 0x06, 0x7f ],
                  [ 0x0f, 0x26, 0x3f ],
                  [ 0x0f, 0x65, 0x7f ],
                  [ 0x0f, 0x64, 0x7f ] ],
    },
    {
        name => "Separate NRPN value MSB/LSB",
        nrpn => [ 0x0f, [ 0x01, 0x02 ], [ 0x7f, 0x3f ] ],
        cc   => [ [ 0x0f, 0x63, 0x01 ],
                  [ 0x0f, 0x62, 0x02 ],
                  [ 0x0f, 0x06, 0x7f ],
                  [ 0x0f, 0x26, 0x3f ],
                  [ 0x0f, 0x65, 0x7f ],
                  [ 0x0f, 0x64, 0x7f ] ],
    },
    {
        name => "NRPN value MSB only",
        nrpn => [ 0x0f, [ 0x01, 0x02 ], [ 0x7f ] ],
        cc   => [ [ 0x0f, 0x63, 0x01 ],
                  [ 0x0f, 0x62, 0x02 ],
                  [ 0x0f, 0x06, 0x7f ],
                  [ 0x0f, 0x65, 0x7f ],
                  [ 0x0f, 0x64, 0x7f ] ],
    },
    {
        name => "NRPN MSB only, LSB is filled with 0x00",
        nrpn => [ 0x0f, [ 0x01 ], [ 0x7f ] ],
        cc   => [ [ 0x0f, 0x63, 0x01 ],
                  [ 0x0f, 0x62, 0x00 ],
                  [ 0x0f, 0x06, 0x7f ],
                  [ 0x0f, 0x65, 0x7f ],
                  [ 0x0f, 0x64, 0x7f ] ],
    },
);

for my $test ( @tests ) {
    subtest $test->{name} => sub {
        my @ccs = map { [ control_change => @{$_} ] } @{ $test->{cc} };
        plan scalar @ccs;

        $out->rpn( @{ $test->{rpn} } ) if $test->{rpn};
        $out->nrpn( @{ $test->{nrpn} } ) if $test->{nrpn};

        my $t = [ gettimeofday ];
        while ( @ccs ) {
            die "Messages did not arrive in good time"
                if ( tv_interval( $t ) > 1 );
            usleep( 1_000 );
            next unless my $event = $in->get_message_decoded;
            is ( $event, shift @ccs, $test->{name} );
        }
    }
}

done_testing;
