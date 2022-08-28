#!/usr/bin/perl
# ---   *   ---   *   ---
# PILOT
# I gotta move...
# put on my travelin shoes
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb
# ---   *   ---   *   ---

# deps
package Pilot;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Array;

  use Cask;

  use Type;
  use Blk;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.3;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {}};

  Readonly our $DOM=>0x9E50;
  Readonly our $SIGIL=>0xE4EC;

  Readonly our $XKP=>$Type::Table->nit(

    'Pilot::XKP',[

      byte=>'sigil',
      byte_str=>'id(7)',

    ],

  );

  our $FNDAT=[

    cpy=>[qw(word word)],

  ];

  Readonly our $FNTAB=>array_key_idex([

    array_keys($FNDAT)

  ]);

  $FNDAT={@$FNDAT};

# ---   *   ---   *   ---
# constructor

sub nit($class) {

  $Blk::Sys_Frame->__ctltake();

  my $blk=$Blk::Sys_Frame->nit(
    $Blk::Non,$class

  );

  $Blk::Sys_Frame->__ctlgive();

# ---   *   ---   *   ---

  my $pil=bless {

    blk=>$blk,
    wed=>$Type::Table->{word},

    ins_buf=>[],

  },$class;

  return $pil;

};

# ---   *   ---   *   ---
# sets typing mode

sub wed($self,$name) {

  errout(

    q[Bad typing mode '%s'],

    args=>[$name],
    lvl=>$AR_FATAL,

  ) unless defined $Type::Table->{$name};

  $self->{wed}=$Type::Table->{$name};

};

# ---   *   ---   *   ---

sub ins($self,$call,@args) {

  my $blk=$self->{blk};
  my $id=$FNTAB->{$call};

  my $fmat="$Type::PACK_SIZES->{64}>";

  for my $arg_t(@{$FNDAT->{$call}}) {

    my $elem_sz=$Type::Table
      ->{$arg_t}->{size};

    $elem_sz*=8;
    $fmat.="$Type::PACK_SIZES->{$elem_sz}>";

  };

  my $wsig=$self->{wed}->{sigil};
  my $body=pack $fmat,($wsig<<56)|$id,@args;

  my ($cnt,$sz)=$blk->align_sz(length $body);

  my $ptr=$blk->alloc(

    'ins'.int(@{$self->{ins_buf}}),

    $Type::Table->{byte_str},$cnt

  );

  $ptr->strcpy($body);

  push @{$self->{ins_buf}},$ptr;

};

# ---   *   ---   *   ---
1; # ret
