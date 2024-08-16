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

proc new;


  qword mask;

  ld  br,$304;
  ld  mask,$01;
  shl mask,$08;
  dec mask;

  and br,mask;


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
