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

  Readonly our $LIST=>[qw(

    ar    br    cr    dr
    er    fr    gr    hr

    xp    xs    sp    sb

    ice   ctx   opt   chan

  )];

  Readonly our $SIZE_K => 'qword';
  Readonly our $SIZE   => sizeof $SIZE_K;
  Readonly our $CNT    => int @$LIST;

  Readonly our $CNT_BS => bitsize($CNT-1);
  Readonly our $CNT_BM => bitmask($CNT_BS);

  Readonly our $RE     => re_eiths($LIST);

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
    $SIZE * $CNT,'ANIMA'

  );


  # ^make labels
  my $addr=0x00;
  map {

    $mem->lvalue(

      0x00,

      addr  => $addr,
      label => $ARG,

      type  => $SIZE_K,

    );

    $addr += $SIZE;

  } @$LIST;


  return $mem;

};

# ---   *   ---   *   ---
# get token is register
#
# if so, give idex
# else undef

sub tokin($name) {

  return ($name=~ $RE)
    ? array_iof($LIST,$name)
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
    . (join ',',@$LIST) . ';'

    . "A9M.REGISTER_CNT    = $CNT;"
    . "A9M.REGISTER_CNT_BS = $CNT_BS;"
    . "A9M.REGISTER_CNT_BM = $CNT_BM;"

    );

    # ^commit to file
    owc($dst,$blk->{buf});

  };

};

# ---   *   ---   *   ---
1; # ret
