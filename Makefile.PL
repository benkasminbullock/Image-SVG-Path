use strict;
use warnings;
use ExtUtils::MakeMaker;

# $pm points to the main file of this package.

my $pm = 'lib/Image/SVG/Path.pm';
my $repo = 'https://github.com/benkasminbullock/Image-SVG-Path';

WriteMakefile (
    NAME => 'Image::SVG::Path',
    VERSION_FROM => $pm,
    ABSTRACT_FROM => $pm,
    AUTHOR => 'Ben Bullock <bkb@cpan.org>',
    LICENSE => 'perl',
    META_MERGE => {
        resources => {
            repository => $repo,
            bugtracker => "$repo/issues",
        },
    },
    MIN_PERL_VERSION => '5.006001',
);
