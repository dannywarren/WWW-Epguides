package WWW::Epguides;

our $VERSION = '0.01_2';

#########################################################################
# Libraries
#########################################################################

# Declare this package as an inside out object
use Object::InsideOut;

# Standard modules
use strict;
use Carp;

# Package modules
use WWW::Epguides::Episode;

# Required modules
use HTML::TreeBuilder;
use LWP::UserAgent;


#########################################################################
# Accessors
#########################################################################

# The id of the show, which is how the show would be accessed via the
# epguides site.  Example: www.epguides.com/[show_id]
my @show_id
  :Field
  :Arg( Name => 'show_id', Mandatory => 1 )
  :Acc( Name => 'show_id' )
;

# Base url of epguides website
my @base_url
  :Field
  :Arg( Name => 'base_url' )
  :Acc( Name => 'base_url' )
  :Default( 'http://epguides.com/' )
;

# Url of the show at the epguides website
my @show_url
  :Field
  :Acc( Name => 'show_url' )
;

# User agent object
my @ua
  :Field
  :Type( LWP::UserAgent )
  :Acc( Name => 'ua' )
;
  
# Treebuilder object for parsing html
my @tree
  :Field
  :Type( HTML::TreeBuilder )
  :Acc( Name => 'tree' )
;
  
# Content as html of epguides page
my @html
  :Field
  :Acc( Name => 'html' )
;

# Show name
my @show_name
  :Field
  :Acc( Name => 'show_name' )
  ;

# List of Episode objects
my @episodes
  :Field
  :Type(list)
  :Acc( Name => 'episodes' )
;

# Holds episode data by date
my @episodes_by_date
  :Field
  :Type(HASH)
  :Acc( Name => 'episodes_by_date' )
;

# Holds episode data by number
my @episodes_by_number
  :Field
  :Type(HASH)
  :Acc( Name => 'episodes_by_number' )
;


#########################################################################
# Object Methods
#########################################################################

# Object initialization
sub _init :Init
{
  my $self = shift;
  
  # Create a mechanize object
  $self->ua( LWP::UserAgent->new );
  
  # Set the show url
  $self->show_url( $self->base_url . '/' . $self->show_id );
  
  # Get the show from the epguides site
  $self->html( $self->ua->get( $self->show_url )->content );
  
  # Get the content of the url
  $self->tree( HTML::TreeBuilder->new_from_content( $self->html ) );
  
  # Parse the show name
  $self->_parse_show_name;
  
  # Parse the episodes data
  $self->_parse_episodes;
  
  return;
}


#########################################################################
# Methods
#########################################################################

sub get_episode
{
  my $self    = shift;
  my %options = @_;
  
  if ( defined $options{number} )
  {
    return $self->episodes_by_number->{$options{number}};
  }
  
  if ( defined $options{date} )
  {
    return $self->episodes_by_date->{$options{date}};
  }
  
}


#########################################################################
# Private Methods
#########################################################################

# Parse the show name
sub _parse_show_name
{
  my $self = shift;
  
  $self->show_name( $self->tree->look_down( 'href', qr/imdb\.com/ )->as_text );
}


# Parse episodes data
sub _parse_episodes
{
  my $self = shift;
  
  # Define a list of months, as they are defined on epguides.com and
  # correlate them to a numeric month (ex: Jan -> 01)
  my %months =
  (
    Jan => '01',
    Feb => '02',
    Mar => '03',
    Apr => '04',
    May => '05',
    Jun => '06',
    Jul => '07',
    Aug => '08',
    Sep => '09',
    Oct => '10',
    Nov => '11',
    Dec => '12',
  );
  
  # Variables that will be used for building episode data, which will
  # then be set into this object
  my @episodes;
  my %episodes_by_date;
  my %episodes_by_number;
  
  # Get the episode list data as text
  my $episode_data = $self->tree->look_down( '_tag', 'pre' )->as_text;
  
  # Iterate over the show data to build the episode list
  LINE: foreach my $line (split /\n/, $episode_data)
  {
    # Strip newlines
    $line =~ s/[\n\r]//g;
    
    # Skip the line if it does not contain any data formatted like
    # an episode number (since this is the only thing consistant
    # about all episode entries)
    next LINE if $line !~ /[PS\d]+-\s?\d+/;
    
    # Get the episode index, which is the raw ordering number of
    # the episode and usually the first entry
    my ($episode_index) = $line =~ /^\s*(\d+)/;
    
    # Get the season id, which is the first number in a 5-14
    # formatted episode number.  This might also be a P for pilot.
    # We will skip S (for Special) episodes as these do not have
    # useful or reliable episode numbers.
    my ($episode_season_id) = $line =~ /([P\d]+)-\s?\d+/;
    
    # Change the episode season id to '1' if it is a 'P' episode (since we
    # would rather see the pilot episode listed as 101 instead of P01)
    $episode_season_id =~ s/P/1/gi if defined $episode_season_id;
    
    # Get the episode id, which is the second number in a 5-14
    # formatted episode number
    my ($episode_number_id) = $line =~ /[P\d]+-\s?(\d+)/;
    
    # Build the episode number so that it is formatted like 514 or 502 (instead
    # of 5-14 or 5- 2)
    my $episode_number = sprintf('%s%02d', $episode_season_id, $episode_number_id) if defined $episode_season_id and defined $episode_number_id;
    
    # Get the episode air date, which is formatted like DD MMM YY
    my ($episode_day, $episode_month, $episode_year) = $line =~ /(\d{1,2})[\s\/-](\w{3,3})[\s\/-](\d{2,2})/;
    
    # Build the episode air date in the format YYYY-MM-DD
    my $episode_date;
    if ( defined $episode_day and defined $episode_month and defined $episode_day )
    {
      $episode_date = join '-', 
        sprintf('%d%02d', $episode_year < 50 ? 20 : 19, $episode_year), # ex: 04 -> 2004, 99 -> 1999
        $months{$episode_month},                                        # ex: Mar -> 03, Oct -> 10
        sprintf('%02d', $episode_day),                                  # ex: 2 -> 02, 10 -> 10
        ;
    }
    
    # Get the episode title, which is the rightmost chunk of text 
    my $episode_name = (split /\s{2,}/, $line)[-1]; 
    
    # Create the episode entry
    my $episode = WWW::Epguides::Episode->new;
    
    # Set data for this episode
    $episode->index       ( $episode_index )      if defined $episode_index;
    $episode->season_id   ( $episode_season_id )  if defined $episode_season_id;
    $episode->episode_id  ( $episode_number_id )  if defined $episode_number_id;
    $episode->number      ( $episode_number )     if defined $episode_number;
    $episode->date        ( $episode_date )       if defined $episode_date;
    $episode->name        ( $episode_name )       if defined $episode_name;
    
    # Add this episode to our by number hash
    $episodes_by_number{$episode->number} = $episode if defined $episode->number;
          
    # Add this episode to our by date hash
    $episodes_by_date{$episode->date} = $episode if defined $episode->date;
    
    # Add this episode to our episode list
    push @episodes, $episode;
  }
  
  # Add episodes list to the object
  $self->episodes( @episodes );
  $self->episodes_by_number( %episodes_by_number );
  $self->episodes_by_date( %episodes_by_date );
}

1;

