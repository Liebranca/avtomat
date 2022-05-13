#!/usr/bin/perl
# ---   *   ---   *   ---
# LYPERL
# Makes Perl even cooler
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package lyperl;
  use strict;
  use warnings;

  use Filter::Util::Call;

  use lib $ENV{'ARPATH'}.'/avtomat/';
  use lang;

# ---   *   ---   *   ---

sub import {

  my ($type)=@_;
  my ($ref)={

    lline_exp=>0,

    line=>'',
    lineno=>1,
    macros=>{},

  };filter_add(bless $ref);

};

# ---   *   ---   *   ---

sub replstr($) {

  my $s=shift;

  my ($dq,$non_dq)=lang::cut($s,lang::dqstr);
  my ($sq,$non_sq)=lang::cut($s,lang::sqstr);

  printf ">NON_DQ:\n";
  printf ''.(join "\n",@$non_dq)."\n";

  printf ">DQ:\n";
  printf ''.(join "\n",@$dq)."\n";

  printf "____________\n\n";

};

# ---   *   ---   *   ---

sub filter {

  my ($self)=@_;
  my $status=filter_read();

  if(
      $status<0
  ||  !length lang::stripline($_)

  ) {return $status;};my $s=$_;

# ---   *   ---   *   ---

  # not a multi-line bit
  if($self->{lline_exp}) {
    $self->{line}=$s;

  # the other way around
  } else {
    $self->{line}.=$s;

  };

# ---   *   ---   *   ---

  replstr($s);$_='';

  $self->{lineno}++;
  return $status;

};

# ---   *   ---   *   ---
1; # ret

