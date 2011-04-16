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
