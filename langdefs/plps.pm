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

  '->'=>[

    undef,
    undef,

    [-1,sub {my ($x,$y)=@_;return "$$x->$$y";}],

  ],'?'=>[

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

  'beg'=>[sbl_id,'1<type>:1<bare>'],
  'end'=>[sbl_id,'0'],

  'in'=>[sbl_id,'1<path>'],

};

# ---   *   ---   *   ---

BEGIN {

$plps_sbl=peso::sbl::new_frame();

DEFINE 'beg',DIRECTIVE,sub {

  my ($inskey,$frame,@fields)=@_;
  my ($f0,$f1)=@fields;
  my $m=$frame->master;

  $f0=$f0->[0];
  $f1=$f1->[0];

  $m->{defs}->{$f0}->{$f1}='';
  $m->{dst}=\$m->{defs}->{$f0}->{$f1};

};

# ---   *   ---   *   ---

DEFINE 'in',DIRECTIVE,sub {

  my ($inskey,$frame,@fields)=@_;
  my ($f0)=@fields;
  my $m=$frame->master;

  $f0=$f0->[0];

  #:!;> also a hack
  $m->{ext}=eval($f0);

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

    sbl ptr bare
    sep del ari
    ode cde

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

  -MCUT_TAGS=>[-CHAR],

);

};

# ---   *   ---   *   ---
1; # ret
