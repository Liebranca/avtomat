#!/usr/env/perl
# ---   *   ---   *   ---

package main;
  use v5.42.0;
  use strict;
  use warnings;
  use lib "$ENV{ARPATH}/lib/sys/";
  use Type qw(
    struc
    typefet
    sizeof
    offsetof
    typeraw
  );
  use Arstd::xd;
  use Arstd::fatdump;
  use Arstd::mem qw(
    mem_store
    mem_load
  );
  use Arstd::vm qw(
    vm_new
    vm_enter
    vm_leave
    vm_in
    vm_out
    vm_local
    vm_var_blk
    vm_sym_in
    vm_sym_out
  );
  use Arstd::ir qw(ctoir);


# ---   *   ---   *   ---
# ~ the bit

my $code=q[
dword fn(dword y,dword x) {
  return y+x;
};
];

my $vm=vm_new();
my @ir=ctoir($vm,$code);
fatdump \[@ir];


# ---   *   ---   *   ---
1; # ret
