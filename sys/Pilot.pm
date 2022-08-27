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

  our $VERSION=v0.00.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {}};

  Readonly our $DOM=>0x1BE7;
  Readonly our $SIGIL=>0xE4EC;


  Readonly our $FNTAB=>array_key_idex([qw(

    cpy

  )]);

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

  },$class;

  $Blk::Non->set_header(

    $class,

    N=>0xF,
    ID=>0x1,

  );

  return $pil;

};

# ---   *   ---   *   ---

sub stream($self,$data,$call,@args) {

  my $blk=$self->{blk};

  my $id=(int(@args)<<28)|$FNTAB->{$call};
  my ($cnt,$sz)=$blk->align_sz(length $data);

  my $fmat="$Type::PACK_SIZES->{16}>2";
  $fmat.="$Type::PACK_SIZES->{32}>";
  $fmat.="$Type::PACK_SIZES->{64}>";

  my $body=pack $fmat,$DOM,$SIGIL,$id,$cnt;
  ($cnt,$sz)=$blk->align_sz(
    length $body.$data

  );

  my $ptr=$blk->alloc(

    'input',
    $Type::Table->{byte_str},

    $cnt

  );

  $ptr->strcpy($body.$data);

};

# ---   *   ---   *   ---
1; # ret
