# -*- perl -*-

# t/004_exceptions.t
#   verify that exceptions are thrown 

use Test::More tests => 2;

use_ok('WWW::Epguides');

eval { WWW::Epguides->new( show_id => 'ksdfjlksdjfsldkfjsdlkfjsdlkfjdslfkjs' ) };

ok( Exception::Class->caught('EpguidesException'), "Able to catch exception" );
