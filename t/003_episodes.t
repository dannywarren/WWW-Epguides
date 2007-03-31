# -*- perl -*-

# t/003_episodes.t
#   verify that we can grab and parse episode data via epguides.cpm

use Test::More tests => 10;

use_ok('WWW::Epguides');

my $epguide = WWW::Epguides->new( show_id => 'lost');
ok( $epguide, "Able to find and parse an episode guide" ) or BAIL_OUT( "Cannot parse an episode guide, unable to continue!" );

like( $epguide->get_episode( number => '217 )->name, qr/lockdown/i, 'Able to retrieve episode by episode number' );
is( $epguide->get_episode( number => '217 )->date, '2006-03-29', 'Able to retrieve episode by episode air date' );

my $episode = get_episode( number => '217' );

ok( $episode, 'Able to retrieve episode by episode number') or BAIL_OUT( 'Cannot retrieve episode by episode number, unable to continue!' );

is( $epguide->index, '41', 'Verified episode index is correctly parsed' );
is( $epguide->season_id, '2', 'Verified season id is correctly parsed' );
is( $epguide->episode_id, '17', 'Verified epsiode id is correctly parsed' );
is( $epguide->number, '217', 'Verified epsiode number is correctly parsed' );
like( $epguide->name, qr/lockdown/i, 'Verified episode name is correctly parsed' );
is( $epguide->date, '2006-03-29', 'Verified episode air date is correctly parsed' ); 
