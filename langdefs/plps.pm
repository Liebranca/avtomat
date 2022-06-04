#!/usr/bin/perl
# peso language pattern syntax

# ---   *   ---   *   ---
# deps
package langdefs::plps;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;
  use peso::sbl;

# ---   *   ---   *   ---
# shorthands

my $plps_sbl=undef;

sub DEFINE($$$) {

  $plps_sbl->DEFINE(
    $_[0],$_[1],$_[2],

  );
};

# ---   *   ---   *   ---

sub ALIAS($$) {

  $plps_sbl->DEFINE(
    $_[0],$_[1],$_[2],

  );
};

my $SBL_ID=0;sub sbl_id() {return $SBL_ID++;};

# ---   *   ---   *   ---

use constant plps_ops=>{

  '?'=>[

    [0,sub {my ($x)=@_;$x->{optional}=1;}],
    undef,
    undef,

  ],'+'=>[

    [1,sub {my ($x)=@_;$x->{consume_equal}=1;}],

    undef,
    undef,

  ],'--'=>[

    [2,sub {my ($x)=@_;$x->{rewind}=1;}],

    undef,
    undef,

  ],

# ---   *   ---   *   ---

};use constant DIRECTIVE=>{

  'beg'=>[sbl_id,'1<bare>:1<type>'],
  'end'=>[sbl_id,'0'],

};

# ---   *   ---   *   ---

BEGIN {

$plps_sbl=peso::sbl::new_frame();

DEFINE 'beg',DIRECTIVE,sub {

  my ($inskey,$frame,@fields)=@_;
  my ($f0,$f1)=@fields;

  $f0=$f0->[0];
  $f1=$f1->[0];

  printf "$f0:$f1\n";


};

# ---   *   ---   *   ---

lang::def::nit(

  -NAME=>'plps',

  -EXT=>'\.pe\.lps',
  -HED=>'\$:%plps;>',
  -MAG=>'Peso-style language patterns',

# ---   *   ---   *   ---

  -TYPES=>[qw(

    type spec dir itri

    sbl ptr ode cde
    sep del ari

    fctl sbl_decl ptr_decl pattern

  )],

  -DIRECTIVES=>[keys %{langdefs::plps->DIRECTIVE}],

  -SBL=>$plps_sbl,

# ---   *   ---   *   ---

  -ODE=>'[<]',
  -CDE=>'[>]',

  -DEL_OPS=>'[<>]',
  -NDEL_OPS=>'[?+-]',
  -OP_PREC=>plps_ops,

);

};

# ---   *   ---   *   ---
1; # ret
