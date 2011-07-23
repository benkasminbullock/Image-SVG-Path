use strict;
use warnings;
use ExtUtils::MakeMaker;

# $pm points to the main file of this package.

my $pm = 'lib/Image/SVG/Path.pm';

WriteMakefile (
    NAME => 'Image::SVG::Path',
    VERSION_FROM => $pm,
    ABSTRACT_FROM => $pm,
    AUTHOR => 'Ben Bullock <bkb@cpan.org>',
    LICENSE => 'perl',
);
