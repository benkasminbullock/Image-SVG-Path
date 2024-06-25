#!/home/ben/software/install/bin/perl
use Z;
use Image::SVG::Path ':all';
my $path;
while (<STDIN>) {
    $path .= $_;
}
my $rpath = reverse_path ($path);
$rpath =~ s!0+(,| |$)!$1!g;
print "$rpath";

