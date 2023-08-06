#!/usr/bin/perl
# ---   *   ---   *   ---
# DEPRECATED PACKAGE
# Common regex operations moved
# to Arstd::Re
#
# This file is left as it is
# to avoid breaking other legacy
# packages; it will be (eventually)
# either retired or repurposed
#
# ---   *   ---   *   ---
# LANG
# Syntax wrangler
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
#
# ---   *   ---   *   ---
# NOTE:
#
# Most of these regexes were taken from nanorc files!
# all I did was *manually* collect them to make this
# syntax file generator
#
# ^ this note is outdated ;>
# dirty regexes are at their own language files now
#
# ^^ more than outdated!
# almost none of the original regexes remain ;>
# still leaving this up for acknowledgement
#
# ---   *   ---   *   ---
# deps

package Lang;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';
  use Shwl;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);
  use Carp;

  use List::Util qw( max );

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Array;
  use Arstd::Re;

  use Chk;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(rmquotes);

# ---   *   ---   *   ---
# info

  our $VERSION=v1.02.6;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $OP_L=>0x01;
  Readonly our $OP_R=>0x02;
  Readonly our $OP_B=>0x04;
  Readonly our $OP_A=>0x08;

# ---   *   ---   *   ---
# escapes [*]: in pattern

sub lescap($s) {

  for my $c(split '','[*]:') {
    $s=~ s/\Q${ c }/\\${ c }/g;

  };return $s;

};

# ---   *   ---   *   ---
# removes double and single quotes
# at end and beggining of string

sub rmquotes($s) {

  state $re=qr{^["']+|["']+$}x;

  $s=~ s[$re][]sxmg;
  return $s;

};

# ---   *   ---   *   ---
# delimiter patterns

sub delim($beg,$end=$NULLSTR,$ml=0) {

  if(!length $end) {
    $end=$beg;

  };

  my $allow=re_neg_lkahead(

    $end,

    multiline=>$ml,
    uberscape=>1,

  );

  $beg=re_opscape($beg);
  $end=re_opscape($end);

  my $out="($beg(($allow)*)$end)";
  return qr{$out}x;

};

# ---   *   ---   *   ---
# ^multiline

sub delim2($beg,$end=$NULLSTR,$ml=0) {

  if(!$end) {
    $end=$beg;

  };

  my $allow=re_neg_lkahead(

    $end,

    multiline=>$ml,
    uberscape=>0,

  );

  $beg=re_opscape($beg);
  $end=re_opscape($end);

  return qr{

    $beg

    (($allow|$end)*)

    $end

    [^$end]*\$

  }x;

};

# ---   *   ---   *   ---
# book-keeping

my %LANGUAGES=();

sub register_def($name) {
  $LANGUAGES{$name}=eval(q{Lang::}.$name);

};

sub file_ext($file) {

  my $name=undef;

  $file=(split '/',$file)[-1];

  for my $lang(values %LANGUAGES) {

    my $pat=$lang->{ext};

    if($file=~ m/$pat/) {
      $name=$lang->{name};
      last;

    };
  };

  return $name;

};

# ---   *   ---   *   ---
# for when you just need textual recognition

sub quick_op_prec(%h) {

  my $result={};
  my $prec=-1;

# ---   *   ---   *   ---

  my $asg_c=undef;

  if(exists $h{asg}) {
    $asg_c=$h{asg};
    delete $h{asg};

    my ($sign,$compound,$standalone)=@$asg_c;
    my @asg_ops=();

    for my $c(@$compound) {
      push @asg_ops,$c.$sign;

    };

    for my $c(@$standalone) {
      push @asg_ops,$c;

    };

    for my $op(@asg_ops) {
      if(!exists $h{$op}) {$h{$op}=$OP_B|$OP_A}
      else {$h{$op}|=$OP_A};

    };

  };

# ---   *   ---   *   ---

  for my $op(keys %h) {

    my $flags=$h{$op};

    my $ar=[

      undef,  # takes operand on left
      undef,  # takes operand on right
      undef,  # ^takes both operands

      0       # is assignment operator

    ];

# ---   *   ---   *   ---

    if($flags & $OP_L) {
      $ar->[0]
        =[$prec,sub($x) {return $$x.$op}]

    };

# ---   *   ---   *   ---

    if($flags & $OP_R) {
      $ar->[1]
        =[$prec,sub($y) {return $op.$$y}]

    };

# ---   *   ---   *   ---

    if($flags & $OP_B) {
      $ar->[2]
        =[$prec,sub($x,$y) {return $$x.$op.$$y}]

    };

# ---   *   ---   *   ---

    if($flags & $OP_A) {$ar->[3]=1};

    $prec++;
    $result->{$op}=$ar;

  };

  return $result;

};

# ---   *   ---   *   ---
1; # ret
