#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD TEST
# Utilities for writing 'em
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Arstd::Test;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $CMPTAB=>{

    'eq'=>sub($a,$b) {
      $$a//=$NULLSTR;
      $$b//=$NULLSTR;

      return $$a eq $$b;

    },

  };

# ---   *   ---   *   ---

sub nit($class,$name) {

  my $tab="\e[37;1m\::\e[0m";

  my $format=
    "Test unit ".
    "\e[36;1m'%s'\e[0m"

  ;

  fstrout(
    $format,$tab,

    args=>[$name],
    pre_fmat=>"\n",
    post_fmat=>"\n",

  );

  return bless {

    id=>$name,

    passed=>0,
    total=>0,

  },$class;

};

# ---   *   ---   *   ---

sub passed($t) {

  my $tab="\e[37;1m\::\e[0m";
  my $status=$NULLSTR;

  my $format=

    "\e[33;22m%i\e[0m".
    "\e[37;1m/\e[0m".
    "\e[33;22m%i\e[0m ".

    "checks passed\n".

    "Status: %s"

  ;

# ---   *   ---   *   ---

  if($t->{passed} != $t->{total}) {
    $status="\e[31;22mFAILURE\e[0m";

  } else {
    $status="\e[32;22mSUCCESS\e[0m";

  };

# ---   *   ---   *   ---
# spit out results to log

  fstrout(
    $format,$tab,

    args=>[$t->{passed},$t->{total},$status],
    pre_fmat=>"\n",
    post_fmat=>"\n",

  );

  return $t->{passed} == $t->{total};

};

# ---   *   ---   *   ---
# report check results

sub test($t,$cmp,$a,$b,%opt) {

  # opt defaults
  $opt{name}//='unnamed';

# ---   *   ---   *   ---

  my $tab=sprintf
    "\e[37;1m<\e[0m".
    "\e[34;22m%s\e[0m".
    "\e[37;1m>\e[0m ",

    'test',

  ;

  my $endtab=sprintf

    "\e[37;1m(\e[0m".

    "\e[34;22m%s\e[0m".
    "\e[37;1m::\e[0m".
    "\e[33;22m%s\e[0m".

    "\e[37;1m)\e[0m",

    (caller)[1],(caller)[2]

  ;

# ---   *   ---   *   ---

  # placeholders
  my $format="%-21s %-2s ";
  my $status=$NULLSTR;

  # used to recolor the format
  my $cfn=$NULLSTR;

# ---   *   ---   *   ---
# failure

  if($CMPTAB->{$cmp}->(\$a,\$b)) {
    $status='NO';
    $cfn="\e[31;22m";

# ---   *   ---   *   ---
# success

  } else {
    $status='OK';
    $cfn="\e[32;22m";

  };

# ---   *   ---   *   ---

  $t->{passed}+=int($status eq 'OK');
  $t->{total}+=1;

# ---   *   ---   *   ---

  fstrout(
    $format,$tab,
    args=>[$opt{name},"$cfn$status\e[0m"],

    endtab=>$endtab,

  );

  return;

};

# ---   *   ---   *   ---
