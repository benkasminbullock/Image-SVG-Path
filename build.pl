#!/home/ben/software/install/bin/perl
use warnings;
use strict;
use Perl::Build;
use FindBin '$Bin';
perl_build (
pod => ["lib/Image/SVG/Path.pod"],
);

