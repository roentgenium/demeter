package Demeter::UI::Wx::SpecialCharacters;

use strict;
use Encode;
use base qw( Exporter );
our @EXPORT_OK = qw(emph $CHI $EPSILON $DELTA $SIGMA $SIGSQR $PHI $COPYRIGHT $LAQUO $RAQUO $MDASH);
our %EXPORT_TAGS = (all   => [qw(emph $CHI $EPSILON $DELTA $SIGMA $SIGSQR $PHI $COPYRIGHT $LAQUO $RAQUO $MDASH)],
		    greek => [qw($CHI $EPSILON $DELTA $SIGMA $SIGSQR $PHI)],
		   );

my $is_windows = (($^O eq 'MSWin32') or ($^O eq 'cygwin'));

## -------- greek characters
our $CHI     = chr(967); #"\xCF\x87"; #'χ';
our $EPSILON = chr(949); #"\xCE\xB5"; #'ε';
our $DELTA   = chr(916); #"\xCE\x94"; #'Δ';
our $SIGMA   = chr(963); #"\xCF\x83"; #'σ';
our $SIGSQR  = chr(963).chr(178); #"\xCF\x83"."\xC2\xB2"; #'σ²';
our $PHI     = chr(966); #"\xCF\x86"; #'φ';


## -------- other special characters
our $COPYRIGHT = chr(169); #"\xC2\xA9"; #'©';
our $LAQUO     = chr(171); #"\xC2\xAB"; #'«';
our $RAQUO     = chr(187); #"\xC2\xBB"; #'»';
our $MDASH     = chr(8212); #"\xE2\x80\x94"; #'—';

sub emph {
  return $LAQUO . $_[0] . $RAQUO;
};

1;

=head1 NAME

Demeter::UI::Wx::SpecialCharacters - A library of special characters for use in Wx labels

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

This provides a library of special characters for use in labels on Wx widgets.

  use Demeter::UI::Wx::SpecialCharacters qw(:all);
  my $button = Wx::Button($parent, -1, "Plot $CHI(k)");

=head1 DESCRIPTION

This collects all the various special characters needed in Artemis and
other Wx-based GUIs into one convenient location.  Please note that
this exports B<variables> into your module's namespace.  This is a
against good practice, but is a huge convenience nonetheless.

The greek letters exported are

=over 4

=item C<$CHI>

lower case chi

=item C<$EPSILON>

lower case epsilon

=item C<$DELTA>

upper case delta

=item C<$SIGMA>

lower case sigma

=item C<$SIGSQR>

lower case sigma followed by a proper subscripted 2

=item C<$PHI>

lower case phi

=back

The other characters exported are

=over 4

=item C<$COPYRIGHT>

copyright symbol

=item C<$LABELS>

left guillemet

=item C<$RAQUO>

right guillemet

=back

The sets exported are

=over 4

=item C<:all>

As the name implies, all defined characters

=item C<:greek>

Just the greek letters

=back

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
