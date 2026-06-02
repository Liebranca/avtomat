#!/usr/bin/perl
# ---   *   ---   *   ---

package tests::SWAN;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Type qw(typefet sizeof);
  use Arstd::xd;

  use lib "$ENV{ARPATH}/lib/";
  use SWAN qw(
    mem_new
    mem_delete
    mem_push_string
    mem_at_string
    mem_usedsz
    xp_strlen
  );


# ---   *   ---   *   ---
# ~~

my $cstr=typefet('cstr');
my $s=pack($cstr->{packof},"H1\0 1\0\0\0\0");

xd($s);
say xp_strlen($s);


# ---   *   ---   *   ---
# ~~

#my $byte = typefet('byte');
#my $mem  = typefet('mem');
#my $self = pack($mem->{packof});
#
#mem_new($self,$byte->{sizeof},64,0x00);
#
#for("HLOWRLD","BYEWRLD") {
#  my $used=unpack("x8Q",$self);
#  say "$used (" . mem_usedsz($self) . ")";
#
#  mem_push_string($self,$ARG);
#};
#
#xd(mem_at_string($self,0));
#xd(mem_at_string($self,1));
#
#mem_delete($self);


# ---   *   ---   *   ---
1; # ret
