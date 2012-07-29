package WWW::Epguides::Show;
use Moose;

# Child classes
use WWW::Epguides::Episode;


#########################################################################
# Attributes
#########################################################################

# The internal epguides id for this show
has 'id' =>
(
  is  => 'rw',
  isa => 'Int',
);

# The url friendly name for this show
has 'name' =>
(
  is  => 'rw',
  isa => 'Str',
);

# The proper title for this show
has 'title' =>
(
  is  => 'rw',
  isa => 'Str',
);

# The url for the epguides page for this show
has 'url' =>
(
  is  => 'rw',
  isa => 'URI',
);

# A hashref of raw episodes data, in the format pulled from epguides
has 'episodes_data' =>
(
  is  => 'rw',
  isa => 'Ref',
);

# A hashref of raw show data, in the format pulled from epguides
has 'show_data' =>
(
  is  => 'rw',
  isa => 'Ref',
);

# A list of episode objects
has 'episodes' =>
(
  is         => 'rw',
  isa        => 'ArrayRef[WWW::Epguides::Episode]',
  lazy_build => 1,
);


##############################################################################
# Builders
##############################################################################

sub _build_episodes
{
  my ( $self ) = @_;
  
  my @episodes;
  EPISODE: foreach my $episode_data ( @{ $self->episodes_data } )
  {
    my $episode = WWW::Epguides::Episode->new
    (
      id           => $episode_data->{number},
      code         => $episode_data->{production code},
      season       => $episode_data->{season},
      episode      => $episode_data->{episode},
      date         => $episode_data->{airdate},
      title        => $episode_data->{title},
      episode_data => $episode_data,
    );
    
    push @episodes, $episode;
  }
  
  return \@episodes;
}


##############################################################################
# Methods
##############################################################################


1;
