#!/usr/bin/perl
# ---   *   ---   *   ---
# XCAV C
# Header scanner
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Avt::Xcav::C;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Arstd::throw;
  use rd;


# ---   *   ---   *   ---
# TODO: read utypes
#
# in C header, out symbols

sub symscan($class,$fpath) {
  # parse file
  my $rd=rd::crux(
    $fpath,

    ROM => 1,
    C   => 1,
  );

  # get parser ctx
  my $sym_re    = $rd->{l1}->re(SYM=>'.+');
  my $star_re   = $rd->{l1}->re(OPR=>'\*');
  my $comma_re  = $rd->{l1}->re(OPR=>',');
  my $exp_re    = $rd->{l1}->re(EXP=>'.*');
  my $parens_re = $rd->{l1}->re(SCP=>'\(');

  my @pat=(
    [$sym_re,$sym_re,$parens_re],
    [$sym_re,$star_re,$sym_re,$parens_re],
    [$sym_re,$star_re,$star_re,$sym_re,$parens_re],
  );


  # now we cat to this
  my $out={function=>{},utype=>{}};

  # ^cat [rtype,args] for every function
  my @nd=grep {
    defined $ARG->match_series(@pat);

  } $rd->{tree}->branches_in($exp_re)

  for(@nd) {
    my ($fn,$attrs)=rdfn($rd,$ARG);
    $out->{function}->{$fn}=$attrs;
  };

  return $out;
};


# ---   *   ---   *   ---
# ^get attrs for proc

sub rdfn($rd,$branch) {
  # get ctx
  my $comma_re = $rd->{l1}->re(OPR=>',');
  my $sym_re   = $rd->{l1}->re(SYM=>'.+');

  # get name of proc and return type
  my $name  = $branch->{leaves}->[-2];
  my @rtype = $name->all_back();

  # ^stirr
  my $rtype=join ' ',map {
    $rd->{l1}->untag($ARG->{value})->{spec}

  } @rtype;

  my $ptr_re=qr{\s+\*};

  $name  = $rd->{l1}->untag($name->{value})->{spec};

  $rtype = s[$ptr_re][\*]sxmg;
  $rtype = 'void' if $rtype eq null;


  # get everything between `()` parens
  my $par   = $branch->{leaves}->[-1];
  my @have  = $par->leafless_values;
  my $args  = [null,null];
  my $out   = {rtype=>$rtype,args=>$args};

  # ^walk args in reverse (yes)
  for(reverse @have) {

    # comma is reset
    if($ARG=~ $comma_re) {
      $args->[1]='void' if $args->[1] eq null;
      unshift @$args,(null,null);


    # symbol name after reset
    #
    # this is way we walk backwards
    # it ensures the name is always first ;>
    } elsif($args->[0] eq null) {
      $ARG=~ $sym_re or throw "Invalid SYM '$ARG'";
      $args->[0]=$+{spec};


    # ^everything afterwards (behind) is type,
    # ^up until comma or EOS
    } else {
      my $have=$rd->{l1}->untag($ARG)->{spec};

      # only the compiler cares about const
      $args->[1]="$have$args->[1]"
      if $have ne 'const';
    };

  };


  # edge case: nullargs ;>
  $args->[0]=null   if $args->[0] eq 'void';
  $args->[1]='void' if $args->[1] eq null;

  # give [F => attrs]
  return ($name=>$out);
};


# ---   *   ---   *   ---
1; # ret
