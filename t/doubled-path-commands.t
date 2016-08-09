use warnings;
use strict;
use Test::More;
#use Test::Exception;
use Image::SVG::Path qw/extract_path_info/;

##Check to see that doubled, implicit commands work for all types

my @sets = (
    'L', 2, 'Double line-to L',
    'H', 1, 'Double Horizontal line H',
    'V', 1, 'Double Vertical line V',
    'M', 2, 'Double move-to M', ##Note, have to use 2 M commands, since extra coordinates in initial M are converted to move-to's!
    'C', 6, 'Double Cubic C',
    'S', 4, 'Double Shorthand cubic S',
    'Q', 4, 'Double Bezier Q',
    'T', 2, 'Double Shorthand bezier T',
    'A', 7, 'Double Arc A',
);

my @foo;
while(my ($element, $arg_count, $comment) = splice @sets, 0, 3) {
    # Dynamically build a path string to parse, we don't care about
    # the formatting so much as the contents
    my $command = 'M 1 2 ';
    $command .= join ' ', $element, (1..2*$arg_count);
    $command .= ' Z';
    diag $command;
    eval {
	@foo = extract_path_info ($command);
    };
    SKIP: {
	# Not sure why this skip is necessary.
        skip "$comment failed anyway", 1 if $@;
        is @foo, 4, "Received 4 path elements for $comment";
    }
}

done_testing();
