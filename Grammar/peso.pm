#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO GRAMMAR
# Recursive swan song
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/avtomat/sys/';

  use Style;
  use Arstd::IO;

  use lib $ENV{'ARPATH'}.'/avtomat/';

  use Lang;
  use parent 'Grammar';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) { return {

    -creg   => undef,
    -cclan  => 'non',
    -cproc  => undef,

    %{Grammar->Frame_Vars()}

  }};

  Readonly my $REGEX=>{

    hexn  => qr{\$  [0-9A-Fa-f\.:]+}x,
    octn  => qr{\\ [0-7\.:]+}x,
    binn  => qr{0b  [0-1\.:]+}x,
    decn  => qr{[0-9\.:]+}x,

    term  => Lang::nonscap(';'),
    sep   => Lang::nonscap(','),

    vname => qr{

      [_A-Za-z][_A-Za-z0-9:\.]*

    }x,

    hier  => Lang::eiths(

      [qw(reg rom clan proc)],

      bwrap  => 1,
      insens => 1,

    ),

    reg   => Lang::eiths(

      [qw(reg)],

      bwrap  => 1,
      insens => 1,

    ),

    type  => Lang::eiths(

      [qw(

        byte wide brad word
        unit half line page

        nihil stark signal

      )],

      bwrap  => 1,
      insens => 1,

    ),

    spec  => Lang::eiths(

      [qw(ptr fptr str buf tab)],

      bwrap  => 1,
      insens => 1,

    ),

  };

# ---   *   ---   *   ---
# numerical notation

  Readonly my $HEX=>{
    name => $REGEX->{hexn},
    fn   => 'capt',

  };

  Readonly my $OCT=>{
    name => $REGEX->{octn},
    fn   => 'capt',

  };

  Readonly my $BIN=>{
    name => $REGEX->{binn},
    fn   => 'capt',

  };

  Readonly my $DEC=>{
    name => $REGEX->{decn},
    fn   => 'capt',

  };

# ---   *   ---   *   ---
# ^combined into a single rule

  Readonly my $NUM=>{

    name => 'num',
    fn   => 'rdnum',

    dom  => 'Grammar::peso',

    chld => [

      $HEX,$Grammar::OR,
      $OCT,$Grammar::OR,
      $BIN,$Grammar::OR,

      $DEC

    ],

  };

# ---   *   ---   *   ---
# lets call these "syntax ops"

  Readonly my $CLIST=>{

    name => $REGEX->{sep},
    fn   => 'rew',

    opt  => 1,

  };

  Readonly my $TERM=>{
    name => $REGEX->{term},
    fn   => 'term',

  };

# ---   *   ---   *   ---

  Readonly my $TYPE=>{
    name => $REGEX->{type},
    fn   => 'capt',

  };

  Readonly my $SPEC=>{
    name => $REGEX->{spec},
    fn   => 'capt',

    opt  => 1,

  };

  Readonly my $VNAME=>{
    name => $REGEX->{vname},
    fn   => 'capt',

  };

# ---   *   ---   *   ---

  Readonly my $HIER=>{
    name => $REGEX->{hier},
    fn   => 'capt',

  };

  Readonly my $REG=>{
    name => $REGEX->{reg},
    fn   => 'capt',

  };

  Readonly my $UTYPE_DECL=>{

    name => 'utype_decl',

    fn   => 'utype_decl',
    dom  => 'Grammar::peso',

    chld => [$REG,$VNAME,$TERM],

  };

# ---   *   ---   *   ---

  Readonly my $FULL_TYPE=>{
    name => 'type',
    chld => [$TYPE,$SPEC],

  };

  Readonly my $NLIST=>{
    name => 'vnames',
    chld => [$VNAME,$CLIST],

  };

  Readonly my $VLIST=>{

    name => 'values',

    fn   => 'list_flatten',
    dom  => 'Grammar::peso',

    chld => [$NUM,$CLIST],

  };

# ---   *   ---   *   ---
# ^combo

  Readonly my $PTR_DECL=>{

    name => 'ptr_decl',

    fn   => 'ptr_decl',
    dom  => 'Grammar::peso',

    chld => [

      $FULL_TYPE,

      $NLIST,
      $VLIST,

      $TERM

    ],

  };

# ---   *   ---   *   ---
# global state

  our $Top;

# ---   *   ---   *   ---
# converts all numerical
# notations to decimal

sub rdnum($tree,$match) {

  state %converter=(

    hexn=>\&Lang::pehexnc,
    octn=>\&Lang::peoctnc,
    binn=>\&Lang::pebinnc,

  );

  for my $type(keys %converter) {

    my $fn=$converter{$type};

    map {

      $ARG->{value}=$fn->(
        $ARG->{value}

      );

    } $match->branches_in(
      $REGEX->{$type}

    );

  };

};

# ---   *   ---   *   ---
# turns trees with the structure:
#
# ($match)
# \-->subtype
# .  \-->value
#
# into:
#
# ($match)
# \-->value

sub list_flatten($tree,$match) {

  for my $branch(@{$match->{leaves}}) {
    $branch->flatten_branch();

  };

};

# ---   *   ---   *   ---
# pushes declarations to reg

sub utype_decl($tree,$match) {

  # get context
  my $f    = $tree->{ctx}->{frame};
  my $name = $match->leaf_value(-1);

  $f->{-creg}=$name;

};

# ---   *   ---   *   ---
# decl errme

sub throw_invalid_scope(@names) {

  my $s=join q[,],map {'%s'} @names;

  errout(

    q[No valid container for decls ]."<$s>",

    args => [@names],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# pushes constructors to current namespace

sub ptr_decl($tree,$match) {

  # get context
  my $f      = $tree->{ctx}->{frame};
  my $st     = $match->bhash(1,1,1);

  # ^unpack
  my $type   = shift @{$st->{type}};
  my @specs  = @{$st->{type}};
  my @names  = @{$st->{vnames}};
  my @values = @{$st->{'values'}};

  my @path;

  # errchk
  throw_invalid_scope(@names)
  if !$f->{-creg} && !$f->{-cproc};

  # build namespace path
  if(defined $f->{-cproc}) {

    @path=(
      $f->{-cclan},'procs',
      $f->{-cproc},'stk:$00'

    );

  } else {

    @path=(
      $f->{-cclan},'regs',
      $f->{-creg}

    );

  };

  # enforce zero as default value
  for my $i(0..$#names) {
    $values[$i]//=0;

  };

  # push decls to namespace
  while(@names && @values) {

    my $name  = shift @names;
    my $value = shift @values;

    my $o     = {

      type  => $type,
      flags => \@specs,

      value => $value,

    };

    $tree->{ctx}->ns_decl($o,@path,$name);

  };

};

# ---   *   ---   *   ---
# test

  Grammar::peso->mkrules($UTYPE_DECL,$PTR_DECL);

  my $t=Grammar::peso->parse(q[

reg vars;
  byte x $00;
  byte y $10;

  ]);

  use Fmat;
  fatdump($t->{ctx}->{frame}->{-ns});


# ---   *   ---   *   ---
1; # ret
