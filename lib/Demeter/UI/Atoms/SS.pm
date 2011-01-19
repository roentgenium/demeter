package Demeter::UI::Atoms::SS;

use strict;
use warnings;

use Wx qw( :everything );
use Wx::DND;
use base 'Wx::Panel';

use Wx::Event qw(EVT_CHOICE EVT_KEY_DOWN EVT_MENU EVT_TOOL_ENTER EVT_BUTTON
		 EVT_ENTER_WINDOW EVT_LEAVE_WINDOW EVT_RADIOBOX
		 EVT_LEFT_DOWN EVT_LIST_BEGIN_DRAG);

use List::MoreUtils qw(uniq);
use YAML::Tiny;

my @PosSize = (wxDefaultPosition, [60,-1]);

sub new {
  my ($class, $page, $parent) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{parent}    = $parent;
  $self->{statusbar} = $parent->{statusbar};
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );


  my $cb = Wx::Choicebook->new( $self, -1, wxDefaultPosition, wxDefaultSize, wxBK_TOP );
  $self->{book} = $cb;
  #my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize + 2;
  #($cb->GetChildren)[0]->SetFont( Wx::Font->new($size, wxDEFAULT, wxNORMAL, wxNORMAL, 0, "" ) );
  $vbox->Add($cb, 1, wxALL|wxGROW, 5);

  $self->{ss} = $self->_ss($parent);
  $cb  -> AddPage($self->{ss}, "Make a Single Scattering path of arbitrary length", 1);

  $self->{dlp_ss} = $self->_dlp_ss($parent);
  $cb  -> AddPage($self->{dlp_ss}, "Make a SS histogram from a DL_POLY history", 0);

  $self->{dlp_ncl} = $self->_dlp_ncl($parent);
  $cb  -> AddPage($self->{dlp_ncl}, "Make a nearly collinear histogram from a DL_POLY history", 0);

  $self -> SetSizerAndFit( $vbox );
  return $self;
};


sub _ss {
  my ($self, $parent) = @_;
  my $page = Wx::Panel->new($self->{book}, -1, wxDefaultPosition, wxDefaultSize);
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $page->SetSizerAndFit($vbox);


  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add( Wx::StaticText->new($page, -1, "Name: "), 0, wxALL, 7);
  $self->{ss_name} = Wx::TextCtrl->new($page, -1, q{});
  $hbox -> Add( $self->{ss_name}, 1, wxGROW|wxALL, 5);
  $vbox -> Add( $hbox, 0, wxGROW|wxLEFT|wxRIGHT, 20 );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add( Wx::StaticText->new($page, -1, "Distance: "), 0, wxALL, 7);
  $self->{ss_reff} = Wx::TextCtrl->new($page, -1, q{3.0});
  $hbox -> Add( $self->{ss_reff}, 0, wxALL, 5);
  $vbox -> Add( $hbox, 0, wxGROW|wxLEFT|wxRIGHT, 20 );

  $self->{ss_ipot} = Wx::RadioBox->new($page, -1, ' ipot of scatterer ', wxDefaultPosition, wxDefaultSize,
				       [q{     },q{     },q{     },q{     },q{     },q{     },q{     }], 7, wxRA_SPECIFY_COLS);
  $self->{ss_ipot}->Enable($_,0) foreach (0..6);
  EVT_RADIOBOX($self, $self->{ss_ipot}, \&set_name);

  $vbox -> Add( $self->{ss_ipot}, 0, wxLEFT|wxRIGHT, 25 );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add( $hbox, 0, wxGROW|wxALL, 20 );
  $self->{ss_drag} = Demeter::UI::Atoms::SS::SSDragSource->new($page, -1, wxDefaultPosition, wxDefaultSize, $parent);
  $hbox  -> Add( $self->{ss_drag}, 0, wxALL, 20);
  $self->{ss_drag}->SetCursor(Wx::Cursor->new(wxCURSOR_HAND));
  $self->{ss_drag}->SetFont( Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxNORMAL, 1, "" ) );
  $self->{ss_drag}->Enable(0);




#  $self->{toolbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_HORIZONTAL|wxTB_3DBUTTONS|wxTB_TEXT);
#  EVT_MENU( $self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolClick($toolbar, $event, $self)} );
#  $self->{toolbar} -> AddTool(2, "Plot SS path",  $self->icon("plot"), wxNullBitmap, wxITEM_NORMAL, q{}, $Demeter::UI::Atoms::Paths::hints{plot});
#  $self->{toolbar} -> AddSeparator;
#  $self->{toolbar} -> AddRadioTool(4, 'chi(k)',     $self->icon("chik"),    wxNullBitmap, q{}, $Demeter::UI::Atoms::Paths::hints{chik});
#  $self->{toolbar} -> AddRadioTool(5, '|chi(R)|',   $self->icon("chirmag"), wxNullBitmap, q{}, $Demeter::UI::Atoms::Paths::hints{chir_mag});
#  $self->{toolbar} -> AddRadioTool(6, 'Re[chi(R)]', $self->icon("chirre"),  wxNullBitmap, q{}, $Demeter::UI::Atoms::Paths::hints{chir_re});
#  $self->{toolbar} -> AddRadioTool(7, 'Im[chi(R)]', $self->icon("chirim"),  wxNullBitmap, q{}, $Demeter::UI::Atoms::Paths::hints{chir_im});
#  $self->{toolbar} -> ToggleTool(5, 1);

#  EVT_TOOL_ENTER( $self, $self->{toolbar}, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'toolbar')} );
#  $self->{toolbar} -> Realize;
#  $vbox -> Add($self->{toolbar}, 0, wxALL, 20);
  return $page;
};


sub _dlp_ss {
  my ($self, $parent) = @_;
  my $page = Wx::Panel->new($self->{book}, -1, wxDefaultPosition, wxDefaultSize);
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $page->SetSizerAndFit($vbox);

  $self->{dlp_ss_dlfile} = Wx::FilePickerCtrl->new( $page, -1, "", "Choose a HISTORY File", "HISTORY files|HISTORY|All files|*",
						    wxDefaultPosition, wxDefaultSize,
						    wxFLP_DEFAULT_STYLE|wxFLP_USE_TEXTCTRL|wxFLP_CHANGE_DIR|wxFLP_FILE_MUST_EXIST );
  $vbox -> Add($self->{dlp_ss_dlfile}, 0, wxGROW|wxLEFT|wxRIGHT, 25);


  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);
  $self->{dlp_ss_ipot} = Wx::RadioBox->new($page, -1, ' ipot of scatterer ', wxDefaultPosition, wxDefaultSize,
				       [q{     },q{     },q{     },q{     },q{     },q{     },q{     }], 7, wxRA_SPECIFY_COLS);
  $self->{dlp_ss_ipot}->Enable($_,0) foreach (0..6);
  EVT_RADIOBOX($self, $self->{dlp_ss_ipot}, \&set_name);

  $vbox -> Add( $self->{dlp_ss_ipot}, 0, wxLEFT|wxRIGHT, 25 );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);
  $self -> {dlp_ss_dlrminlab} = Wx::StaticText -> new($page, -1, "Rmin");
  $self -> {dlp_ss_dlrmin}    = Wx::TextCtrl   -> new($page, -1, 1.0, @PosSize,);
  $hbox -> Add($self->{dlp_ss_dlrminlab}, 0, wxGROW|wxALL|wxALIGN_CENTRE, 5);
  $hbox -> Add($self->{dlp_ss_dlrmin},    0, wxGROW|wxALL|wxALIGN_CENTRE, 5);

  $self -> {dlp_ss_dlrmaxlab} = Wx::StaticText -> new($page, -1, "Rmax");
  $self -> {dlp_ss_dlrmax}    = Wx::TextCtrl   -> new($page, -1, 3.5, @PosSize,);
  $hbox -> Add($self->{dlp_ss_dlrmaxlab}, 0, wxGROW|wxALL|wxALIGN_CENTRE, 5);
  $hbox -> Add($self->{dlp_ss_dlrmax},    0, wxGROW|wxALL|wxALIGN_CENTRE, 5);

  $self -> {dlp_ss_dlbinlab} = Wx::StaticText -> new($page, -1, "Bin size");
  $self -> {dlp_ss_dlbin}    = Wx::TextCtrl   -> new($page, -1, 0.005, @PosSize,);
  $hbox -> Add($self->{dlp_ss_dlbinlab},  0, wxGROW|wxALL|wxALIGN_CENTRE, 5);
  $hbox -> Add($self->{dlp_ss_dlbin},     0, wxGROW|wxALL|wxALIGN_CENTRE, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  $self -> {dlp_ss_dlplot} = Wx::Button -> new($page, -1, "Plot RDF");
  $hbox -> Add($self->{dlp_ss_dlplot},    1, wxGROW|wxALL, 5);
  EVT_BUTTON($self, $self->{dlp_ss_dlplot}, sub{ dlplot(@_) });

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add( $hbox, 0, wxGROW|wxALL, 20 );
  $self->{dlp_ss_drag} = Demeter::UI::Atoms::SS::DLPSSDragSource->new($page, -1, wxDefaultPosition, wxDefaultSize, $parent);
  $hbox  -> Add( $self->{dlp_ss_drag}, 0, wxALL, 20);
  $self->{dlp_ss_drag}->SetCursor(Wx::Cursor->new(wxCURSOR_HAND));
  $self->{dlp_ss_drag}->SetFont( Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxNORMAL, 1, "" ) );
  $self->{dlp_ss_drag}->Enable(0);


  $self->{dlp_ss_yaml} = ();
  my $persist = File::Spec->catfile(Demeter->dot_folder, 'demeter.dlpoly');
  if (-e $persist) {
    my $yaml = YAML::Tiny::LoadFile($persist);
    $self->{dlp_ss_dlfile} -> SetPath ($yaml->{file});
    $self->{dlp_ss_dlrmin} -> SetValue($yaml->{rmin});
    $self->{dlp_ss_dlrmax} -> SetValue($yaml->{rmax});
    $self->{dlp_ss_dlbin}  -> SetValue($yaml->{bin} );
    $self->{dlp_ss_yaml}    = $yaml;
  };

  return $page;
};

sub _dlp_ncl {
  my ($self, $parent) = @_;
  my $page = Wx::Panel->new($self->{book}, -1, wxDefaultPosition, wxDefaultSize);
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $page->SetSizerAndFit($vbox);

  $self->{dlp_ncl_dlfile} = Wx::FilePickerCtrl->new( $page, -1, "", "Choose a HISTORY File", "HISTORY files|HISTORY|All files|*",
						     wxDefaultPosition, wxDefaultSize,
						     wxFLP_DEFAULT_STYLE|wxFLP_USE_TEXTCTRL|wxFLP_CHANGE_DIR|wxFLP_FILE_MUST_EXIST );
  $vbox -> Add($self->{dlp_ncl_dlfile}, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);
  $self -> {dlp_ncl_rbinlab} = Wx::StaticText -> new($page, -1, "Radial bin size");
  $self -> {dlp_ncl_rbin}    = Wx::TextCtrl   -> new($page, -1, 1.0, @PosSize,);
  $self -> {dlp_ncl_betabinlab} = Wx::StaticText -> new($page, -1, "Angular bin size");
  $self -> {dlp_ncl_betabin}    = Wx::TextCtrl   -> new($page, -1, 1.0, @PosSize,);
  $hbox -> Add($self->{dlp_ncl_rbinlab},    0, wxGROW|wxALL|wxALIGN_CENTRE, 5);
  $hbox -> Add($self->{dlp_ncl_rbin},       0, wxGROW|wxALL|wxALIGN_CENTRE, 5);
  $hbox -> Add($self->{dlp_ncl_betabinlab}, 0, wxGROW|wxALL|wxALIGN_CENTRE, 5);
  $hbox -> Add($self->{dlp_ncl_betabin},    0, wxGROW|wxALL|wxALIGN_CENTRE, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 0);
  $self->{dlp_ncl_ipot1} = Wx::RadioBox->new($page, -1, ' ipot of near neighbor scatterer ', wxDefaultPosition, wxDefaultSize,
					     [q{     },q{     },q{     },q{     },q{     },q{     },q{     }], 7, wxRA_SPECIFY_COLS);
  $self->{dlp_ncl_ipot1}->Enable($_,0) foreach (0..6);
  EVT_RADIOBOX($self, $self->{dlp_ncl_ipot1}, \&set_name);
  $hbox -> Add( $self->{dlp_ncl_ipot1}, 0, wxLEFT|wxRIGHT, 25 );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);
  $self -> {dlp_ncl_dlnearlab} = Wx::StaticText -> new($page, -1, "R range of near neighbor");
  $self -> {dlp_ncl_dlr1}    = Wx::TextCtrl   -> new($page, -1, 1.0, @PosSize,);
  $self -> {dlp_ncl_dlr2}    = Wx::TextCtrl   -> new($page, -1, 1.0, @PosSize,);
  $hbox -> Add($self->{dlp_ncl_dlnearlab}, 0, wxGROW|wxALL|wxALIGN_CENTRE, 5);
  $hbox -> Add($self->{dlp_ncl_dlr1},      0, wxGROW|wxALL|wxALIGN_CENTRE, 5);
  $hbox -> Add(Wx::StaticText -> new($page, -1, " to "), 0, wxGROW|wxALL|wxALIGN_CENTRE, 5);
  $hbox -> Add($self->{dlp_ncl_dlr2},      0, wxGROW|wxALL|wxALIGN_CENTRE, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 0);
  $self->{dlp_ncl_ipot2} = Wx::RadioBox->new($page, -1, ' ipot of distant scatterer ', wxDefaultPosition, wxDefaultSize,
					     [q{     },q{     },q{     },q{     },q{     },q{     },q{     }], 7, wxRA_SPECIFY_COLS);
  $self->{dlp_ncl_ipot2}->Enable($_,0) foreach (0..6);
  EVT_RADIOBOX($self, $self->{dlp_ncl_ipot2}, \&set_name);
  $hbox -> Add( $self->{dlp_ncl_ipot2}, 0, wxLEFT|wxRIGHT, 25 );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);
  $self -> {dlp_ncl_dldistlab} = Wx::StaticText -> new($page, -1, "R range of distant neighbor");
  $self -> {dlp_ncl_dlr3}    = Wx::TextCtrl   -> new($page, -1, 1.0, @PosSize,);
  $self -> {dlp_ncl_dlr4}    = Wx::TextCtrl   -> new($page, -1, 1.0, @PosSize,);
  $hbox -> Add($self->{dlp_ncl_dldistlab}, 0, wxGROW|wxALL|wxALIGN_CENTRE, 5);
  $hbox -> Add($self->{dlp_ncl_dlr3},      0, wxGROW|wxALL|wxALIGN_CENTRE, 5);
  $hbox -> Add(Wx::StaticText -> new($page, -1, " to "), 0, wxGROW|wxALL|wxALIGN_CENTRE, 5);
  $hbox -> Add($self->{dlp_ncl_dlr4},      0, wxGROW|wxALL|wxALIGN_CENTRE, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add( $hbox, 0, wxGROW|wxALL, 20 );
  $self->{dlp_ncl_drag} = Demeter::UI::Atoms::SS::DLPNCLDragSource->new($page, -1, wxDefaultPosition, wxDefaultSize, $parent);
  $hbox  -> Add( $self->{dlp_ncl_drag}, 0, wxALL, 20);
  $self->{dlp_ncl_drag}->SetCursor(Wx::Cursor->new(wxCURSOR_HAND));
  $self->{dlp_ncl_drag}->SetFont( Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxNORMAL, 1, "" ) );
  $self->{dlp_ncl_drag}->Enable(0);


  $vbox -> Add($self->{toolbar}, 0, wxALL, 20);
  return $page;
};

sub dlplot {
  my ($this, $event) = @_;
  my $file = $this->{dlp_ss_dlfile}->GetTextCtrl->GetValue;
  my $rmin = $this->{dlp_ss_dlrmin}->GetValue;
  my $rmax = $this->{dlp_ss_dlrmax}->GetValue;
  my $bin  = $this->{dlp_ss_dlbin}->GetValue;
  $this->{yaml}->{file} = $file;
  $this->{yaml}->{rmin} = $rmin;
  $this->{yaml}->{rmax} = $rmax;
  $this->{yaml}->{bin}  = $bin;

  if ((not $file) or (not -e $file) or (not -r $file)) {
    $this->GetParent->status("You did not specify a file or your file cannot be read.");
    return;
  };

  my $dlp = Demeter::ScatteringPath::Histogram::DL_POLY->new(rmin=>$rmin, rmax=>$rmax, bin=>$bin, ss=>1, ncl=>0);
  my $persist = File::Spec->catfile($dlp->dot_folder, 'demeter.dlpoly');
  YAML::Tiny::DumpFile($persist, $this->{yaml});


  $this->{DLPOLY} = $dlp;
  $dlp->sentinal(sub{$this->dlpoly_sentinal});

  my $busy = Wx::BusyCursor->new();
  my $start = DateTime->now( time_zone => 'floating' );
  $dlp->file($file);
  $dlp->rebin;
  my $finish = DateTime->now( time_zone => 'floating' );
  my $dur = $finish->subtract_datetime($start);
  my $finishtext = sprintf("Plotting histogram from %d timesteps (%d minutes, %d seconds)", $dlp->nsteps, $dur->minutes, $dur->seconds);
  $this->GetParent->status($finishtext);
  $dlp->plot;
  undef $busy;
};

sub dlpoly_sentinal {
  my ($this) = @_;
  my $text = $this->{DLPOLY}->timestep_count . " of " . $this->{DLPOLY}->{nsteps} . " timesteps";
  #print $text, $/;
  #$this->GetParent->status($text, 'wait|nobuffer') if not $this->{DLPOLY}->timestep_count % 10;
};


sub icon {
  my ($self, $which) = @_;
  my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', "$which.png");
  return wxNullBitmap if (not -e $icon);
  return Wx::Bitmap->new($icon, wxBITMAP_TYPE_ANY)
};

sub set_name {
  my ($self, $event) = @_;

  ## need to make a regular expression out of all elements in the potentials list ...
  my @pots = @{ $self->{parent}->{Feff}->{feffobject}->potentials };
  shift @pots;
  my @all_elems = uniq( map { $_ -> [2] } @pots );
  my $re = join("|", @all_elems);

  ## ... so I can reset the name if it has been left to its default.
  if ($self->{name}->GetValue =~ m{\A\s*$re\s+SS\z}) {
    my $label = $self->{ipot}->GetStringSelection;
    my $elem  = (split(/: /, $label))[1];
    $self->{name}->SetValue($elem.' SS');
  };
};

sub OnToolEnter {
  my ($self, $event, $which) = @_;
  if ( $event->GetSelection > -1 ) {
    $self->{statusbar}->SetStatusText($self->{$which}->GetToolLongHelp($event->GetSelection));
  } else {
    $self->{statusbar}->SetStatusText(q{});
  };
};

sub OnToolClick {
  my ($toolbar, $event, $self) = @_;
  ##                 Vv------order of toolbar on the screen-----vV
  my @callbacks = qw(plot noop set_plot set_plot set_plot set_plot);
  my $closure = $callbacks[$toolbar->GetToolPos($event->GetId)];
  $self->$closure($event->GetId);
};

sub noop {
  return 1;
};

sub set_plot {
  my ($self, $id) = @_;
  ## set plotting space
  my $space = ($id == 5) ? 'k' : 'r';
  $self->{parent}->{Feff}->{feffobject}->po->space($space);
  # set part of R space plot
  my %pl = (5 => q{}, 6 => 'm', 7 => 'r', 8 => 'i');
  $self->{parent}->{Feff}->{feffobject}->po->r_pl($pl{$id}) if $pl{$id};
  # sensible status bar message
  my %as = (5 => 'chi(k)', 6 => 'the magnitude of chi(R)', 7 => 'the real part of chi(R)', 8 => 'the imaginary part of chi(R)');
  $self->{statusbar}->SetStatusText("Plotting as $as{$id}");
  return $self;
};

sub plot {
  my ($self) = @_;
  my $save = $Demeter::UI::Atoms::demeter->po->title;

  ## make SSPath

  ## make plot

  ## destroy SSPath (since it will be created when dnd-ed

  $Demeter::UI::Atoms::demeter->po->title($save);
};



package Demeter::UI::Atoms::SS::SSDragSource;

use Demeter;

use Wx qw( :everything );
use base qw(Wx::Window);
use Wx::Event qw(EVT_LEFT_DOWN EVT_PAINT);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new( @_[0..2], [300,30] );
  my $parent = $_[4];

  EVT_PAINT( $this, \&OnPaint );
  EVT_LEFT_DOWN( $this, sub{OnDrag(@_, $parent)} );

  return $this;
};

sub OnPaint {
  my( $this, $event ) = @_;
  my $dc = Wx::PaintDC->new( $this );

  $dc->DrawText( "Drag single scattering path from here ", 2, 2 );
};

sub OnDrag {
  my( $this, $event, $parent ) = @_;

  my $dragdata = ['SSPath',  	                         # id
		  $parent->{Feff}->{feffobject}->group,  # feff object group
		  $parent->{SS}->{ss_name}->GetValue,       # name
		  $parent->{SS}->{ss_reff}->GetValue,       # reff
		  $parent->{SS}->{ss_ipot}->GetSelection+1, # ipot
		 ];
  my $data = Demeter::UI::Artemis::DND::PathDrag->new($dragdata);
  my $source = Wx::DropSource->new( $this );
  $source->SetData( $data );
  $source->DoDragDrop(1);
};


package Demeter::UI::Atoms::SS::DLPSSDragSource;

use Demeter;

use Wx qw( :everything );
use base qw(Wx::Window);
use Wx::Event qw(EVT_LEFT_DOWN EVT_PAINT);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new( @_[0..2], [300,30] );
  my $parent = $_[4];

  EVT_PAINT( $this, \&OnPaint );
  EVT_LEFT_DOWN( $this, sub{OnDrag(@_, $parent)} );

  return $this;
};

sub OnPaint {
  my( $this, $event ) = @_;
  my $dc = Wx::PaintDC->new( $this );

  $dc->DrawText( "Drag DL_POLY histogram SS path from here ", 2, 2 );
};

sub OnDrag {
  my( $this, $event, $parent ) = @_;

  my $dragdata = ['DLPSS',						  # id
		  $parent->{Feff}->{feffobject}->group,			  # feff object group
		  $parent->{SS}->{dlp_ss_dlfile}->GetTextCtrl->GetValue,  # HISTORY file
		  $parent->{SS}->{dlp_ss_dlrmin}->GetValue,		  # rmin
		  $parent->{SS}->{dlp_ss_dlrmax}->GetValue,		  # rmax
		  $parent->{SS}->{dlp_ss_dlbin} ->GetValue,		  # bin size
		  $parent->{SS}->{dlp_ss_ipot}->GetSelection+1,		  # ipot
		 ];
  my $data = Demeter::UI::Artemis::DND::PathDrag->new($dragdata);
  my $source = Wx::DropSource->new( $this );
  $source->SetData( $data );
  $source->DoDragDrop(1);
};


package Demeter::UI::Atoms::SS::DLPNCLDragSource;

use Demeter;

use Wx qw( :everything );
use base qw(Wx::Window);
use Wx::Event qw(EVT_LEFT_DOWN EVT_PAINT);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new( @_[0..2], [300,30] );
  my $parent = $_[4];

  EVT_PAINT( $this, \&OnPaint );
  EVT_LEFT_DOWN( $this, sub{OnDrag(@_, $parent)} );

  return $this;
};

sub OnPaint {
  my( $this, $event ) = @_;
  my $dc = Wx::PaintDC->new( $this );

  $dc->DrawText( "Drag DL_POLY histogram nearly collinear path from here ", 2, 2 );
};

sub OnDrag {
  my( $this, $event, $parent ) = @_;

  my $dragdata = ['DLPNCL',						      # id
		  $parent->{Feff}->{feffobject}    -> group,		      # feff object group
		  $parent->{SS}->{dlp_ncl_dlfile}  -> GetTextCtrl->GetValue,  # HISTORY file
		  $parent->{SS}->{dlp_ncl_dlr1}    -> GetValue,		      # r ranges
		  $parent->{SS}->{dlp_ncl_dlr2}    -> GetValue,		      #
		  $parent->{SS}->{dlp_ncl_dlr3}    -> GetValue,		      #
		  $parent->{SS}->{dlp_ncl_dlr4}    -> GetValue,		      #
		  $parent->{SS}->{dlp_ncl_rbin}    -> GetValue,		      # bin size
		  $parent->{SS}->{dlp_ncl_betabin} -> GetValue,		      # bin size
		  $parent->{SS}->{dlp_ncl_ipot1}   -> GetSelection+1,	      # ipot
		  $parent->{SS}->{dlp_ncl_ipot2}   -> GetSelection+1,	      # ipot
		 ];
  my $data = Demeter::UI::Artemis::DND::PathDrag->new($dragdata);
  my $source = Wx::DropSource->new( $this );
  $source->SetData( $data );
  $source->DoDragDrop(1);
};



1;

=head1 NAME

Demeter::UI::Atoms::SS - Create SSPath objects in Atoms

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 DESCRIPTION

This class is used to populate the SS tab in the Wx version of Atoms
as a component of Artemis.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
