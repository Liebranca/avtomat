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

  use Arstd::Array;
  use Arstd::IO;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/avtomat/hacks/';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/avtomat/';

  use Lang;
  use parent 'Grammar';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) { return {

    -creg   => undef,
    -cclan  => 'non',
    -cproc  => undef,

    %{Grammar->Frame_Vars()},

    -passes => ['_ctx'],

  }};

  Readonly my $PE_FLAGS=>{

    -qwor   => 0,
    -insens => 0,
    -escape => 0,
    -sigws  => 0,

  };

  Readonly my $REGEX=>{

    hexn  => qr{\$  [0-9A-Fa-f\.:]+}x,
    octn  => qr{\\ [0-7\.:]+}x,
    binn  => qr{0b  [0-1\.:]+}x,
    decn  => qr{[0-9\.:]+}x,

    term  => Lang::nonscap(q[;]),
    sep   => Lang::nonscap(q[,]),
    lcom  => Lang::eaf(q[\#]),

    nsop  => qr{::},

# ---   *   ---   *   ---

    nonterm=>Lang::nonscap(

      q[;],

      negate => 1,
      mod    => '+',
      sigws  => 1,

    ),

    sigil=>Lang::eiths(

      [qw(

        $ $: $:% $:/

        %% % / // @

        * : -- - ++ + ^ &

        >> >>: << <<:

        |> &>

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

    chld => [

      $SIGIL,

      {%$NONTERM,opt=>1},
      $TERM

    ],

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

  };

  Readonly my $SPECS=>{

    name  => 'specs',
    greed => 1,

    chld  => [$SPEC],

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
      name => $REGEX->{hier},
      fn   => 'capt',

    }],

  };

  Readonly my $HIER=>{

    name => 'hier',

    fn   => 'hier_sort',
    dom  => 'Grammar::peso',

    chld => [

      {
        name => 'spec',
        opt  => 1,

        chld => [$SPEC],

      },

      $THIER,

      {
        name => 'name',
        chld => [$BARE],

      },

      $TERM

    ],

  };

# ---   *   ---   *   ---
# ^patterns for declaring members

  Readonly my $FULL_TYPE=>{

    name => 'type',
    chld => [

      $TYPE,
      {%$SPECS,opt=>1},

    ],

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
      {%$VLIST,opt=>1},

      $TERM

    ],

  };

# ---   *   ---   *   ---
# proc input

  Readonly my $PE_INPUT=>{

    name => 'input',

    fn   => 'rdin',
    dom  => 'Grammar::peso',

    chld => [

      {name=>qr{in}},
      $PTR_DECL,

    ]

  };

# ---   *   ---   *   ---
# special definitions

  Readonly my $SVARS=>{

    name => 'name',

    chld=>[{
      name => Lang::eiths(

        [qw(VERSION AUTHOR ENTRY)],
        -insens=>1,

      ),

      fn   => 'capt',

    }],

  };

  Readonly my $SDEFS=>{

    name => 'sdef',

    fn   => 'sasg',
    dom  => 'Grammar::peso',

    chld => [$SVARS,$NONTERM,$TERM],

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
# test

  Readonly my $MATCH=>{

    name => 'match',

    fn   => 'mtest',
    dom  => 'Grammar::peso',

    chld => [

      {name=>qr{match}},

      $STR,
      {name=>$REGEX->{sep}},

      $NONTERM,

    ],

  };

# ---   *   ---   *   ---
# pop current block

  Readonly my $RET=>{

    name  => 'ret',
    dom   => 'Grammar::peso',

    chld  => [

      {name=>'nid',chld=>[{

        name => Lang::eiths(
          [qw(ret)],
          -insens=>1

        ),

        fn   => 'capt',

      }]},

      {%$NONTERM,opt=>1},
      $TERM

    ],

  };

# ---   *   ---   *   ---

sub ret_ctx($match) {

  my ($tree,$cutx,$f)=get_ctx($match);
  ns_path($f,-ret=>1);

};

# ---   *   ---   *   ---

  Readonly my $FCALL=>{

    name=>'fcall',
    chld=>[
      $MATCH

    ],

  };

  Readonly my $FC_OR_V=>{

    name => 'fc_or_v',

    dom  => 'Grammar::peso',
    fn   => 'fc_or_v',

    chld => [

      $FCALL,$Grammar::OR,
      $VALUE

    ],

  };

# ---   *   ---   *   ---
# wat

sub fc_or_v($match) {

  my $par=$match->{parent};

  for my $nd(@{$match->{leaves}}) {
    $match->pluck($nd) if !$nd->{mfull};

  };

  my $type=\($match->{leaves}->[0]->{value});

  if($$type eq 'value') {
    $match=$match->flatten_branch();

  } else {

  };

  $match=$match->flatten_branch();
  $match->{value}='eval';

};

# ---   *   ---   *   ---

  Readonly my $COND_BEG=>{

    name  => 'branch_beg',

    dom   => 'Grammar::peso',
    fn    => 'cond_beg',

    chld  => [

      {

        name=>'nid',chld=>[{

          name => Lang::eiths(

            [qw(on or)],

            brwap  => 1,
            insens => 1,

          ),

          fn   => 'capt',

        }],

      },

      $FC_OR_V,
      $TERM

    ],

  };

# ---   *   ---   *   ---

  Readonly my $COND_END=>{

    name  => 'branch_end',

    dom   => 'Grammar::peso',
#    fn    => 'cond_end',

    chld  => [

      {

        name=>'nid',chld=>[{

          name => Lang::eiths(

            [qw(off)],

            brwap  => 1,
            insens => 1,

          ),

          fn   => 'capt',

        }],

      },

      $TERM

    ],

  };

# ---   *   ---   *   ---

sub cond_beg_ctx($match) {

  my $idex  = $match->{idex};
  my $depth = 0;

  my @lv    = @{$match->{parent}->{leaves}};
  @lv       = @lv[$idex+1..$#lv];

  $idex     = 0;

  for my $nd(@lv) {

    if($nd->{value} eq 'branch_end') {
      $depth--;

    } elsif($nd->{value} eq 'branch_beg') {
      $depth++;

    };

    last if $depth<0;
    $idex++;

  };

  @lv=@lv[0..$idex-1];
  $match->{-pest}=$match->bhash();

  $match->pluck($match->branches_in(
    qr{^nid|eval$}

  ));

  $match->pushlv(@lv);

};

# ---   *   ---   *   ---

sub mtest($match) {

return;
  my ($tree,$ctx,$f)=get_ctx($match);

  my $st     = $match->bhash(0,0,0);
  my @path   = ns_path($f);

  my $o      = $st->{nterm};
  my $qwor   = $ctx->ns_get(@path,'-qwor');
  my $sigws  = $ctx->ns_get(@path,'-sigws');
  my $insens = $ctx->ns_get(@path,'-insens');
  my $escape = $ctx->ns_get(@path,'-escape');

  $o         = detag($o,$ctx,@path);

  my $s=$st->{str};
  $s=~ s[^"|"$][]sxmg;

say $s,q[ ],$o;

  say int($s=~ $o);
  exit;

};

# ---   *   ---   *   ---
# global state

  our $Top;

# ---   *   ---   *   ---
# repeat offenders

sub get_ctx($match) {
  my ($tree) = $match->root();
  my $ctx    = $tree->{ctx};
  my $f      = $ctx->{frame};

  return ($tree,$ctx,$f);

};

# ---   *   ---   *   ---
# placeholder for file header

sub rdhed($match) {

};

# ---   *   ---   *   ---
# reads input lines

sub rdin($match) {
#  $match->prich();

};

# ---   *   ---   *   ---

sub detag($o,$ctx,@path) {

  state $RETAG_RE=qr{

    (?: (?!< \\\\) <)
    ((?: [^>]|\\\\>)+)
    (?: (?!< \\\\) >)

  }x;

  my @tags=();

  while($o=~ s[$RETAG_RE][$Shwl::PL_CUT]) {

    my @ar=split q[\|],$1;

    for my $name(@ar) {

      my @npath = split $REGEX->{nsop},$name;
      $name     = pop @npath;

      push @npath,'re',$name;

      my @rpath=$ctx->ns_search(

        (join q[::],@npath),

        $REGEX->{nsop},
        @path,'re'

      );

      $name=$ctx->ns_get(@rpath);

    };

    push @tags,(join q[|],@ar);

  };

  for my $x(@tags) {
    $o=~ s[$Shwl::PL_CUT_RE][$x];

  };

  return $o;

};

# ---   *   ---   *   ---
# interprets regex definitions

sub rdre_ctx($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

  my $st     = $match->bhash(0,0,0);
  my @path   = ns_path($f);

  my $o      = $st->{nterm};
  my $qwor   = $ctx->ns_get(@path,'-qwor');
  my $sigws  = $ctx->ns_get(@path,'-sigws');
  my $insens = $ctx->ns_get(@path,'-insens');
  my $escape = $ctx->ns_get(@path,'-escape');

  $o         = detag($o,$ctx,@path);

  if(!$sigws) {
    $o=~ s[[\s\n]+][ ]sxmg;

  };

  if($qwor) {

    my @ar=split $SPACE_RE,$o;
    array_filter(\@ar);

    $o=Lang::eiths(
      \@ar,

      escape=>$escape,
      insens=>$insens

    );

  };

  $o=(!$sigws) ? qr{$o}x : qr{$o};

  $ctx->ns_decl(

    $o,

    @path,
    $st->{type},
    $st->{seal}

  );

};

# ---   *   ---   *   ---
# placeholder for special defs

sub sasg_ctx($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

  my $st     = $match->bhash(0,0);
  my @path   = ns_path($f);

  $ctx->ns_asg(
    $st->{nterm},

    @path,
    $st->{name}

  );

};

# ---   *   ---   *   ---
# turns you on and off

sub switch_ctx($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

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
# preprocesses hierarchicals


sub hier_sort($match) {

  Tree::Grammar::list_flatten(
    $match->branch_in(qr{^name$})

  );

  my ($type)=$match->pluck(
    $match->branch_in(qr{^type$})

  );

  $match->{value}=$type->leaf_value(0);

  my $st=$match->bhash(1,0);
  $match->{-pest}=$st;

  $match->clear_branches();

};

# ---   *   ---   *   ---
# forks accto hierarchical type

sub hier_sort_ctx($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

  my $type    = $match->{value};
  my $ckey    = q[-c].(lc $type);
  my $st      = $match->{-pest};

  $f->{$ckey} = $st->{name};

  if($type eq 'ROM') {
    $f->{-creg}=undef;
    $f->{-cproc}=undef;

    $type=q[REG|ROM];

  } elsif($type eq 'REG') {
    $f->{-crom}=undef;
    $f->{-cproc}=undef;

    $type=q[REG|ROM];

  } elsif($type eq 'CLAN') {
    $f->{-creg}=undef;
    $f->{-crom}=undef;
    $f->{-cproc}=undef;

  };

  for my $key(keys %$PE_FLAGS) {

    my $value=$PE_FLAGS->{$key};

    $tree->{ctx}->ns_asg(
      $value,ns_path($f),$key

    );

  };

  my @chld=$match->{parent}->match_until(
    $match,qr{^$type$}

  );

  @chld=$match->{parent}->all_from(
    $match

  ) if !@chld;

  $match->pushlv(@chld);

};

# ---   *   ---   *   ---
# decl errme

sub throw_invalid_scope($names,@path) {

  my $p=(@path) ? join q[/],@path : $NULLSTR;
  my $s=join q[,],map {$p.'/%s'} @$names;

  errout(

    q[No valid container for decls ]."<$s>",

    args => [@$names],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---

sub ns_ret($f) {

  if(defined $f->{-cproc}) {
    $f->{-cproc}=undef;

  } elsif(defined $f->{-crom}) {
    $f->{-crom}=undef;

  } elsif(defined $f->{-creg}) {
    $f->{-creg}=undef;

  } else {
    $f->{-cclan}='non';

  };

};

# ---   *   ---   *   ---
# builds namespace path

sub ns_path($f,%O) {

  # defaults
  $O{-ret}//=0;

  my @out=();

  if(defined $f->{-cproc}) {

    my $ckey=(defined $f->{-crom})
      ? q[rom]
      : q[reg]
      ;


    my @ptr=(
      $ckey.'s',
      $f->{q[-c].$ckey},

    );

    @out=(
      $f->{-cclan},@ptr,'procs',
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

  } else {

    @out=(
      $f->{-cclan},'$DEF'

    );

  };

  ns_ret($f) if $O{-ret};

  return @out;

};

# ---   *   ---   *   ---
# pushes constructors to current namespace

sub ptr_decl($match) {

  Tree::Grammar::list_flatten(
    $match->branch_in(qr{^names$})

  );

  Tree::Grammar::nest_flatten(
    $match,'value'

  );

  $match->branch_in(
    qr{^specs$}

  )->flatten_branch();

};

# ---   *   ---   *   ---
# ^call made when executing tree

sub ptr_decl_ctx($match) {


  my ($tree,$ctx,$f)=get_ctx($match);

  # ^unpack
  my $st     = $match->bhash(1,1,1);
  my $type   = shift @{$st->{type}};
  my @specs  = @{$st->{type}};
  my @names  = @{$st->{names}};
  my @values = @{$st->{'values'}};

  my @path   = ns_path($f);

  # errchk
  throw_invalid_scope(\@names,@path)
  if !$f->{-crom}
  && !$f->{-creg}
  && !$f->{-cproc}
  ;

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

    $ctx->ns_decl($o,@path,$name);

  };

};

# ---   *   ---   *   ---
# test

  Grammar::peso->mkrules(

    $HEADER,
    $COMMENT,
    $MATCH,

    $SDEFS,
    $SWITCH,

    $HIER,
    $PTR_DECL,
    $PE_INPUT,

    $RE,
    $RET,

    $COND_BEG,
    $COND_END,

  );

  my $src  = $ARGV[0];
     $src//= 'lps/peso.rom';

  my $prog = orc($src);

  $prog    =~ m[([\S\s]+)\s*STOP]x;
  $prog    = ${^CAPTURE[0]};

  my $t    = Grammar::peso->parse($prog,-r=>1);

  $t->prich();
#  fatdump($t->{ctx}->{frame}->{-ns});

# ---   *   ---   *   ---
1; # ret
