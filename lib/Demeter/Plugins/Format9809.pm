package Demeter::Plugins::Format9809;

use Moose;
use YAML;
use File::Basename;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => 'Format 9809');
has '+version'     => (default => 0.1);
has 'scaler'       => (is => 'rw', isa => 'Str', default => 'ORTEC');
has 'nelements'    => (is => 'rw', isa => 'Int', default => 3);
has 'facility'     => (is => 'rw', isa => 'Str', default => 'KEK-PF');
has 'detector'     => (is => 'rw', isa => 'Str', default => 'ssd');

use Demeter::Constants qw($PI);
use Const::Fast;
const my $HC      => 12398.52;	# slightly different than in D::C
#const my $HBARC   => 1973.27053324;
#const my $TWODONE => 6.2712;	# Si(111)
#const my $TWODTHR => 3.275;	# Si(311)

const my $INIFILE => 'format9809.demeter_conf';
has '+conffile'   => (default => File::Spec->catfile(dirname($INC{'Demeter.pm'}), 'Demeter', 'Plugins', $INIFILE));
Demeter -> co -> read_config(File::Spec->catfile(dirname($INC{'Demeter.pm'}), 'Demeter', 'Plugins', $INIFILE));

sub is {
  my ($self) = @_;
  open D, $self->file or $self->Croak("could not open " . $self->file . " as data (Photon Factory/SPring-8/SAGA-LS/AichiSR)\n");
  my $line = <D>;
  close D;
  return 1 if ($line =~ m{9809\s+(?:KEK-PF|SPring-8|SAGA-LS|AichiSR)\s+(?:(BL\d+)|(NW\d+)|(\d+\w+\d*))});
  return 0;
};

sub fix {
  my ($self) = @_;
  $self->detector( Demeter->co->default("format9809", "detector") );
  
  # Load Deadt.d
  my $deadt = YAML::LoadFile( File::Spec->catfile(dirname($INC{'Demeter.pm'}), 'Demeter', 'Plugins', 'Format9809.conf') );
  
  my $file = $self->file;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open my $D, $file or die "could not open $file as data (fix in Format9809)\n";
  open my $N, ">".$new or die "could not write to $new (fix in Format9809)\n";

  my $header    = 1; # Turn on header flag
  my $ddistance = 1; # Turn on ddistance flag
  my $is_mssd   = 0; # MSSD flag
  my $ndch      = 0; # Number of detector
  my @detector_id;
  my $header_array;
  my $sca_id    = 0;
  
  while (<$D>) {
    next if ($_ =~ m{\A\s*\z}); # Ignore text lines
    last if ($_ =~ m{});       # Exit from while loop
    chomp;
    if ($header and ($_ =~ m{\A\s+offset}i)) {
      my $this = $_;
      print $N '# ', $_, $/;
      print $N '# --------------------------------------------------', $/;
      print $N $header_array, $/;
      $header = 0; # Turn off header flag
    } elsif ($header and ($_ =~ m{9809\s+(KEK-PF|SPring-8|SAGA-LS|AichiSR)\s+(?:(BL\d+)|(NW\d+)|(\d+\w+\d*))})) {
      print $N '# ', $_, $/;
      $self->facility($1);
    } elsif ($header and ($_ =~ m{\A\s+mode}i)) {
      print $N '# ', $_, $/;
      my $this = $_;
      $this =~ s/Mode//g;
      $this =~ s/0//; # Remove first 0 for Angle(o)
      $this =~ s/0//; # Remove second 0 for Time
      $this =~ s/^\s+|\s+$//g;
      @detector_id = split(/\s+/, $this);
      $self->nelements(scalar(@detector_id));
      my $element_array = '';
      # my $sca_id = 0;
      my $icr_id = 0;
      my $trans_id = 0;
      my $dismiss = 0;
      # I0=1,I1=2,SCA=3,UNUSEDSCA=0,PZT=5,ICR=103,PREAMP=101,UNUSEDPREAMP=100
      foreach my $id (@detector_id) {
        if ($id eq "0") {
          if ($dismiss < 2) {
            $id = '';
            $dismiss = $dismiss + 1;
          } else {
            $sca_id = $sca_id + 1;
            $id = "DISABLED" . $sca_id;
          }
        } elsif ($id eq "1") {
          $id = "I0";
        } elsif ($id eq "2") {
          $trans_id = $trans_id + 1;
          $id = "I" . $trans_id;
        } elsif ($id eq "3") {
          $sca_id = $sca_id + 1;
          if ( $sca_id < 20 ) {
            $id = "S" . $sca_id;
          } else {
            $id = "CEY";
          }
        } elsif ($id eq "5") {
          $id = "PZT";
        } elsif ($id eq "103") {
          $icr_id = $icr_id + 1;
          $id = "ICR" . $icr_id;
        } elsif ($id =~ m{mode}i) {
          $id = '';
        } elsif ($id eq "105") {
          $id = "PZT";
        } elsif ($id eq "101") {
          $id = "RESET";
        } else {
          $id = "UNKNOWN";
        }
        $element_array = $element_array . " " . $id;
      }
      $header_array = '# energy_requested   energy_attained  time' . $element_array;
    } elsif ($header) {
      my $this = $_;
      if ($this =~ m{d=\s+(\d\.\d+)\s+A}i) {
        $ddistance = $1*2; # Extract D spacing value
      };
      if ($this =~ m{NDCH\s+=\s*(\d+)}i) {
        # $ndch = $1;
        # $self->nelements($1);
        if ($1 > 4) { $is_mssd = 1; };
      };
      print $N '# ', $_, $/;
    } else {
      if ($is_mssd) { 
        my @list = split(" ", $_);
        $list[0] = ($HC) / ($ddistance * sin($list[0] * $PI / 180)); # Convert configured crystal angle to energy
        $list[1] = ($HC) / ($ddistance * sin($list[1] * $PI / 180)); # Convert observed crystal angle to energy
        $list[2] = $list[2];                                         # Acquisition time
        foreach my $i (3 .. (3 + $self->nelements() - 1) ) {
          if ($self->facility eq 'AichiSR') {
            if ( $detector_id[-3+$i]  =~ m{I0}i ) {
              # I0 or disabled SCA
              $list[$i] = $list[$i]/$list[2];
            } elsif ( $detector_id[-3+$i]  =~ m{^S}i ) {
              my $shapingtime = $deadt->{shapingtime};
              my $preampdeadtime = 10.0 ** -6.0 * $deadt->{AichiSR}->{$self->detector}->{individual}->{preamp}[-3+$i];
              my $ampdeadtime = 10.0 ** -6.0 * $deadt->{AichiSR}->{$self->detector}->{individual}->{amp}->{$shapingtime}[-3+$i];
              # "Prof. Nomura equation"
              $list[$i] = ($list[$i]/$list[2]) * ( 1 + ($list[1+$sca_id+$i]/$list[2]) * $ampdeadtime ) / ( 1 - ($list[1+$sca_id+$i]/$list[2]) * $preampdeadtime );
              # "Prof. Uruga equation"
              # $list[$i] = ($list[$i]/$list[2]) / ( 1 - ($list[1+$sca_id+$i]/$list[2]) * ($ampdeadtime + $preampdeadtime) );
              # print $N '# ', $preampdeadtime . " " . $ampdeadtime, $/;
            }
          }
        };
        my $pattern = "  %9.3f  %9.3f  %6.2f" . "  %16.6f" x $self->nelements() . $/;
        printf $N $pattern, @list;
      } else {
        my @list = split(" ", $_);
        $list[0] = ($HC) / ($ddistance * sin($list[0] * $PI / 180)); # Convert configured crystal angle to energy
        $list[1] = ($HC) / ($ddistance * sin($list[1] * $PI / 180)); # Convert observed crystal angle to energy
        my $ndet = $#list-2;
        my $pattern = "  %9.3f  %9.3f  %6.3f" . "  %16.6f" x $ndet . $/;
        printf $N $pattern, @list;
      }
    };
  };
  close $N;
  close $D;
  $self->fixed($new);
  return $new;
};

sub suggest {
  my ($self, $which) = @_;
  $which ||= 'transmission';
  if ($self->nelements() > 4) {
    $which = 'MSSD';
  }
  if ($which eq 'transmission') {
    return (energy      => '$2',
            numerator   => '$4',
            denominator => '$5',
            ln          =>  1,);
  } elsif (($which eq 'MSSD') and ($self->facility eq 'KEK-PF')) {
    return (energy      => '$2',
            numerator   => '$4+$5+$6+$7+$8+$9+$10+$11+$12+$13+$14+$15+$16+$17+$18+$19+$20+$21+$22',
            denominator => '$23',
            ln          =>  0,);
  } elsif (($which eq 'MSSD') and ($self->facility eq 'SPring-8')) {
    return (energy      => '$2',
            numerator   => '$4+$5+$6+$7+$8+$9+$10+$11+$12+$13+$14+$15+$16+$17+$18+$19+$20+$21+$22',
            denominator => '$23',
            ln          =>  0,);
  } elsif (($which eq 'MSSD') and ($self->facility eq 'AichiSR')) {
    if ($self->nelements() > 15) {
      return (energy      => '$2',
              numerator   => '$4+$5+$6+$7+$8+$9+$10+$11+$12+$13+$14+$15+$16+$17+$18+$19+$20+$21+$22',
              denominator => '$23',
              ln          =>  0,);
    } else {
      return (energy      => '$2',
              numerator   => '$4+$5+$6+$7',
              denominator => '$8',
              ln          =>  0,);
    }
  } else {
    return ();
  };
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Plugin::Format9809 - filetype plugin for 9809 format (Photon Factory, SPring-8, SAGA-LS, AichiSR)

=head1 VERSION

This documentation refers to Demeter version 0.9.22.

=head1 SYNOPSIS

This plugin converts data recorded as a function of mono angle to data
as a function of energy.

=head1 METHODS

=over 4

=item C<is>

This file is identified by the string "KEK-PF", "SPring-8", "SAGA-LS",
and "AichiSR" followed by the beamline number in the first line of the file.

=item C<fix>

Convert the wavelength array to energy using the formula

   data.energy = 2 * pi * hbarc / 2D * sin(data.angle)

where C<hbarc=1973.27053324> is the the value in eV*angstrom units and
D is the Si(111) plane spacing.

=back

=head1 REVISIONS

=over 4

=item 0.1

Copy and modify PFBL12C.pm of Demeter varsion 0.9.10.

=back

=head1 AUTHOR

  Hiroyuki Asakura, L<http://orange.nusr.nagoya-u.ac.jp>
  http://orange.nusr.nagoya-u.ac.jp

=cut
