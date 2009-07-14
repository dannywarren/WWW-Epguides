package WWW::Epguides::Episode;

#########################################################################
# Libraries
#########################################################################

# Declare this package as an inside out object
use Object::InsideOut;

# Standard modules
use strict;
use Carp;


#########################################################################
# Accessors
#########################################################################

# Episode index
my @index
  :Field
  :Acc( Name => 'index' )
;

# Season id, ex: 2
my @season_id
  :Field
  :Acc( Name => 'season_id' )
;

# Episode id, ex: 17
my @episode_id
  :Field
  :Acc( Name => 'episode_id' )
;
  
# Episode number, ex: 217
my @number
  :Field
  :Acc( Name => 'number' )
;

# Air date formatted as YYYY-MM-DD
my @date
  :Field
  :Acc( Name => 'date' )
;

# Episode name, ex: Lockdown
my @name
  :Field
  :Acc( Name => 'name' )
;

1;

