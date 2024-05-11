#!/usr/bin/perl
# ---   *   ---   *   ---
# ID
# Papers, please!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package id;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Cask;
  use Warnme;

  use Arstd::PM;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# instance book-keeping

sub man($class,$mode,$src) {


  # initialize if need
  state $tab = {};
  my    $dst = rcaller;
  my    $box = \$tab->{$dst};


  # delete?
  if($mode eq 'del') {

    return if ! defined $$box;

    $$box->take(idex=>$src->{iced})
    if ! --$src->{icedcnt};

    return;


  # fetch?
  } elsif($mode eq 'fet') {
    my $ice=$$box->view($src);
    return (defined $ice) ? $ice : null ;


  # make?
  } elsif($mode eq 'new') {

    $$box //= Cask->new();

    $src->{iced}    = $$box->give($src);
    $src->{icedcnt} = 1;

    return $src->{iced};


  # throw!
  } else {

    Warnme::invalid 'idcmd',

    obj  => $mode,
    give => null;

  };


};

# ---   *   ---   *   ---
# ^icef*ck

sub new($class,$ice) {
  return $class->man(new=>$ice);

};

sub fet($class,$idex) {
  return $class->man(fet=>$idex);

};

sub del($class,$ice) {
  return $class->man(del=>$ice);

};

# ---   *   ---   *   ---
# more specific:
#
# 0: id not found, make new!
# 1: id found, sharing with existing!

sub chk($class,$ice,$id=undef) {


  # bad or no id passed?
  return (0,$class->new($ice))

  if ! defined $id
  || ! length (my $have=$class->fet($id));


  # ^found, tick counter
  $ice->{iced}=$id;
  $have->{icedcnt}++;

  return (1,$id);

};

# ---   *   ---   *   ---
1; # ret
