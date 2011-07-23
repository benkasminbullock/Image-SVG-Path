use warnings;
use strict;
use Test::More tests => 5;
BEGIN { use_ok('Image::SVG::Path', 'extract_path_info') };
use Image::SVG::Path qw/extract_path_info/;

my $path1 = 'M6.93,103.36c3.61-2.46,6.65-6.21,6.65-13.29c0-1.68-1.36-3.03-3.03-3.03s-3.03,1.36-3.03,3.03s1.36,3.03,3.03,3.03C15.17,93.1,10.4,100.18,6.93,103.36z';

my @path_info = extract_path_info ($path1, {verbose => 0});

ok ($path_info[0]->{type} eq 'moveto');
ok ($path_info[1]->{position} eq 'relative');
ok ($path_info[2]->{control2}->[1] == -3.03);
ok ($path_info[3]->{type} eq 'shortcut-cubic-bezier');
if (0) {
#dump_path (@path_info);

@path_info = extract_path_info ($path1, {verbose => 1, absolute => 1});

dump_path (@path_info);
@path_info = extract_path_info ($path1, {verbose => 1, absolute => 1, no_shortcuts => 1});

dump_path (@path_info);
}
my $path2 = "M 65,29 C 59,19 49,12 37,12 20,12 7,25 7,42 7,75 25,80 65,118 105,80 123,75 123,42 123,25 110,12 93,12 81,12 71,19 65,29 z";

my @path_info2 = extract_path_info ($path2, {verbose => 0});

dump_path (@path_info2);

# Extracted from http://en.wikipedia.org/wiki/File:French_suits.svg
# 2011-04-16 10:44:17

my $wikipedia_spade = "M 233.67878,387.99261 C 232.46008,393.05519 230.58508,397.60206 228.05378,401.58636 C 225.52259,405.5708 221.01477,410.48486 214.52253,416.36761 C 208.03039,422.25048 203.91323,426.75828 202.17878,429.89886 C 200.44449,433.03952 199.58509,436.22702 199.58503,439.46136 C 199.58511,443.96139 201.08509,447.71138 204.08503,450.71136 C 207.08511,453.71138 210.74134,455.21137 215.05378,455.21136 C 222.77369,455.21135 228.74469,449.57456 232.67878,443.43011 C 232.37984,450.14857 231.27283,455.52721 229.33503,459.55511 C 227.24915,463.89104 224.05522,467.47909 219.74128,470.33636 C 216.83647,472.26031 211.60073,473.94574 204.05378,475.39886 L 203.49128,477.80511 L 233.64753,477.80511 L 263.83503,477.80511 L 263.27253,475.39886 C 255.72557,473.94573 250.48983,472.26031 247.58503,470.33636 C 243.27109,467.47907 240.07717,463.89105 237.99128,459.55511 C 236.05637,455.53321 234.94845,450.1658 234.64753,443.46136 C 238.58188,449.59723 244.59308,455.21135 252.30378,455.21136 C 256.61623,455.21137 260.27245,453.71138 263.27253,450.71136 C 266.27244,447.71138 267.77245,443.96139 267.77253,439.46136 C 267.77244,436.22702 266.91307,433.03952 265.17878,429.89886 C 263.44431,426.75828 259.32716,422.25048 252.83503,416.36761 C 246.3428,410.48486 241.83498,405.5708 239.30378,401.58636 C 236.77249,397.60206 234.89749,393.05519 233.67878,387.99261 z ";

my @wikipedia_spade_info = extract_path_info ($wikipedia_spade, {verbose => 0});

dump_path (@wikipedia_spade_info);

exit;

sub dump_path
{
my @path_info = @_;
my $count = 0;
for my $element (@path_info) {
    $count++;
    print "Element $count:\n";
    for my $k (keys %$element) {
        my $val = $element->{$k};
        if (ref $val eq 'ARRAY') {
            $val = "[$val->[0], $val->[1]]";
        }
        print "   $k -> $val\n";
    }
}
}

# Local variables:
# mode: perl
# End:
