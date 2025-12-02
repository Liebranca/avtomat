#!/usr/bin/perl
# ---   *   ---   *   ---

package tests::proc;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/";
  use lib "$ENV{ARPATH}/lib/sys";
  use Chk qw(is_file);
  use MAM;
  use CMAM;

# ---   *   ---   *   ---
# ~~

sub mamrun {
  my @file=grep {is_file $ARG} @ARGV;
  $ENV{MAMROOT}=$ENV{ARPATH};
  for(@file) {
    my $mam=MAM->new();
    $mam->set_module('avtomat');
    $mam->set_rap(1);

    say $mam->run($ARG);

  };
  return;
};

sub cmamrun {
my $cstr=q[

package non; // global scope
  use PM Style qw(null);
  use PM Chk qw(is_null);
  use PM Type;
  use lib "$ENV{ARPATH}/lib/sys/";
  use PM Arstd::String qw(strip);
  use PM Arstd::Bin qw(deepcpy);
  use PM Arstd::throw;

  use PM CMAM::static qw(
    cpackage
    cmamlol
    cmamgbl
    cmamout
  );

macro public($nd) {
  $nd->{cmd}=tokenshift($nd);
  my $cpy=Arstd::Bin::deepcpy($nd);

  my @out = CMAM::parse::exprproc($cpy);
  my $dst = cmamout()->{export};
  my $i   = int @$dst;
  push @$dst,[@out];

  clnd($nd);
  return strnd("__EXPORT_${i}__;");
};

public #include "cthis.h";
public int main(void) {
  return 0;
};

];

  CMAM::restart();
  my $src=CMAM::blkparse($cstr);
  my $hed=CMAM::emit::chead('s',$src);

  say "$hed\n\n# ---   *   ---   *   ---\n\n$src";

  return;
};

cmamrun;

# ---   *   ---   *   ---
1; # ret
