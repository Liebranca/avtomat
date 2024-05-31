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

  use ipret;
  use xlate;

  use Fmat;
  use Shb7;
  use Arstd::Path;

  use Arstd::IO;
  use Arstd::xd;

# ---   *   ---   *   ---
# run and dbout

my $xlate = xlate->new('./lps/hello.pe',limit=>2);
my $prog  = $xlate->run();

#say $prog;
#exit;

# ---   *   ---   *   ---
# assemble!

my $asm   = Shb7::trash('avtomat/rd.s');
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
