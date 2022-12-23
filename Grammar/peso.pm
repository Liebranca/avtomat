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
  use Fmat;

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

    nonterm => Lang::nonscap(

      q[;],

      negate => 1,
      mod    => '+',

    ),

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

    bare=>qr{

      [_A-Za-z][_A-Za-z0-9:\.]*

    }x,

    seal=>qr{

      [_A-Za-z<]
      [_A-Za-z0-9:\-\.]+

      [_A-Za-z>]

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

    name => 'sigil',

    chld => [{
      name => $REGEX->{sigil},
      fn   => 'capt',

    }],

  };

  Readonly my $NONTERM=>{

    name => 'nterm',

    chld => [{
      name => $REGEX->{nonterm},
      fn   => 'capt',

    }],

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

  Readonly my $BARE=>{

    name => 'bare',

    chld => [{
      name => $REGEX->{bare},
      fn   => 'capt',

    }],

  };

  Readonly my $SEAL=>{

    name => 'seal',

    chld => [{
      name => $REGEX->{seal},
      fn   => 'capt',

    }],

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
# soul of perl!

  Readonly my $FLG=>{

    name => 'flg',

    chld => [

      $SIGIL,

      $BARE,$Grammar::OR,
      $SEAL

    ],

  };

  Readonly my $FLIST=>{
    name => 'flags',
    chld => [$FLG,$CLIST],

  };

# ---   *   ---   *   ---
# all non-bare

  Readonly my $VALUE=>{

    name => 'value',
    chld => [

      $NUM,$Grammar::OR,
      $STR,$Grammar::OR,

      $FLG

    ],

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
        chld=>[$BARE],

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
    name => 'names',
    chld => [$BARE,$CLIST],

  };

  Readonly my $VLIST=>{
    name => 'values',
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
# switch flips

  Readonly my $WED=>{

    name => 'type',
    chld => [{

      name => Lang::eiths(
        [qw(wed unwed)],
        insens=>1,

      ),

      fn   => 'capt',

    }],

  };

  Readonly my $SWITCH=>{

    name => 'switch',

    fn   => 'switch',
    dom  => 'Grammar::peso',

    chld => [$WED,$FLIST,$TERM],

  };

# ---   *   ---   *   ---
# regex definitions

  Readonly my $RETYPE=>{

    name => 'type',

    chld =>[{
      name => Lang::insens('re',mkre=>1),
      fn   => 'capt',

    }],

  };

  Readonly my $RE=>{

    name => 're',

    fn   => 'rdre',
    dom  => 'Grammar::peso',

    chld => [

      $RETYPE,

      $SEAL,
      $NONTERM,
      $TERM

    ],

  };

# ---   *   ---   *   ---
# global state

  our $Top;

# ---   *   ---   *   ---
# placeholder for file header

sub rdhed($match) {

};

# ---   *   ---   *   ---
# interprets regex definitions

sub rdre($match) {

  my ($tree) = $match->root();
  my $ctx    = $tree->{ctx};
  my $f      = $ctx->{frame};

  my $st     = $match->bhash(0,0,0);
  my @path   = ns_path($f);

  my $o      = $st->{nterm};
  my $qwor   = $ctx->ns_get(@path,'-qwor');
  my $sigws  = $ctx->ns_get(@path,'-sigws');

  if(!$sigws) {
    $o=~ s[\s+][ ]sxmg;

  };

  if($qwor) {
    $o=~ s[\s][|]sxmg;

  };

  $ctx->ns_decl(

    qr{$o},

    @path,
    $st->{type},
    $st->{seal}

  );

};

# ---   *   ---   *   ---
# placeholder for special defs

sub sasg($match) {

  my $v=$match->branch_in(qr{^value$});

  for my $branch(@{$v->{leaves}}) {
    $v->pluck($branch)
    if !@{$branch->{leaves}};

  };

  list_flatten($v);

};

# ---   *   ---   *   ---
# turns you on and off

sub switch($match) {

  my ($tree) = $match->root();
  my $f      = $tree->{ctx}->{frame};

  my @path   = ns_path($f);

  my $type=uc $match->branch_in(
    qr{^type$}

  )->leaf_value(0);

  my $flags=$match->branch_in(
    qr{^flags$}

  );

  my $value=int($type eq 'WED');

  for my $branch(@{$flags->{leaves}}) {

    my $h    = $branch->bhash(0,0);
    my $name = $h->{sigil}.$h->{bare};

    $tree->{ctx}->ns_asg(
      $value,@path,$name

    );

  };

};

# ---   *   ---   *   ---
# converts all numerical
# notations to decimal

sub rdnum($match) {

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

sub hier_sort($match) {

  my ($tree)  = $match->root();
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

sub list_flatten($match) {

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
#;

sub nest_flatten($match,$pat) {

  for my $branch(
    $match->branches_in(qr{^$pat$})

  ) {

    list_flatten($branch);
    $branch->flatten_branch();

  };

};

# ---   *   ---   *   ---
# builds namespace path

sub ns_path($f) {

  my @out=();

  if(defined $f->{-cproc}) {

    @out=(
      $f->{-cclan},'procs',
      $f->{-cproc},'stk:$00'

    );

  } elsif(defined $f->{-crom}) {

    @out=(
      $f->{-cclan},'roms',
      $f->{-crom}

    );

  } elsif(defined $f->{-creg}) {

    @out=(
      $f->{-cclan},'regs',
      $f->{-creg}

    );

  };

  return @out;

};

# ---   *   ---   *   ---
# pushes constructors to current namespace

sub ptr_decl($match) {

  # get context
  my ($tree) = $match->root();
  my $f      = $tree->{ctx}->{frame};

  list_flatten($match->branch_in(qr{^names$}));
  nest_flatten($match,'value');

  my $st     = $match->bhash(1,1,1);

  # ^unpack
  my $type   = shift @{$st->{type}};
  my @specs  = @{$st->{type}};
  my @names  = @{$st->{names}};
  my @values = @{$st->{'values'}};

  # errchk
  throw_invalid_scope(@names)
  if !$f->{-crom} && !$f->{-creg} && !$f->{-cproc};

  my @path=ns_path($f);

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
    $SWITCH,

    $HIER,
    $PTR_DECL,

    $RE,

  );

  my $prog = orc('plps/peso.rom');
  $prog    =~ m[([\S\s]+)\s*STOP]x;
  $prog    = ${^CAPTURE[0]};

  my $t    = Grammar::peso->parse($prog);

  $t->prich();

  fatdump($t->{ctx}->{frame}->{-ns});


# ---   *   ---   *   ---
1; # ret
