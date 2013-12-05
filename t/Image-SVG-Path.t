use warnings;
use strict;
use Test::More;
BEGIN { 
    use_ok('Image::SVG::Path', 'extract_path_info');
};
use Image::SVG::Path qw/extract_path_info/;

my $path1 = 'M6.93,103.36c3.61-2.46,6.65-6.21,6.65-13.29c0-1.68-1.36-3.03-3.03-3.03s-3.03,1.36-3.03,3.03s1.36,3.03,3.03,3.03C15.17,93.1,10.4,100.18,6.93,103.36z';

my @path_info = extract_path_info ($path1, {verbose => 0});

is ($path_info[0]->{type}, 'moveto');
is ($path_info[1]->{position}, 'relative');
is ($path_info[2]->{control2}->[1], -3.03);
is ($path_info[3]->{type}, 'shortcut-cubic-bezier');

my $path2 = 'M2,3l4,5';

my @path2_info = extract_path_info ($path2);

is ($path2_info[0]->{type}, 'moveto');
is ($path2_info[1]->{type}, 'line-to');
is ($path2_info[1]->{position}, 'relative');
is ($path2_info[1]->{end}->[0], 4);
is ($path2_info[1]->{end}->[1], 5);

done_testing ();
exit;

# Local variables:
# mode: perl
# End:
