# -*- perl -*-

# t/001_load.t - check module loading

use Test::More tests => 2;

BEGIN { use_ok( 'WWW::Epguides' ); }

my $object = WWW::Epguides->new( show_id => 'Lost' );
isa_ok ($object, 'WWW::Epguides');


