package Image::SVG::Path;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw/extract_path_info/;
use warnings;
use strict;
our $VERSION = 0.03;
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

# The following regular expression splits the path into pieces

my $split_re = qr/(?:,|(?=-)|\s+)/;

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
    my $has_moveto = ($path =~ /^([Mm])\s*,?\s*([-0-9.,]+)(.*)$/);
    if (! $has_moveto) {
        croak "No moveto at start of path '$path'";
    }
    my ($moveto_type, $move_to, $curves) = ($1, $2, $3);
    if ($verbose) {
        print "$me: The initial moveto looks like '$moveto_type' '$move_to'.\n";
    }
    # Deal with the initial "move to" command.
    my $position = position_type ($moveto_type);
    my ($x, $y) = split $split_re, $move_to, 2;
    push @path_info, {
        type => 'moveto',
        position => $position,
        point => [$x, $y],
        svg_key => $moveto_type,
    };
    # Deal with the rest of the path.
    my @curves;
    while ($curves =~ /([cslqtahv])\s*([-0-9.,\s]+)/gi) {
        push @curves, [$1, $2];
    }
    if (@curves == 0) {
        croak "No curves found in '$curves'";
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
                    position => $position,
                    control2 => \@control2,
                    end => \@end,
                    svg_key => $curve_type,
                };
            }
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
                            croak "The initial position you supplied doesn't look like a pair of coordinates";
                        }
                        add_coords ($element->{point}, $ip);
                    }
                }
                $abs_pos = $element->{point};
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

    use Image::SVG::Path qw/extract_path_info/;
    my @path_info = extract_path_info ($path_d_attribute);

This module is for extracting the information contained in the "d"
attribute of an SVG <path> element and turning it into a simpler
series of steps. SVG means "scalable vector graphics" and it is a
standard of the W3 consortium. See L<http://www.w3.org/TR/SVG/> for
the full specification. See L<http://www.w3.org/TR/SVG/paths.html> for
the specification for paths.

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

The return value is an array containing a sequence of hash
references. Each of the hash references has the three fields "type",
"position", and "svg_key". The C<type> field says what type of thing
it is. The C<position> value is either "relative" or "absolute". The
C<svg_key> field is the original key from the path.

If the type is "moveto", the hash contains one more field, "point",
which is the point to move to as an array reference containing the x
and y coordinates.

If the type is "cubic-bezier", the hash contains three more fields,
C<control1>, C<control2> and C<end>, each array references containing
the x and y coordinates of the first and second control points and the
end point of the Bezier curve respectively. (The start point of the
curve is the end point of the previous part of the path.)

If the type is "shortcut-cubic-bezier", the hash contains two more
fields, C<control2> and C<end>. C<control2> is the second control
point, and C<end> is the end point. The first control point is got by
reflecting the second control point of the previous curve around the
end point of the previous curve (the start point of the current
curve). If you find that confusing then you might want to switch on
the L</no_shortcuts> option which will automatically replace shortcut
cubic bezier curves with the normal kind, by calculating the first
control point for you.

There is a second argument of a hash reference which you can use to
make a request.

    my @path_info = extract_path_info ($path, {absolute => 1});

You can set a combination of the following values:

=over

=item absolute

If this is set to a true value, it changes relative to absolute
positions. For example a curve marked with "c" is changed to the
equivalent "C" curve. 

=item initial_position

The initial position of the path for the case that the path begins
with a relative moveto rather than an absolute one.

=item no_shortcuts

If this is set to a true value then shortcuts ("S" curves) are changed
into the equivalent "C" curves. A deficiency of this is that it only
works in combination with the "absolute" option, otherwise it does
nothing.

=item verbose

If this is set to a true value, it prints out messages about what it
is doing as it parses the path.

=back

=head1 BUGS

=over

=item Only cubic bezier curves

Right now the module only deals with cubic bezier curves. It doesn't
deal with quadratic bezier curves, elliptical arcs, or lines. That is
because I haven't come across any of these in the SVG files I have
looked at.

=item Doesn't use the grammar

There is a grammar for the paths in the W3 specification. See
L<http://www.w3.org/TR/SVG/paths.html#PathDataBNF>. However, this
module doesn't use that grammar, it just hacks up the path using
regexes.

=back

=head1 EXPORTS

The module exports L</extract_path_info> on demand, so you need to say

     use Image::SVG::Path 'extract_path_info';

to import it into your namespace.

=head1 AUTHOR

Ben Bullock, <bkb@cpan.org>

=head1 LICENCE

You can use, modify and distribute this Perl module and all the
associated files under either the Perl artistic licence or the GNU
General Public Licence.

=cut
