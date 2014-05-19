package Image::SVG::Path;
use warnings;
use strict;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw/extract_path_info reverse_path create_path_string/;
our $VERSION = '0.17';
use Carp;

# Return "relative" or "absolute" depending on whether the command is
# upper or lower case.

sub position_type
{
    my ($curve_type) = @_;
    if (lc $curve_type eq $curve_type) {
        return "relative";
    }
    elsif (uc $curve_type eq $curve_type) {
        return "absolute";
    }
    else {
        croak "I don't know what to do with '$curve_type'";
    }
}

sub add_coords
{
    my ($first_ref, $to_add_ref) = @_;
    $first_ref->[0] += $to_add_ref->[0];
    $first_ref->[1] += $to_add_ref->[1];
}

sub reverse_path
{
    my ($path) = @_;
    my $me = 'reverse_path';
    if (! $path) {
        croak "$me: no input";
    }
    my @values = extract_path_info ($path, {
        no_shortcuts => 1,
        absolute => 1,
    });
    if (! @values) {
        return '';
    }
    my @rvalues;
    my $end_point = $values[0]->{point};
    for my $value (@values[1..$#values]) {
        my $element = {};
        $element->{type} = $value->{type};
#        print "$element->{type}\n";
        if ($value->{type} eq 'cubic-bezier') {
            $element->{control1} = $value->{control2};
            $element->{control2} = $value->{control1};
            $element->{end} = $end_point;
            $end_point = $value->{end};
        }
        else {
            croak "Can't handle path element type '$value->{type}'";
        }
        unshift @rvalues, $element;
    }
    my $moveto = {
        type => 'moveto',
        point => $end_point,
    };
    unshift @rvalues, $moveto;
    my $rpath = create_path_string (\@rvalues);
    return $rpath;
}

sub create_path_string
{
    my ($info_ref) = @_;
    my $path = '';
    for my $element (@$info_ref) {
        my $t = $element->{type};
#        print "$t\n";
        if ($t eq 'moveto') {
            my @p = @{$element->{point}};
            $path .= sprintf ("M%f,%f ", @p);
        }
        elsif ($t eq 'cubic-bezier') {
            my @c1 = @{$element->{control1}};
            my @c2 = @{$element->{control2}};
            my @e = @{$element->{end}};
            $path .= sprintf ("C%f,%f %f,%f %f,%f ", @c1, @c2, @e);
        }
        elsif ($t eq 'closepath') {
            $path .= "Z";
        }
	else {
            croak "Don't know how to deal with type '$t'";
        }
    }
    return $path;
}

# The following regular expression splits the path into pieces
# Note we only split on '-' when it's not preceeded by 'e'

my $split_re = qr/
		     (?:
			 ,
		     |
			 (?<!e)(?=-)
		     |
			 \s+
		     )
		 /x;

# Match a number

my $number_re = qr/[-0-9.,e]+/i;

my $numbers_re = qr/(?:$number_re|\s)*/;

sub extract_path_info
{
    my ($path, $options_ref) = @_;
    my $me = 'extract_path_info';
    if (! $path) {
        croak "$me: no input";
    }
    # Create an empty options so that we don't have to
    # keep testing whether the "options" string is defined or not
    # before trying to read a hash value from it.
    if ($options_ref) {
        if (ref $options_ref ne 'HASH') {
            croak "$me: second argument should be a hash reference";
        }
    }
    else {
        $options_ref = {};
    }
    if (! wantarray) {
        croak "$me: extract_path_info returns an array of values";
    }
    my $verbose = $options_ref->{verbose};
    if ($verbose) {
        print "$me: I am trying to split up '$path'.\n";
    }
    my @path_info;
    my $has_moveto = ($path =~ /^\s*([Mm])\s*($numbers_re)(.*)$/s);
    if (! $has_moveto) {
        croak "No moveto at start of path '$path'";
    }
    my ($moveto_type, $move_to, $curves) = ($1, $2, $3);
    if ($verbose) {
        print "$me: The initial moveto looks like '$moveto_type' '$move_to'.\n";
    }
    # Deal with the initial "move to" command.
    my $position = position_type ($moveto_type);
    my @coords = split $split_re, $move_to;
    push @path_info, {
        type => 'moveto',
	name => 'moveto',
        position => $position,
        point => [@coords[0, 1]],
        svg_key => $moveto_type,
    };
    # Deal with any implicit line-to's remaining.
    if (@coords > 2) {
	if ($verbose) {
	    print "$me: dealing with extra stuff in ", join (', ', @coords),
	    ".\n";
	}
	my $n_coords = scalar (@coords);
	if ($n_coords % 2 != 0) {
	    croak "Odd number of coordinates";
	}
	for my $i (1..($n_coords / 2 - 1)) {
	    my ($x, $y) = ($coords[2*$i], $coords[2*$i + 1]);
	    push @path_info, {
		type => 'line-to',
		name => 'lineto',
		position => $position,
		point => [$x, $y],
		svg_key => ($position eq 'absolute' ? 'L' : 'l'),
	    };
	}
    }
    # Deal with the rest of the path.
    my @curves;
    while ($curves =~ /\G([cslqtahvzm])\s*($numbers_re)/gi) {
        push @curves, [$1, $2];
    }
    for my $curve_data (@curves) {
        my ($curve_type, $curve) = @$curve_data;
        $curve =~ s/^,//;
        my @numbers = split $split_re, $curve;
        if ($verbose) {
            print "Extracted numbers: @numbers\n";
        }
        if (uc $curve_type eq 'C') {
            my $expect_numbers = 6;
            if (@numbers % 6 != 0) {
                croak "Wrong number of values for a C curve " .
                    scalar @numbers . " in '$path'";
            }
            my $position = position_type ($curve_type);
            for (my $i = 0; $i < @numbers / 6; $i++) {
                my $offset = 6 * $i;
                my @control1 = @numbers[$offset + 0, $offset + 1];
                my @control2 = @numbers[$offset + 2, $offset + 3];
                my @end      = @numbers[$offset + 4, $offset + 5];
                # Put each of these abbreviated things into the list
                # as a separate path.
                push @path_info, {
                    type => 'cubic-bezier',
		    name => 'curveto',
                    position => $position,
                    control1 => \@control1,
                    control2 => \@control2,
                    end => \@end,
                    svg_key => $curve_type,
                };
            }
        }
        elsif (uc $curve_type eq 'S') {
            my $expect_numbers = 4;
            if (@numbers % $expect_numbers != 0) {
                croak "Wrong number of values for an S curve " .
                    scalar @numbers . " in '$path'";
            }
            my $position = position_type ($curve_type);
            for (my $i = 0; $i < @numbers / $expect_numbers; $i++) {
                my $offset = $expect_numbers * $i;
                my @control2 = @numbers[$offset + 0, $offset + 1];
                my @end      = @numbers[$offset + 2, $offset + 3];
                push @path_info, {
                    type => 'shortcut-cubic-bezier',
		    name => 'shorthand/smooth curveto',
                    position => $position,
                    control2 => \@control2,
                    end => \@end,
                    svg_key => $curve_type,
                };
            }
        }
        elsif (uc $curve_type eq 'L') {
            my $expect_numbers = 2;
            if (@numbers % $expect_numbers != 0) {
                croak "Wrong number of values for an L command " .
                    scalar @numbers . " in '$path'";
            }
            my $position = position_type ($curve_type);
            for (my $i = 0; $i < @numbers / $expect_numbers; $i++) {
                my $offset = $expect_numbers * $i;
		my $point = [@numbers[$offset, $offset + 1]];
                push @path_info, {
                    type => 'line-to',
                    position => $position,
		    # Bugwards compatibility, keep "end" even though
		    # it's a bug.
                    end => [@numbers[$offset, $offset + 1]],
		    point => $point,
                    svg_key => $curve_type,
                }
            }
        }
        elsif (uc $curve_type eq 'Z') {
            if (@numbers > 0) {
                croak "Wrong number of values for a Z command " .
                    scalar @numbers . " in '$path'";
            }
            my $position = position_type ($curve_type);
	    push @path_info, {
		type => 'closepath',
		name => 'closepath',
		position => $position,
		svg_key => $curve_type,
            }
        }
        elsif (uc $curve_type eq 'Q') {
            my $expect_numbers = 4;
            if (@numbers % $expect_numbers != 0) {
                croak "Wrong number of values for an L command " .
                    scalar @numbers . " in '$path'";
            }
            my $position = position_type ($curve_type);
            for (my $i = 0; $i < @numbers / $expect_numbers; $i++) {
                my $o = $expect_numbers * $i;
                push @path_info, {
                    type => 'quadratic-bezier',
		    name => 'quadratic Bézier curveto',
                    position => $position,
                    control => [@numbers[$o, $o + 1]],
                    end => [@numbers[$o + 2, $o + 3]],
                    svg_key => $curve_type,
                }
            }
        }
        elsif (uc $curve_type eq 'T') {
            my $expect_numbers = 2;
            if (@numbers % $expect_numbers != 0) {
                croak "Wrong number of values for an L command " .
                    scalar @numbers . " in '$path'";
            }
            my $position = position_type ($curve_type);
            for (my $i = 0; $i < @numbers / $expect_numbers; $i++) {
                my $o = $expect_numbers * $i;
                push @path_info, {
                    type => 'shortcut-quadratic-bezier',
		    name => 'Shorthand/smooth quadratic Bézier curveto',
                    position => $position,
                    end => [@numbers[$o, $o + 1]],
                    svg_key => $curve_type,
                }
            }
        }
        elsif (uc $curve_type eq 'H') {
            my $position = position_type ($curve_type);
            for (my $i = 0; $i < @numbers; $i++) {
                push @path_info, {
                    type => 'horizontal-line-to',
		    name => 'horizontal lineto',
                    position => $position,
                    x => $numbers[$i],
                    svg_key => $curve_type,
                }
            }
        }
        elsif (uc $curve_type eq 'V') {
            my $position = position_type ($curve_type);
            for (my $i = 0; $i < @numbers; $i++) {
                push @path_info, {
                    type => 'vertical-line-to',
		    name => 'vertical lineto',
                    position => $position,
                    y => $numbers[$i],
                    svg_key => $curve_type,
                }
            }
        }
        elsif (uc $curve_type eq 'A') {
            my $position = position_type ($curve_type);
	    if (@numbers != 7) {
		croak "Need 7 parameters for arc";
	    }
	    my %arc;
	    $arc{type} = 'arc';
	    $arc{name} = 'elliptical arc';
	    @arc{qw/rx ry x_axis_rotation large_arc_flag sweep_flag x y/} = 
	    @numbers;
	    push @path_info, \%arc;
        }
	elsif (uc $curve_type eq 'M') {
	    my $position = position_type ($curve_type);
	    if (@numbers != 2) {
		croak "Need 2 numbers for move to";
	    }
	    push @path_info, {
		type => 'moveto',
		name => 'moveto',
		position => $position,
		point => [@numbers],
		svg_key => $curve_type,
	    };
	}
        else {
            croak "I don't know what to do with a curve type '$curve_type'";
        }
    }
    # Now sort it out if the user wants to get rid of the absolute
    # paths etc. 
    
    my $absolute = $options_ref->{absolute};
    my $no_shortcuts = $options_ref->{no_shortcuts};
    if ($absolute) {
        if ($verbose) {
            print "Making all coordinates absolute.\n";
        }
        my $abs_pos;
        my $previous;
        for my $element (@path_info) {
            if ($element->{type} eq 'moveto') {
                if ($element->{position} eq 'relative') {
                    my $ip = $options_ref->{initial_position};
                    if ($ip) {
                        if (ref $ip ne 'ARRAY' ||
                            scalar @$ip != 2) {
                            croak "The initial position supplied doesn't look like a pair of coordinates";
                        }
                        add_coords ($element->{point}, $ip);
                    }
                }
                $abs_pos = $element->{point};
            }
            elsif ($element->{type} eq 'line-to') {
                if ($element->{position} eq 'relative') {
                    add_coords ($element->{end},      $abs_pos);
                }
                $abs_pos = $element->{end};
            }
            elsif ($element->{type} eq 'cubic-bezier') {
                if ($element->{position} eq 'relative') {
                    add_coords ($element->{control1}, $abs_pos);
                    add_coords ($element->{control2}, $abs_pos);
                    add_coords ($element->{end},      $abs_pos);
                }
                $abs_pos = $element->{end};
            }
            elsif ($element->{type} eq 'shortcut-cubic-bezier') {
                if ($element->{position} eq 'relative') {
                    add_coords ($element->{control2}, $abs_pos);
                    add_coords ($element->{end},      $abs_pos);
                }
                if ($no_shortcuts) {
                    if (!$previous) {
                        die "No previous element";
                    }
                    if ($previous->{type} ne 'cubic-bezier') {
                        die "Bad previous element type $previous->{type}";
                    }
                    $element->{type} = 'cubic-bezier';
                    $element->{svg_key} = 'C';
                    $element->{control1} = [
                        2 * $abs_pos->[0] - $previous->{control2}->[0],
                        2 * $abs_pos->[1] - $previous->{control2}->[1],
                    ];
                }
                $abs_pos = $element->{end};
            }
            $element->{position} = 'absolute';
            $element->{svg_key} = uc $element->{svg_key};
            $previous = $element;
        }
    }
    return @path_info;
}

1;

__END__

=head1 NAME

Image::SVG::Path - read the "d" attribute of an SVG path

=head1 SYNOPSIS

    use Image::SVG::Path 'extract_path_info';
    my @path_info = extract_path_info ($path_d_attribute);

=head1 DESCRIPTION

This module extracts information contained in the "d" attribute of an
SVG <path> element and turns it into a simpler series of steps. 

For example, an SVG <path> element might take the form

    <path d="M9.6,20.25c0.61,0.37,3.91,0.45,4.52,0.34c2.86-0.5,14.5-2.09,21.37-2.64c0.94-0.07,2.67-0.26,3.45,0.04"/>

Using an XML parser, such as L<XML::Parser>,

    use XML::Parser;
    use Image::SVG::Path 'extract_path_info';
    my $p = XML::Parser->new (Handlers => {Start => \& start});
    $p->parsefile ($file)
        or die "Error $file: ";

    sub start
    {
        my ($expat, $element, %attr) = @_;

        if ($element eq 'path') {
            my $d = $attr{d};
            my @r = extract_path_info ($d);
            # Do something with path info in @r
        }
    }

SVG means "scalable vector graphics" and it is a standard of the W3
consortium. See L<http://www.w3.org/TR/SVG/> for the full
specification. See L<http://www.w3.org/TR/SVG/paths.html> for the
specification for paths. Although SVG is a type of XML, the text in
the d attribute of SVG paths is not in the XML format but in a more
condensed form using single letters and numbers. This module is a
parser for that condensed format.

=head1 FUNCTIONS

=head2 extract_path_info

    my @path_info = extract_path_info ($path_d_attribute);

Turn the SVG path string into a series of simpler things. For example,

    my @path_info = extract_path_info ('M6.93,103.36c3.61-2.46,6.65-6.21,6.65-13.29c0-1.68-1.36-3.03-3.03-3.03s-3.03,1.36-3.03,3.03s1.36,3.03,3.03,3.03C15.17,93.1,10.4,100.18,6.93,103.36z');

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

This prints out
  
    Element 1:                         
       point -> [6.93, 103.36]         
       svg_key -> M                    
       position -> absolute            
       type -> moveto                  
    Element 2:                         
       control1 -> [3.61, -2.46]       
       svg_key -> c                    
       control2 -> [6.65, -6.21]       
       position -> relative            
       type -> cubic-bezier            
       end -> [6.65, -13.29]           
    Element 3:                         
       control1 -> [0, -1.68]          
       svg_key -> c                    
       control2 -> [-1.36, -3.03]      
       position -> relative            
       type -> cubic-bezier            
       end -> [-3.03, -3.03]           
    Element 4:                         
       svg_key -> s                    
       control2 -> [-3.03, 1.36]       
       position -> relative            
       type -> shortcut-cubic-bezier   
       end -> [-3.03, 3.03]            
    Element 5:                         
       svg_key -> s                    
       control2 -> [1.36, 3.03]        
       position -> relative            
       type -> shortcut-cubic-bezier   
       end -> [3.03, 3.03]             
    Element 6:                         
       control1 -> [15.17, 93.1]       
       svg_key -> C                    
       control2 -> [10.4, 100.18]      
       position -> absolute            
       type -> cubic-bezier            
       end -> [6.93, 103.36]
    Element 7:
       svg_key -> z
       position -> relative
       type -> closepath

The return value is a list of hash references. Each hash reference has
at least three keys, C<type>, C<position>, and C<svg_key>. The C<type>
field says what type of thing it is, for example a cubic bezier curve
or a line. The C<position> value is either "relative" or "absolute"
depending on whether the coordinates of this step of the path are
relative to the current point (relative) or to the drawing's origin
(absolute). The C<svg_key> field is the original key from the
path. C<position> is relative if this key is lower case and absolute
if this key is upper case.

If C<type> is C<moveto>, the hash reference contains one more field,
C<point>, which is the point to move to. This is an array reference
containing the I<x> and I<y> coordinates as elements indexed 0 and 1
respectively.

If the type is C<cubic-bezier>, the hash reference contains three more
fields, C<control1>, C<control2> and C<end>. The value of each is an
array reference containing the I<x> and I<y> coordinates of the first
and second control points and the end point of the Bezier curve
respectively. (The start point of the curve is the end point of the
previous part of the path.)

If the type is C<shortcut-cubic-bezier>, the hash contains two more
fields, C<control2> and C<end>. C<control2> is the second control
point, and C<end> is the end point. The first control point is got by
reflecting the second control point of the previous curve around the
end point of the previous curve (the start point of the current
curve). 

There is also an option L</no_shortcuts> which automatically replaces
shortcut cubic bezier curves with the normal kind, by calculating the
first control point.

A second argument to C<extract_path_info> contains options for the
extraction in the form of a hash reference. For example,

    my @path_info = extract_path_info ($path, {absolute => 1});

The following may be chosen by adding them to the hash reference:

=over

=item absolute

If the hash element C<absolute> is set to a true value, relative
positions are changed to absolute. For example a "c" curve is changed
to the equivalent "C" curve.

=item no_shortcuts

If the hash element C<no_shortcuts> is set to a true value then
shortcuts ("S" curves) are changed into the equivalent "C" curves. A
deficiency of this is that it only works in combination with the
"absolute" option, otherwise it does nothing.

=item verbose

If this is set to a true value, C<extract_path_info> prints out
informative messages about what it is doing as it parses the path.

=back

=head2 reverse_path

    my $reverse_path = reverse_path ($path);

Make an SVG path which is the exact reverse of the input.

=head3 BUGS

This only works for cubic bezier curves with absolute position and no
shortcuts (C elements only). It doesn't fill in all the information
correctly.

=head2 create_path_string

    my $path = create_path_string (\@info);

Given a set of information as created by L</extract_path_info>, turn
them into an SVG string representing a path.

=head3 BUGS

This only works for cubic bezier curves and the initial moveto element
for absolute position and no shortcuts (C elements only).

=head1 SVG path elements

This section documents the output elements. For example, if we extract
the path information from a path C<$d> using

    my @path = extract_path_info ($d);

then each element of C<@path> is a hash reference containing one of
the following types of elements and the corresponding hash keys.

An SVG path consists of a sequence of movements from one point to
another, so each of the following steps in the path begins from the
end point of the previous movement.

=head2 Move to elements

=over

=item svg_key

This is M or m.

=item point

This is the point to move to.

=back

=head2 Line elements

=over

=item svg_key

This is L or l.

=item point

This is the end point of the line.

=item end

This field occurs in some lines for backwards compatibility with
pre-0.16 versions of the module.

=back

=head2 Cubic bezier curve elements

=over

=item svg_key

This is C or c.

=item control1

Control point 1 of the curve.

=item control2

Control point 2 of the curve.

=item end

The end point of the curve.

=back

=head2 Shortcut cubic bezier curve elements

Use the L</no_shortcuts> option to remove these automatically.

=over

=item svg_key

This is S or s.

=item control2

This is the second control point of the curve (the first one is implicit).

=item end

This is the end point of the curve.

=back

=head2 Quadratic bezier curve elements

=over

=item svg_key

This is Q or q.

=item control

This is the control point.

=item end

This is the end point.

=back

=head2 Shortcut quadratic Bezier curves

Use the L</no_shortcuts> option to remove these automatically.

=over

=item svg_key

This is T or t.

=item end

This is the end point.

=back

=head2 Arc elements

=over

=item rx, ry

X and Y radiuses

=item x_axis_rotation

=item large_arc_flag

=item sweep_flag

=item x, y

=back

=head2 Horizontal line elements

=over

=item svg_key

This is H or h.

=item x

This is the x coordinate of the end point. The y coordinate is implicit.

=back

=head2 Vertical line elements

=over

=item svg_key

This is V or v.

=item y

This is the y coordinate of the end point. The x coordinate is implicit.

=back

=head1 BUGS

=over

=item Does not use the grammar

There is a grammar for the paths in the W3 specification. See
L<http://www.w3.org/TR/SVG/paths.html#PathDataBNF>. However, this
module does not use that grammar. Instead it hacks up the path using
regexes.

=back

=head1 EXPORTS

The module exports L</extract_path_info> on demand, so 

     use Image::SVG::Path 'extract_path_info';

imports it.

=head1 SEE ALSO

L<MarpaX::Languages::SVG::Parser>

This parser uses the SVG grammar mentioned in L</BUGS>.

=head1 AUTHOR

Ben Bullock, <bkb@cpan.org>

=head1 LICENCE

This module and all associated files can be used, modified and
distributed under either the Perl artistic licence or the GNU General
Public Licence.

=cut
