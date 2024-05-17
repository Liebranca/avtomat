#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M SYSMEM
# Special purpose buffers ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::sysmem;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Type;
  use Warnme;

  use Arstd::Bytes;
  use Arstd::IO;

  use parent 'A9M::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # name of root block
  ROOTID => 'SYSMEM',


  # name of basic unit of measuring
  size_k => 'qword',

  # ^derived values
  size_t => sub {typefet $_[0]->size_k()},
  size   => sub {sizeof  $_[0]->size_k()},


  # number of units used
  cnt    => 0x10,
  total  => sub {$_[0]->cnt * $_[0]->size},

  # ^masks for encoding units
  cnt_bs => sub {bitsize $_[0]->cnt()-1},
  cnt_bm => sub {bitmask $_[0]->cnt()-1},

};

# ---   *   ---   *   ---
# spawn block

sub mkroot($self) {

  return $self->warn_renit
  if defined $self->{mem};

  # get ctx
  my $mc     = $self->getmc();
  my $memcls = $mc->{bk}->{mem};

  # make container
  my $mem=$memcls->mkroot(

    label => $self->ROOTID,
    size  => $self->total,

    mccls => $self->{mccls},
    mcid  => $self->{mcid},

  );


  # set attrs and give
  $self->{mem}     = $mem;
  $self->{almask}  = 0x00;
  $self->{alhist}  = [];
  $self->{memhist} = [];

  return;

};

# ---   *   ---   *   ---
# ^errme

sub warn_renit($self) {

  warnproc

    "attempt to re-initialize "
  . "system memory block [ctl]:%s",

  args => [$self->ROOTID],
  give => null;

};

# ---   *   ---   *   ---
# alloc units and give idex

sub alloci($self,$cnt=1) {


  # get ctx
  my $mc = $self->getmc();
  my $al = $mc->{alloc};

  my $mpart_t = $al->mpart_t();


  # have avail?
  my ($ezy,$pos)=$mpart_t->fit(

    \$self->{almask},
    $cnt,

    limit=>$self->cnt,

  );


  # ^validate and give
  return (defined $pos)
    ? $pos
    : null
    ;

};

# ---   *   ---   *   ---
# ^build mem handle

sub alloc($self,$label=undef) {


  # get idex of free unit
  my $type = $self->size_t;
  my $idex = $self->alloci;


  # give mem handle if avail
  if(length $idex) {

    my $mem  = $self->{mem};
    my $view = $mem->view(

      $idex << $type->{sizep2},
      $type->{sizeof},

      $label,

    );

    return $view;


  # ^fail!
  } else {
    return null;

  };

};

# ---   *   ---   *   ---
# free allocated unit from idex

sub freei($self,$idex) {

  # clear bit from mask
  $self->{almask} &=~ 1 << $idex;
  return;

};

# ---   *   ---   *   ---
# ^free allocated from mem handle

sub free($self,$mem) {

  my ($base,$off) = $mem->get_addr();
  my $type        = $self->size_t();

  $off >>= $type->{sizep2};

  $self->freei($off);

  return;

};

# ---   *   ---   *   ---
# save current state var
# to their respective stacks

sub backup_alma($self) {

  push @{$self->{alhist}},
    $self->{almask};

  return;

};

sub backup_mem($self) {

  push @{$self->{memhist}},
    ${$self->{mem}->{buf}};

  return;

};

# ---   *   ---   *   ---
# ^undo

sub restore_alma($self) {

  $self->{almask}=
    pop @{$self->{alhist}};

  return;

};

sub restore_mem($self) {

  ${$self->{mem}->{buf}}=
    pop @{$self->{memhist}};

  return;

};

# ---   *   ---   *   ---
# ^the entire thing

sub backup($self) {

  $self->backup_alma();
  $self->backup_mem();

  return;

};

sub restore($self) {

  $self->restore_alma();
  $self->restore_mem();

  return;

};

# ---   *   ---   *   ---
# encode to binary

sub mint($self) {

  # get super
  my @out=A9M::layer::mint($self);

  # get attrs
  push @out,map {
    $ARG=>$self->{$ARG};

  } qw(mem almask alhist memhist);

  return @out;

};

# ---   *   ---   *   ---
# undo

sub unmint($class,$O) {

  # get super
  my $self=A9M::layer::unmint($class,$O);

  # get attrs
  $self->{mem}     = $O->{mem};
  $self->{almask}  = $O->{almask};
  $self->{alhist}  = $O->{alhist};
  $self->{memhist} = $O->{memhist};

  return $self;

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {

  my $out=ioprocin(\%O);

  $self->{mem}->prich(

    %O,

    mute  => 1,
    inner => 0,
    root  => 1,

  );

  return ioprocout(\%O);

};

# ---   *   ---   *   ---
1; # ret
