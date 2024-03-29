use strict;
use warnings;

use Test2::V0;

use MIDI::RtMidi::FFI ':all';

ok( rtmidi_get_compiled_api, 'have an API' );
my $apis = rtmidi_get_compiled_api( 1 );
ok( @{ $apis }, 'can get the APIs' );
my $valid_apis = [
    grep { $_ >= RTMIDI_API_UNSPECIFIED && $_ <= RTMIDI_API_RTMIDI_DUMMY } @{ $apis }
];
is( $apis, $valid_apis, 'APIs are valid' );

my $apis_by_name = [
    map { rtmidi_compiled_api_by_name( $_ ) }
    map { rtmidi_api_name( $_ ) }
    @{ $apis }
];
is( $apis, $apis_by_name, 'APIs retrieved by name' );

done_testing;
