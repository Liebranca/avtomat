#!/usr/bin/perl
# ---   *   ---   *   ---
# RD SIG
# Patterns of a call
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::sig;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,$ar) {


  # walk pattern array
  my $idex = 0;
  my $capt = {};
  my $defv = {};

  my @seq  = map {

    my ($key,@pat);


    # named field?
    if(is_arrayref $ARG) {

      ($key,@pat)=@$ARG;

      # have capture?
      if(is_qre $pat[0]) {
        $capt->{$key}=$idex;

      # have defval!
      } else {
        $defv->{$key}=$pat[0];
        @pat=();

      };


    # ^nope, match and discard!
    } else {
      @pat=$ARG;

    };


    # give pattern if any
    $idex += int @pat;
    @pat;

  } @$ar;


  # give expanded
  return bless {

    capt => $capt,
    defv => $defv,

    seq  => \@seq,
    flat => 0,

  },$class;

};

# ---   *   ---   *   ---
# get keys of all declared attrs

sub getattrs($self) {

  my @keys = (
    keys %{$self->{capt}},
    keys %{$self->{defv}},

  );

  array_dupop \@keys;
  return       @keys;

};

# ---   *   ---   *   ---
# ^copy to attributes to hashref
# if it is defined

sub attrs_to_hash($self,$key,$dst) {

  map {
    $dst->{$ARG} //=
      $self->{$key}->{$ARG}

  } grep {
    exists $self->{$key}->{$ARG}

  } $self->getattrs();

  return;

};

# ---   *   ---   *   ---
# ^set own attrs from hashref
# if it is not defined

sub hash_to_attrs($self,$key,$src) {

  map {
    $self->{$key}->{$ARG}=$src->{$ARG}

  } grep {
    ! exists $self->{defv}->{$ARG}
  &&! exists $self->{capt}->{$ARG}

  } keys %$src;

  return;

};

# ---   *   ---   *   ---
# get input matches pattern

sub match($self,$x,%O) {


  # fstate
  return () if ! defined $x;
  my ($valid,$ar,@lv);

  # defaults
  $O{inclusive} //= 0;
  $O{flat}      //= 0;
  $O{nopush}    //= 0;


  # input is tree?
  if(Tree->is_valid($x)) {

    ($valid,@lv)=
      $x->cross_sequence($self->{seq},%O);


    if($valid) {
      shift @lv       if   $O{inclusive};
      $x->pushlv(@lv) if ! $O{nopush};

    };

    $ar=$x->{leaves};


  # input is array!
  } else {

    ($valid,@lv)=array_matchpop
      $x,@{$self->{seq}};

    $ar=$x;

  };


  # give OK of args in order
  return ($valid)
    ? $self->capt($ar)
    : null
    ;

};

# ---   *   ---   *   ---
# captures signature matches!

sub capt($self,$lv) {


  # read values from tree
  my %data=map {

    my $key  = $ARG;
    my $idex = $self->{capt}->{$key};

    $key => $lv->[$idex];

  } keys %{$self->{capt}};


  # set defaults!
  map {

    $data{$ARG} //=
      $self->{defv}->{$ARG};

  } keys %{$self->{defv}};


  # give descriptor
  return \%data;

};

# ---   *   ---   *   ---
1; # ret
