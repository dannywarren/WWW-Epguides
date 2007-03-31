# -*- perl -*-

# t/002_shows.t
#   verify that we can grab and parse show data via epguides.cpm

use Test::More tests => 3;

use_ok('WWW::Epguides');

my $epguide = WWW::Epguides->new( show_id => 'lost' );
ok( $epguide, "Able to find and parse an episode guide" ) or BAIL_OUT( "Cannot parse an episode guide, unable to continue!" );

is( $epguide->show_name, 'Lost', 'Able to parse show name from episode guide' );
