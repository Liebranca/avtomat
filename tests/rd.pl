#!/usr/bin/perl
# ---   *   ---   *   ---

package main;

  use v5.36.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path);
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/avtomat/sys/';

  use Style;
  use Type;
  use Bpack;

  use ipret;
  use xlate;

  use Fmat;
  use Shb7;
  use Arstd::Path;

  use Arstd::IO;
  use Arstd::xd;

# ---   *   ---   *   ---
# run and dbout

my $xlate = xlate->new(

q[%;

clan testy;

proc fn;

  in  byte x0;
  out byte x1;

  add x0,$26;


blk err;
  cmp  br,$00;
  jz   ok;

  os   exit,1;


blk ok;
  add  x0,$01;
  ret;


proc start;

  in   byte x2;
  byte x1;
  byte x3;

  ld   x1,$24;

  x3=*fn x1;

  add  x2,x3;
  add  x2,x1;
  ld   x1,x3;

  ret;

],

#  glob('~/bt/dice.pe'),
  limit=>2

);

my $prog  = $xlate->run();

say $prog;
exit;

# ---   *   ---   *   ---
# assemble!

my $asm   = Shb7::trash('avtomat/rd.asm');
my @call  = (fasm=>$asm);

owc    $asm=>$prog;
system {$call[0]} @call;

# ---   *   ---   *   ---
# find the output ;>

my $bin =  $asm;
   $bin =~ s[\.[^\.]+$][];

my $out = abs_path './a.out';

rename $bin=>$out;

# ---   *   ---   *   ---
1; # ret
