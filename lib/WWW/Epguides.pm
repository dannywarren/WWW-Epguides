package WWW::Epguides;
use Moose;

our $VERSION = '0.02';

# Child Modules
use WWW::Epguides::Show;

# Required modules
use IO::Scalar;
use Text::CSV;
use LWP::UserAgent;
use Text::Printf;


##############################################################################
# Attributes
##############################################################################

# The base url for the epguides website
has 'base_url' => 
(
  is      => 'rw',
  isa     => 'Str',
  default => 'http://www.epguides.com',
);

# The relative url for the show list page, which will be used to look up
# and determine which id to pass to the episodes page
has 'shows_url' =>
(
  is      => 'rw',
  isa     => 'Str',
  default => 'common/allshows.txt',
);

# The relative url for the episodes list page, which will be used to pull
# episode data for a given show
has 'episodes_url' =>
(
  is      => 'rw',
  isa     => 'Str',
  default => 'common/exportToCSV.asp?rage={{id}}',
);

# The relative url for the show page on epguides (not used for parsing,
# but it's useful to build this out while we have the raw data)
has 'show_url' =>
(
  is      => 'rw',
  isa     => 'Str',
  default => '{{directory}}',
);

# The name of our user agent (to be built later, so that it always conforms
# to the format suggested by LWP::UserAgent, unless someone wishes to
# override it themselves)
has 'ua_name' =>
(
  is         => 'rw',
  isa        => 'Str',
  lazy_build => 1,
);

# The user agent object used to pull show data from the web
has 'ua' => 
(
  is         => 'rw',
  isa        => 'LWP::UserAgent',
  lazy_build => 1,
);

# A hashref of raw show data, in the format pulled from epguides (this is
# retained for internal use, so it is kept in whatever format is returned by
# epguides)
has 'shows_data' =>
(
  is         => 'rw',
  isa        => 'Ref',
  lazy_build => 1,
);


##############################################################################
# Builders
##############################################################################

# Build an appropriate user agent string on demand
sub _build_ua_name
{
  my ( $self ) = @_;
  
  # Start with the name of this module (not hardcoded, in case someone
  # extends from us)
  my $ua_name = __PACKAGE__;
  
  # Replace the package seperator with a dash
  $ua_name =~ s/::/-/g;
  
  # Append the package version if one is defined, in the format suggested by
  # LWP::UserAgent, which is name/version
  if ( $VERSION )
  {
    $ua_name = join "/",
      $ua_name,
      $VERSION,
    ;
  }
  
  # Finally, slam it to lowercase
  $ua_name = lc $ua_name;
  
  return $ua_name;
}


# Build a user agent object on demand
sub _build_ua
{
  my ( $self ) = @_;
  
  # Initialze our user agent
  my $ua = LWP::UserAgent->new
  (
    agent => $self->ua_name,
  );
  
  return $ua;
}


# Build a hash of raw shows data on demand
sub _build_shows_data
{
  my ( $self ) = @_;
  
  # Use the public show parsing method to go ahead and build this now, since we
  # will always need it at least once to do anythign else with this module
  my $shows_data = $self->parse_shows;
  
  return $shows_data;
};


##############################################################################
# Methods
##############################################################################

# Return a WWW::Epguides::Show child object for a given show name
sub show
{
  my ( $self, $show_name ) = @_;
  
  # Pull raw data for this show
  my $show_data = $self->show_data( $show_name );
  
  # Pull raw data for all episodes for this show
  my $episodes_data = $self->parse_episodes( $show_name );
  
  # Fill in any values needed to build the url for this show
  # See: Text::Printf
  my $show_url = tsprintf
  (
    $self->show_url,
    $show_data,
  );
  
  # Build uri for the show page using the above relative url
  my $show_uri = URI->new( $self->base_url );
  $show_uri->path_query( $show_url );
  
  # Build the child class object for this show
  my $show = WWW::Epguides::Show->new
  (
    id            => $show_data->{id},
    name          => $show_data->{name},
    title         => $show_data->{title},
    url           => $show_uri,
    show_data     => $show_data,
    episodes_data => $episodes_data,
  );
  
  return $show;
}


# Return a hashref of data for a given show name
sub show_data
{
  my ( $self, $show_name ) = @_;
  
  # Look this show up in our raw show data hash
  my $show_data = $self->shows_data->{ lc $show_name };
  
  # Verify we actually found something
  if ( ! defined $show_data )
  {
    confess sprintf( "show not found: %s", $show_name );
    return;
  }
  
  return $show_data;
}


# Return a hashref of shows
sub parse_shows
{
  my ( $self ) = @_;
  
  # Build uri for the show data page
  my $shows_uri = URI->new( $self->base_url );
  $shows_uri->path( $self->shows_url );
  
  # Pull down the shows data
  my $shows_csv = $self->get_csv( $shows_uri );
  
  # Parse and return a hashref of raw show data from the csv
  my $shows_raw_data = $self->parse_csv( $shows_csv );
  
  # Collapse the above list of hashrefs in to a big hash, with the show name as
  # the key so we can look stuff up without having to iterate over the whole
  # list
  my %shows_data;
  SHOW: foreach my $show_data ( @{ $shows_raw_data } )
  {
    
    # First, let's grab a generic refernce id for this show, so that we only
    # have to refer to it by name once using internal value epguides is using
    # as their lookup id (especially if it changes in the future)
    my $show_id = $show_data->{tvrage};
    
    # Next, let's use the "directory" value for the show name, as that is the
    # url friendly compact name use by epguides
    # For consistancy, we will also slam it to lowercase as that seems to be
    # the right thing to do for a key (also, the epguides site itself is case
    # insensitive if you want to use this value to visit the show for other
    # reasons, so going to epguides.com/SomeShow and epguides.com/someshow will
    # both work fine)
    my $show_name = lc $show_data->{directory};
    
    # Skip this entry if it doesn't have the most basic information we will
    # need to do anything further
    # Usually this is just because the csv had a few blank lines in it, and
    # when that happens you get an entry full of undef values (Text::CSV does
    # not skip those lines, it treats them as empty data)
    if ( ! defined $show_name || ! defined $show_id )
    {
      next SHOW;
    }
    
    # Add our own values to the show data hash, so that other methods can use
    # them as well (and so we don't clobber the raw data we got from epguides)
    $show_data->{id}   = $show_id;
    $show_data->{name} = $show_name;
    
    # Add this show to our hash
    $shows_data{$show_name} = $show_data;
    
  }
  
  return \%shows_data;
}


# Return a list of episodes for a given show name
sub parse_episodes
{
  my ( $self, $show_name ) = @_;
  
  # Grab a hashref of raw epguides data for this show
  my $show_data = $self->show_data( $show_name );
  
  # Bail out now if we didn't get any show data (the above method will handle
  # the error, this will just keep us from doing any work if the result is
  # obviously null)
  return if ! defined $show_data;
  
  # Fill in any values needed to do the HTTP GET query using the configured url
  # value and the hashref of raw epguides data.  Doing things this way means
  # that if the url format changes in the future, it will be easy to adjust
  # without changing the code as long as the lookup value is in the raw show
  # data hash.
  # See: Text::Printf
  my $episodes_url = tsprintf
  (
    $self->episodes_url,
    $show_data,
  );
  
  # Build uri for the episode data page
  my $episodes_uri = URI->new( $self->base_url );
  $episodes_uri->path_query( $episodes_url );
  
  # Pull down the episode data
  my $episodes_csv = $self->get_csv( $episodes_uri );
  
  # Parse and return a hashref of episode data from the csv
  my $episodes_data = $self->parse_csv( $episodes_csv );
  
  return $episodes_data;
}


# Generic method for doing an HTTP GET on a url in order to return csv data
sub get_csv
{
  my ( $self, $url ) = @_;
  
  # Get the csv data from the given url
  my $response = $self->ua->get( $url );
  
  # Check to make sure we got it
  if ( $response->is_error )
  {
    confess sprintf( "unable to get csv from %s: %s", $url, $response->status_line );
    return;
  }
  
  # Grab the html content
  my $html = $response->content;
  
  # Because epguides sometimes returns their csv data inside an html document,
  # we will need to do something a little ghetto here.  Instead of using a
  # costly html parser to jump to the body/pre element, we will just brute 
  # force remove anything that looks like html and hope they don't change up
  # their templates too much.
  my @lines;
  LINE: foreach my $line ( split /\012\015?|\015\012?/, $html )
  {
    
    # Skip blanks lines, which actually helps our csv parser to not get
    # confused later (not really needed here, but since we are already hacking
    # around with the content...)
    next LINE if $line =~ /^\s*$/;
    
    # Skip lines that look like html
    if ( $line =~ /^\s*\</ && $line =~ /\>\s*$/ )
    {
      next LINE;
    }
    
    push @lines, $line;
    
  }
  
  # Join it all back up in to one blob of data, which by this point should be
  # just the csv
  my $csv = join "\n", @lines;
  
  return $csv;
}


# Generic method for parsing and returing csv data as a list of hashrefs
sub parse_csv
{
  my ( $self, $data ) = @_;
  
  # Initialize our csv parsing object
  my $csv = Text::CSV->new
  ({
    binary           => 1,
    allow_whitespace => 1,
    empty_is_undef   => 1,
  });
  
  # Create an in-memory filehandle for the csv data blob we were given, so
  # that we can use the fancy getline methods in the csv parser
  my $fh = new IO::Scalar \$data;
  
  # Assume the first row of the csv is always a header describing the column
  # layout of the rest of the csv data
  my $columns = $csv->getline( $fh );
  
  # Use that list of columsn we just parsed and set it in the csv, so that we
  # can use the hashref mode of the csv parser
  $csv->column_names( @{ $columns } );
  
  # Use the one-shot csv parser method to parse the csv data and return a list
  # of hashrefs for each row, using the column names defined above to determine
  # what each key/value pair means
  my $csv_data = $csv->getline_hr_all( $fh );
  
  # Check to make sure we parsed everything, if not the csv parser probably hit
  # an error
  if ( ! $csv->eof )
  {
    confess $csv->error_diag;
  }
  
  # Close the in-memory filehandle (we don't *really* need to do this since it
  # isnt a real file, but why not play nice?)
  close( $fh );
  
  return $csv_data;
}


1;
