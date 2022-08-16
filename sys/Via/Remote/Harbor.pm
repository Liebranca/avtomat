#!/usr/bin/perl
# ---   *   ---   *   ---
# REMOTE VIA::HARBOR
# Remote calls
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Via::Remote::Harbor;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Cask;
  use Arstd::Array;

  use parent 'Via::Harbor';

# ---   *   ---   *   ---

sub sink($self) {

  return Via->ship(

    $self->{net},
    $self->request(0,'sink',$self->{idex})

  );

};

sub nit($class,$name) {

  my $self=$class;
  my $net="$Shb7::Mem$name.sock";

  return bless Via->ship(

    $net,
    $self->request(0,'nit',"$name$Via::NET_RS$0")

  ),$class;

};

sub get_peer($self,$name,$idex=1) {

  my $class=$self->get_class();

  return bless Via->ship(

    $self->{net},
    $self->request(0,'get_peer',$name,$idex)

  ),$class;

};

# ---   *   ---   *   ---
1; # ret
