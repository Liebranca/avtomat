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

  our $VERSION = v0.00.4;
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

    term  => Lang::nonscap(q[;]),
    sep   => Lang::nonscap(q[,]),
    lcom  => Lang::eaf(q[\#]),

# ---   *   ---   *   ---

    nonterm => qr{[^;]*}x,
    sigil   => Lang::eiths(

      [qw(

        $ $: $:% $:/

        %% % / // @

        * : -- - ++ + ^ &

        >> >>: << <<:

        |>

      )],

      escape=>1

    ),

# ---   *   ---   *   ---

    vname=>qr{

      [_A-Za-z][_A-Za-z0-9:\.]*

    }x,

    hier=>Lang::eiths(

      [qw(reg rom clan proc)],

      bwrap  => 1,
      insens => 1,

    ),

# ---   *   ---   *   ---

    type=>Lang::eiths(

      [qw(

        byte wide brad word
        unit half line page

        nihil stark signal

      )],

      bwrap  => 1,
      insens => 1,

    ),

    spec=>Lang::eiths(

      [qw(ptr fptr str buf tab)],

      bwrap  => 1,
      insens => 1,

    ),

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

  Readonly my $LCOM=>{
    name => $REGEX->{lcom},

  };

  Readonly my $COMMENT=>{

    name => 'comment',
    fn   => 'discard',

    chld => [$LCOM],

  };

# ---   *   ---   *   ---
# pe file header

  Readonly my $SIGIL=>{
    name => $REGEX->{sigil},
    fn   => 'capt',

  };

  Readonly my $NONTERM=>{
    name => $REGEX->{nonterm},
    fn   => 'capt',

  };

  Readonly my $HEADER=>{

    name => 'header',

    fn   => 'rdhed',
    dom  => 'Grammar::peso',

    chld => [$SIGIL,$NONTERM,$TERM],

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
# string types

  Readonly my $QSTR=>{

    name => qr{"([^"]|\\")*?"},
    fn   => 'capt',

  };

  Readonly my $CSTR=>{

    name => qr{'([^']|\\')*?'},
    fn   => 'capt',

  };

  Readonly my $VSTR=>{

    name => qr{v[0-9]\.[0-9]{2}\.[0-9][ab]?},
    fn   => 'capt',

  };

# ---   *   ---   *   ---
# ^combo rule

  Readonly my $STR=>{

    name => 'str',
    chld => [

      $QSTR,$Grammar::OR,
      $CSTR,$Grammar::OR,
      $VSTR

    ],

  };

# ---   *   ---   *   ---
# all non-bare

  Readonly my $VALUE=>{

    name => 'value',
    chld => [

      $NUM,$Grammar::OR,
      $STR

    ],

  };

# ---   *   ---   *   ---
# common patterns

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
# entry point for all hierarchicals

  Readonly my $THIER=>{

    name => 'type',
    chld =>[{
      name =>$REGEX->{hier},
      fn   => 'capt',

    }],

  };

  Readonly my $HIER=>{

    name => 'hier',

    fn   => 'hier_sort',
    dom  => 'Grammar::peso',

    chld => [

      {
        name=>'spec',
        chld=>[$SPEC],

      },

      $THIER,

      {
        name=>'name',
        chld=>[$VNAME],

      },

      $TERM

    ],

  };

# ---   *   ---   *   ---
# ^patterns for declaring members

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

    chld => [$VALUE,$CLIST],

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
# special definitions

  Readonly my $SVARS=>{

    name => 'name',

    chld=>[{
      name => qr{VERSION|AUTHOR}x,
      fn   => 'capt',

    }],

  };

  Readonly my $SDEFS=>{

    name => 'sdef',

    fn   => 'sasg',
    dom  => 'Grammar::peso',

    chld => [$SVARS,$VALUE,$TERM],

  };

# ---   *   ---   *   ---
# global state

  our $Top;

# ---   *   ---   *   ---
# placeholder for file header

sub rdhed($tree,$match) {

};

# ---   *   ---   *   ---
# placeholder for special defs

sub sasg($tree,$match) {

  list_flatten(
    $tree,
    $match->branch_in(qr{^value$})

  );

};

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
# forks accto hierarchical type

sub hier_sort($tree,$match) {

  my $f       = $tree->{ctx}->{frame};
  my $st      = $match->bhash(1,0,0);

  my $ckey    = q[-c].(lc $st->{type});

  $f->{$ckey} = $st->{name};

  if($st->{type} eq 'ROM') {
    $f->{-creg}=undef;
    $f->{-cproc}=undef;

  } elsif($st->{type} eq 'REG') {
    $f->{-crom}=undef;
    $f->{-cproc}=undef;

  } elsif($st->{type} eq 'CLAN') {
    $f->{-creg}=undef;
    $f->{-crom}=undef;
    $f->{-cproc}=undef;

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
  if !$f->{-crom} && !$f->{-creg} && !$f->{-cproc};

  # build namespace path
  if(defined $f->{-cproc}) {

    @path=(
      $f->{-cclan},'procs',
      $f->{-cproc},'stk:$00'

    );

  } elsif(defined $f->{-crom}) {

    @path=(
      $f->{-cclan},'roms',
      $f->{-crom}

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

  Grammar::peso->mkrules(

    $HEADER,
    $COMMENT,

    $SDEFS,

    $HIER,
    $PTR_DECL

  );

  my $prog = orc('plps/peso.rom');
  $prog    =~ m[([\S\s]+)\s*STOP]x;
  $prog    = ${^CAPTURE[0]};

  my $t    = Grammar::peso->parse($prog);

  $t->prich();

  use Fmat;
  fatdump($t->{ctx}->{frame}->{-ns});


# ---   *   ---   *   ---
1; # ret
