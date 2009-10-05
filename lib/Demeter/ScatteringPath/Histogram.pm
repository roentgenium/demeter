package Demeter::ScatteringPath::Histogram;
use Moose::Role;

use Carp;
use List::Util qw(sum);
use Scalar::Util qw(looks_like_number);
use Readonly;
Readonly my $EPSILON  => 0.00001;

sub make_histogram {
  my ($self, $rx, $ry, $s02, $scale, $common) = @_;
  my @paths = ();

  my $total = (looks_like_number($ry->[0])) ? sum(@$ry) : 1; # not quite right...
  #print $total, $/;
  my $rnot = $self->fuzzy;
  foreach my $i (0 .. $#{$rx}) {
    my $deltar = $rx->[$i] - $rnot;
    my $amp = $ry->[$i];
    if (looks_like_number($amp)) {
      $amp = sprintf("%.6f", $ry->[$i] / $total);
      next if ($amp < $self->co->default(qw(histogram epsilon)));
    };
    $deltar = ($scale) ? sprintf("%s*reff + %.5f*(1+%s)", $scale, $deltar, $scale) : sprintf("%.5f", $deltar);
    my $this = Demeter::Path->new(sp     => $self,
				  delr   => $deltar,
				  degen  => 1,
				  n      => 1,
				  s02    => $s02 . ' * ' . $amp,
				  parent => $self->feff,
				  @$common,
				 );
    $this -> make_name;
    (my $oldname = $this->name) =~ s{\s*\z}{};
    $this -> name($oldname . '@ ' . sprintf("%.3f",$rx->[$i]));
    $this -> update_path(1);
    push @paths, $this;
  };

  return \@paths;
};

sub histogram_from_file {
  my ($self, $fname, $xcol, $ycol, $rmin, $rmax) = @_;
  $xcol ||= 1;
  $ycol ||= 2;
  $rmin ||= 0;
  $rmax ||= 100;
  $xcol  -= 1;
  $ycol  -= 1;
  my (@x, @y);
  carp("$fname could not be imported as a histogram file"), return (\@x, \@y) if (not -e $fname);
  open(my $H, $fname);
  foreach my $line (<$H>) {
    chomp $line;
    next if ($line =~ m{\A\s*\z});
    next if ($line =~ m{\A[\#\*\%;]});
    my @list = split(" ", $line);
    next if ($list[$ycol] < $EPSILON);
    next if ($list[$xcol] < $rmin);
    next if ($list[$xcol] > $rmax);
    push @x, $list[$xcol];
    push @y, $list[$ycol];
  };
  close $H;

  return \@x, \@y;
};

sub histogram_from_function {
  my ($self, $string, $rmin, $rmax) = @_;
  my (@x, @y);
  ## use string to generate arrays in Ifeffit
  return \@x, \@y;
};

sub histogram_gamma {
  my ($self, $rmin, $rmax, $grid) = @_;
  my (@x, @y, @z);
  my $r = $rmin;
  while ($r <= $rmax+$EPSILON) {
    push @x, $r;
    my $term = sprintf("t%d",int($r*10000));
    push @y, "max(0, cn_gamma * prefactor * ((p_gamma+$term)**(p_gamma-1)) * exp(-p_gamma-$term))";
    push @z, Demeter::GDS->new(gds=>'def', name=>$term, mathexp=>"2 * ($r - reff + dr_gamma) / (sigma_gamma*beta_gamma)");
    $r += $grid;
  };
  ## use string to generate arrays in Ifeffit
  return \@x, \@y, \@z;
};

sub make_gamma_histogram {
  my ($self, $rx, $ry, $rz, $common) = @_;

  my @gds = (Demeter::GDS->new(gds => 'guess', name => 'cn_gamma',    mathexp => '1'    ),
	     Demeter::GDS->new(gds => 'guess', name => 'ss_gamma',    mathexp => '0.009'),
	     Demeter::GDS->new(gds => 'guess', name => 'dr_gamma',    mathexp => '0'),
	     Demeter::GDS->new(gds => 'guess', name => 'c3_gamma',    mathexp => '0.001'),

	     Demeter::GDS->new(gds => 'def',   name => 'sigma_gamma', mathexp => 'sqrt(max(0,ss_gamma))'    ),
	     Demeter::GDS->new(gds => 'def',   name => 'beta_gamma',  mathexp => 'c3_gamma / sigma_gamma**3' ),
	     Demeter::GDS->new(gds => 'def',   name => 'p_gamma',     mathexp => '4 / beta_gamma**2' ),
	     Demeter::GDS->new(gds => 'def',   name => 'prefactor',   mathexp => '2 / (sigma_gamma * abs(beta_gamma) * gamma(p_gamma))' ),
	    );

  my @paths = ();
  my $rnot = $self->fuzzy;
  foreach my $i (0 .. $#{$rx}) {
    my $deltar = sprintf("%.4f + dr_gamma", $rx->[$i] - $rnot);
    my $this = Demeter::Path->new(sp     => $self,
				  delr   => $deltar,
				  s02    => $ry->[$i],
				  sigma2 => 0,
				  n      => 1,
				  parent => $self->feff,
				  @$common,
				 );
    $this -> make_name;
    (my $oldname = $this->name) =~ s{\s*\z}{};
    $this -> name($oldname . '@ ' . sprintf("%.4f",$rx->[$i]));
    $this -> update_path(1);
    push @paths, $this;
    push @gds, $rz->[$i];
  };

  return \@paths, \@gds;
};


1;

=head1 NAME

Demeter::ScatteringPath::Histogram - Arbitrary distribution functions

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

  my $feff = Demeter::Feff->new(yaml=>'some_feff.yaml');
  my @list_of_paths = @{ $feff->pathlist };
  my $firstshell = $list_of_paths[0];
  my ($rx, $ry) = $firstshell->histogram_from_file('RDFDAT20K', 1, 2, 2.5, 3.0);
  my @common = (s02 => 'amp', sigma2 => 'sigsqr', e0 => 'enot', data=>$data);
  my @paths = $firstshell -> make_histogram($rx, $ry, \@common);

=head1 DESCRIPTION

This role of the ScatteringPath object provides tools for generating
and parameterizing arbitrary distribution functions.

=head1 METHODS

=head2 Histogram from a file

=over 4

=item C<histogram_from_file>

Read data from a text file to define the distribution function.
Returns array references containing the x- and y-axis data.

  ($ref_r, $ref_y) = histogram_from_file($filename, $xcol, $ycol, $rmin, $rmax);

The arguments are the filename, the column numbers (counting from 1)
containing the R-grid and the amplitudes of the distributions, and the
minimum and maximum r-values to read from the file.

=item C<make_histogram>

Given the array references from C<histogram_from_file> or
C<histogram_gamma>, return a reference to a list of Path objects
defining the histogram.

  $ref_paths = $firstshell -> make_histogram($rx, $ry, $scale, \@common);

The caller is the ScatteringPath object used as the Feff calculation
for each bin in the histogram.  The first two arguments are the array
references.  C<@rx> must be a referecne to an array of numbers -- the
x-axis values.  C<@ry> may be a reference to an array of numbers or
strings.  If numbers, they are taken as the bin poulations.  If
strings, they are taken to be math expressions for computing the bin
populations.

The third argument is the name of a parameter that will be
used as an isotropic scaling factor for the dletaR parameter.  The
remaining arguments will be passed to each resulting Path object.

=back

=head2 Histogram from a Gamm-like distribution

=over 4

=item C<histogram_gamma>

Define a gamma-like dsitribution function.

  my ($rx, $ry, $rz) = $fspath -> sp -> histogram_gamma(1.8, 3.0, 0.03);

The return values are array references.  The first is to the grid in R
space defined by the parameters of the method.  The second is a list
of text strings which will be to define the C<s02> parameters of each
bin.  The third is a list of GDS objects conatining additional def and
guess parameters required as part of the fitting model.

=item C<make_gamma_histogram>

Generate Path and GDS objects required to do the gamma-like fit using
a histogram.  The first three arguments of the method are the return
values of C<histogram_gamma>, the last is an array reference which
will be passed as the attributes of each Path object generated.

  my ($paths, $gamma_gds) = $fspath -> sp -> make_gamma_histogram($rx, $ry, $rz, $common);

To finish off the fit, you would do something like this:

  my $e0  = Demeter::GDS->new(gds=>'guess', name=>'enot',   mathexp=>0);
  my $fit = Demeter::Fit->new(gds=>[$e0, @$gamma_gds], data=>[$data], paths=>$paths);
  $fit->fit;

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration
system.  The plot and ornaments configuration groups control the
attributes of the Plot object.

=head1 DEPENDENCIES


=head1 BUGS AND LIMITATIONS

=over 4

=item *

Fits using the Gamma-like distribution are not very stable...

=item *

Need to implement user-defined distribution, although I don't have a
clear idea how to do so...

=back

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
