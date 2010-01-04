package  Demeter::UI::Artemis::Plot::VPaths;


=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Wx qw( :everything );
use Wx::Help;
use Wx::Event qw(EVT_BUTTON EVT_RIGHT_DOWN EVT_MENU);

use base qw(Wx::Panel);

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize);

  my $box  = Wx::BoxSizer->new( wxVERTICAL );
  my $label = Wx::StaticText->new($this, -1, 'Virtual Paths');
  $label -> SetFont(Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ));
  $box -> Add($label, 0, wxALIGN_CENTER_HORIZONTAL);
  $this->{vpathlist} = Wx::ListBox->new($this, -1, wxDefaultPosition, [-1,200], [ ], wxLB_SINGLE);
  $box -> Add($this->{vpathlist}, 1, wxGROW|wxALL, 5);
  EVT_RIGHT_DOWN($this->{vpathlist}, sub{OnRightDown(@_)});
  EVT_MENU($this->{vpathlist}, -1, sub{ $this->OnMenu(@_)    });


  $this -> SetSizer($box);
  return $this;
};

sub add_vpath {
  my ($self, @list) = @_;

  my $ted = Wx::TextEntryDialog->new( $self, "Enter a name for this virtual path", "Enter a VPath name", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
  if ($ted->ShowModal == wxID_CANCEL) {
    $Demeter::UI::Artemis::frames{main}->{statusbar}->SetStatusText("VPath creation cancelled.");
    return;
  };
  my $name = $ted->GetValue;
  $self->add_named_vpath($name, @list);
};

sub add_named_vpath {
  my ($self, $name, @list) = @_;

  my $vpath = Demeter::VPath->new(name => $name);
  $vpath -> include(@list);
  my $help = join(", ", map { $_->label } @list);

  $self->{vpathlist}->Append($name);
  my $this = $self->{vpathlist}->GetCount-1;
  $self->{vpathlist}->SetClientData($this, $vpath);
  $self->{vpathlist}->Select($this);
  $self->transfer($this);

  $Demeter::UI::Artemis::frames{Plot}->{notebook}->SetSelection(3);
  return $vpath;
};

use Readonly;
Readonly my $VPATH_TRANSFER => Wx::NewId();
Readonly my $VPATH_DESCRIBE => Wx::NewId();
Readonly my $VPATH_DISCARD  => Wx::NewId();

sub OnRightDown {
  my ($self, $event) = @_;
  my $sel  = $self->GetSelection;
  return if ($sel == wxNOT_FOUND);
  my $name = sprintf("\"%s\"", $self->GetString($sel));
  my $menu = Wx::Menu->new(q{});
  $menu->Append($VPATH_TRANSFER, "Transfer $name to plotting list");
  $menu->Append($VPATH_DESCRIBE, "Show contents of $name");
  $menu->AppendSeparator;
  $menu->Append($VPATH_DISCARD,  "Discard $name");
  $self->PopupMenu($menu, $event->GetPosition);
  $event->Skip;
};

sub OnMenu {
  my ($self, $listbox, $event) = @_;
  my $id  = $event->GetId;
  my $sel = $self->{vpathlist}->GetSelection;
 SWITCH: {

    ($id == $VPATH_TRANSFER) and do {
      $self->transfer($sel);
      last SWITCH;
    };

    ($id == $VPATH_DESCRIBE) and do {
      my $vpath = $listbox->GetClientData($sel);
      my $text = "\"" . $vpath->name . "\" contains: " . join(", ", map {$_->label} @{$vpath->paths});
      $Demeter::UI::Artemis::frames{main}->{statusbar}->SetStatusText($text);
      last SWITCH;
    };

    ($id == $VPATH_DISCARD) and do {
      my $vpath = $listbox->GetClientData($sel);
      foreach my $i (0 .. $Demeter::UI::Artemis::frames{Plot}->{plotlist}->GetCount-1) {
	if ($Demeter::UI::Artemis::frames{Plot}->{plotlist}->GetClientData($i)->group eq $vpath->group) {
	  my $obj = $Demeter::UI::Artemis::frames{Plot}->{plotlist}->GetClientData($i);
	  $Demeter::UI::Artemis::frames{Plot}->{plotlist}->Delete($i);
	  $obj -> DESTROY;
	  last;
	};
      };
      $listbox->Delete($sel);
      my $text = "Discarded \"" . $vpath->name . "\".";
      $Demeter::UI::Artemis::frames{main}->{statusbar}->SetStatusText($text);
      last SWITCH;
    };
  };
};

sub transfer {
  my ($self, $selection) = @_;
  my $vpath     = $self->{vpathlist}->GetClientData($selection);
  my $plotlist  = $Demeter::UI::Artemis::frames{Plot}->{plotlist};
  my $name      = $vpath->name;
  my $found     = 0;
  my $thisgroup = $vpath->group;
  foreach my $i (0 .. $plotlist->GetCount - 1) {
    if ($thisgroup eq $plotlist->GetClientData($i)->group) {
      $found = 1;
      last;
    };
  };
  if ($found) {
    $Demeter::UI::Artemis::frames{main}->{statusbar} -> SetStatusText("\"$name\" is already in the plotting list.");
    return;
  };
  $plotlist->Append("VPath: $name");
  my $i = $plotlist->GetCount - 1;
  $plotlist->SetClientData($i, $vpath);
  $plotlist->Check($i,1);
  $Demeter::UI::Artemis::frames{main}->{statusbar} -> SetStatusText("Transfered VPath \"$name\" to the plotting list.");
};

1;
