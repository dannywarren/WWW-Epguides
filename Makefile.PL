use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile
(
  NAME         => 'WWW::Epguides',
  VERSION_FROM => 'lib/WWW/Epguides.pm', 
  AUTHOR       => 'Danny Warren (perl@dannywarren.com)',
  ABSTRACT     => 'Parse epguides.com for TV show episode listings',
  PREREQ_PM    => {
                    'Object::InsideOut' => 3.14,
                    'LWP::UserAgent' => 5.805,
                    'HTML::TreeBuilder' => 3.23,
                    'Test::Simple' => 0.44,
                  },
);
