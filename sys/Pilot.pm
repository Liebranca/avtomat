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
  use Cask;

  use Type;
  use Blk;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {}};

  Readonly our $DOM=>0x1BE7;
  Readonly our $SIGIL=>0x0000;

  Readonly our $XKP=>$Type::Table->nit(

    'Pilot::XKP',[

      wide=>'dom',
      wide=>'sigil',

      half=>'id',

    ]

  );

# ---   *   ---   *   ---
# constructor

sub nit($class) {

  my $blk=$Blk::Sys_Frame->nit(
    $Blk::Non,$class

  );

  my $pil=bless {

    blk=>$blk,

  },$class;

  return $pil;

};

# ---   *   ---   *   ---
1; # ret
