#!/usr/bin/perl
# ---   *   ---   *   ---
# RD CASE
# Keyword maker
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::case;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Storable;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => sub {

    return {

      main => undef,
      tab  => {},

    };

  },

};

# ---   *   ---   *   ---
# parser genesis

sub ready_or_build($self) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $tab  = $self->{tab};


  # the basic keyword from which all
  # others can be built is 'case'
  #
  # we need to define parsing rules
  # for it first, and from these rules,
  # all others should be dynamically built

  my $name  = $l1->tagre(STRING => '.+');
  my $at    = $l1->tagre(SYM    => 'at');
  my $loc   = $l1->tagre(NUM    => '.+');
  my $curly = $l1->tagre(OPERA  => '\{');

  $tab->{case} = [

    $self->signew(
      [name => $name],

      $at,

      [loc  => $loc],
      [body => $curly],

    ),

  ];

  return;

};

# ---   *   ---   *   ---
# makes signature

sub signew($self,@sig) {


  # walk pattern array
  my $idex = 0;
  my $capt = {};

  my @seq  = map {


    # have capture?
    my ($key,$pat);

    if(is_arrayref $ARG) {
      ($key,$pat)   = @$ARG;
      $capt->{$key} = $idex;

    # ^nope, match and discard!
    } else {
      $pat=$ARG;

    };


    # give pattern
    $idex++;
    $pat;

  } @sig;


  # give expanded
  return {
    capt => $capt,
    seq  => \@seq

  };

};

# ---   *   ---   *   ---
# entry point

sub parse($self,$keyw,$root) {

  $self->find($root,keyw=>$keyw);
  return;

};

# ---   *   ---   *   ---
# get branches that match

sub find($self,$root,%O) {


  # defaults
  $O{keyw} //= 'case';

  # get ctx
  my $main     = $self->{main};
  my $l1       = $main->{l1};
  my $tab      = $self->{tab};

  # get patterns
  my $keyw_re  = $l1->tagre(SYM=>$O{keyw});
  my $keyw_sig = $tab->{$O{keyw}};


  # get all top level branches that
  # begin with keyw. peso v:
  #
  # * "case %keyw at i {...}"
  #
  # ^this is the first pattern we must
  # be able to define without perl!

  my @have=(
    grep {$ARG->{parent} eq $root}
    $root->branches_in($keyw_re)

  );


  # now we want to ensure the signature is
  # correct. peso v:
  #
  # * "type  at i"
  #
  # | "value at i"
  #
  # | "type=value at i"
  #
  # ^this is a straight assertion: uppon reading
  # the name of case, that exact sequence must
  # follow


  map {

    my $nd=$ARG;

    map {$self->sigchk($nd,$ARG)}
    @$keyw_sig;

  } @have;

  exit;
  return;

};

# ---   *   ---   *   ---
# check node against signature

sub sigchk($self,$nd,$sig) {


  # get signature matches
  my ($pos)=
    $nd->match_sequence(@{$sig->{seq}});


  # args in order?
  if(defined $pos && $pos == 0) {

    my $lv  = $nd->{leaves};
    my $out = $self->sigcapt($lv,$sig);

    use Fmat;
    fatdump \$out;

    return 1;

  };


  # ^nope!
  return 0;

};

# ---   *   ---   *   ---
# captures signature matches!

sub sigcapt($self,$lv,$sig) {

  my %data=map {

    my $key  = $ARG;
    my $idex = $sig->{capt}->{$key};

    $key => $self->sigvalue($lv->[$idex]);

  } keys %{$sig->{capt}};

  return \%data;

};

# ---   *   ---   *   ---
# ^breaks down capture values ;>

sub sigvalue($self,$nd) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  my $key  = $nd->{value};

  # have annotated value?
  my ($type,$have)=$l1->xlate_tag($key);
  return $nd if ! $type;


  # have string?
  if($type eq 'STRING') {
    return $l1->detag($key);

  # have num?
  } elsif($type=~ qr{^(?:NUM|SYM)}) {
    return $have;


  # have operator?
  } elsif($type eq 'OPERA' && $have eq '{') {
    return $nd;


  # error!
  } else {
    die "unreconized: '$type' at sigvalue";

  };

};

# ---   *   ---   *   ---
# per-keyw errme

sub err_shape($self,$iref,$nd,$shape) {


  # walk pattern list
  say "SHAPE $$iref";
  my $assert=0;

  map {


    # get value at this position
    my $key= ($nd->{leaves}->[$assert])
      ? $nd->{leaves}->[$assert]->{value}
      : '<null>'
      ;

    # ^get value passed the assertion!
    say sprintf
      "assert %2u -> (%1b) %s",
      $assert++,int($key=~ $ARG),$key;


  } @$shape;


  # go next
  say null;
  $$iref++;

};

# ---   *   ---   *   ---
1; # ret
