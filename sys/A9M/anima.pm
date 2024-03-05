#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M ANIMA
# Soul of computing
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::anima;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Type;
  use Warnme;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::Re;
  use Arstd::IO;

  use parent 'A9M::component';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  list   => [qw(

    ar    br    cr    dr
    er    fr    gr    hr

    xp    xs    sp    sb

    ice   ctx   opt   chan

  )],

  re     => sub {re_eiths $_[0]->list()},

  sizek  => 'qword',
  size   => sub {sizeof $_[0]->sizek()},

  cnt    => sub {int @{$_[0]->list()}},
  cnt_bs => sub {bitsize $_[0]->cnt()-1},
  cnt_bm => sub {bitmask $_[0]->cnt()-1},

};


# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {


  # defaults
  $O{mcid}  //= 0;
  $O{mccls} //= caller;

  # get ctx
  my $self = bless \%O,$class;

  my $mach = $self->getmc();
  my $cas  = $mach->{cas};


  # make ice
  my $mem=$cas->new(

    $class->size()
  * $class->cnt(),

    'ANIMA'

  );


  # ^make labels
  my $addr = 0x00;
  my @ptr  = map {

    my $v=$mem->lvalue(

      0x00,

      addr  => $addr,
      label => $ARG,

      type  => $class->sizek(),

    );

    $addr += $class->size();
    $v;

  } @{$class->list()};


  # save to ice and give
  $self->{mem}=$mem;
  $self->{ptr}=\@ptr;

  return $self;

};

# ---   *   ---   *   ---
# get register by name or idex

sub fetch($self,$name) {


  # idex passed
  return ($name < $self->cnt())
    ? $self->{ptr}->[$name]
    : warn_invalid($name)

  if $name=~ qr{^\d+$};


  # ^else get idex
  my $idex=$self->tokin($name);
  defined $idex or return warn_invalid($name);

  return $self->{ptr}->[$idex];

};

# ---   *   ---   *   ---
# ^errme

sub warn_invalid($name) {

  Warnme::invalid 'register',

  obj  => $name,
  give => null;

};

# ---   *   ---   *   ---
# get token is register
#
# if so, give idex
# else undef

sub tokin($class,$name) {

  return ($name=~ $class->re())
    ? array_iof($class->list(),$name)
    : undef
    ;

};

# ---   *   ---   *   ---
# legacy method from AR/forge
# needs revision!
#
# generates *.pinc ROM file
# if this one is updated

sub update($class,$A9M) {


  # get additional deps
  use Shb7::Path;

  use lib $ENV{'ARPATH'}.'/forge/';
  use f1::blk;


  # file to (re)generate
  my $dst="$A9M->{path}->{rom}/ANIMA.pinc";

  # ^missing or older?
  if(moo($dst,__FILE__)) {

    # dbout
    $A9M->{log}->substep('ANIMA');

    # make codestr with constants
    my $blk=f1::blk->new('ROM');

    $blk->lines(

      'define A9M.REGISTERS '
    . (join ',',@{$class->list()}) . ';'

    . "A9M.REGISTER_CNT    = " . $class->cnt() .';'
    . "A9M.REGISTER_CNT_BS = " . $class->cnt_bs() .';'
    . "A9M.REGISTER_CNT_BM = " . $class->cnt_bm() .';'

    );

    # ^commit to file
    owc($dst,$blk->{buf});

  };

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {
  $self->{mem}->prich(%O,inner=>0);

};

# ---   *   ---   *   ---
1; # ret
