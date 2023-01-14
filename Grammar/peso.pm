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
  use Chk;
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

  our $VERSION = v0.00.6;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) { return {

    -creg   => undef,
    -cclan  => 'non',
    -cproc  => undef,

    %{Grammar->Frame_Vars()},

    -passes => ['_ctx','_opz','_run'],

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

        %% %

        / // /: //:
        @ @:

        * : -- - ++ + ^ &

        >> >>: << <<:

        |> &>

      )],

      escape=>1

    ),

    ops=>Lang::eiths(

      [qw(

        -> *^ * % / ++ + -- -
        ?? ? !! ~ >> > >= | & ^

        << < <=  || && == !=

        ~=

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

  Readonly my $NTERM=>{

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

      {%$NTERM,opt=>1},
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

    name => 'qstr',

    fn   => 'qstr',
    dom  => 'Grammar::peso',

    chld => [{

      name => qr{"([^"]|\\")*?"},
      fn   => 'capt',

    }],

  };

# ---   *   ---   *   ---
# ^rough ipret

sub qstr($match) {
  $match->{value}=eval($match->leaf_value(0));
  $match->clear_branches();

};

# ---   *   ---   *   ---

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

    dom  => 'Grammar::peso',
    fn   => 'flg',

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
# ^post-parse

sub flg($match) {

  my $st   = $match->bhash();
  my $type = (exists $st->{seal})
    ? 'seal'
    : 'bare'
    ;

  $match->{value}={

    sigil => $st->{sigil},
    name  => $st->{$type},

    type  => $type,

  };

  $match->clear_branches();

};

# ---   *   ---   *   ---
# all non-bare

  Readonly my $VALUE=>{

    name => 'value',

    dom  => 'Grammar::peso',
    fn   => 'value_sort',

    chld => [

      $NUM,$Grammar::OR,
      $STR,$Grammar::OR,

      $FLG,$Grammar::OR,

      $BARE

    ],

  };

# ---   *   ---   *   ---
# ^handler

sub value_sort($match) {

  my $st     = $match->bhash();
  my ($type) = keys %$st;

  $match->{value}=$st->{$type};
  $match->clear_branches();

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
# reads input lines

sub rdin_opz($match) {

  my $h=$match->leaf_value(0);

  $match->{value}=$h;
  $match->clear_branches();

};

sub rdin_run($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

  for my $ptr(@{$match->{value}}) {
    $$ptr->{value}=$ctx->{mach}->stkpop();

  };

};

# ---   *   ---   *   ---
# soul of perl v2.0

  Readonly my $VGLOB=>{

    name=>'vglob',
    chld=>[

      {name=>qr[\{]},
      $FLG,

      {name=>qr[\}]},

    ],

  };

# ---   *   ---   *   ---
# aliasing

  Readonly my $LIS=>{

    name => 'lis',

    dom  => 'Grammar::peso',
    fn   => 'lis',

    chld => [

      {name=>qr{lis}},

      $VGLOB,
      $NTERM

    ],

  };

# ---   *   ---   *   ---
# ^post-parse

sub lis($match) {

  my $st=$match->bhash();

  $match->{value}={

    from => $st->{nterm},
    to   => $st->{vglob},

  };

  $match->clear_branches();

};

# ---   *   ---   *   ---
# ^context build

sub lis_ctx($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

  my $st   = $match->{value};
  my @path = $ctx->ns_path();

  my $key  = $st->{to};
  $key     = "$key->{sigil}$key->{name}";

  $ctx->ns_decl(
    $st->{from},
    @path,q[$LIS],$key

  );

};

# ---   *   ---   *   ---
# buffered IO

  Readonly my $SOW=>{

    name => 'sow',

    fn   => 'sow',
    dom  => 'Grammar::peso',

    chld => [

      {name=>qr{sow}},

      $VGLOB,
      $VLIST,

    ]

  };

  Readonly my $REAP=>{

    name => 'reap',

    fn   => 'reap',
    dom  => 'Grammar::peso',

    chld => [

      {name=>qr{reap}},
      $VGLOB,

    ]

  };

# ---   *   ---   *   ---
# ^post-parse

sub sow($match) {

  my $lv=$match->{leaves};
  my @ar=$lv->[1]->branch_values();

  $match->{value}={

    fd => $lv->[0]->leaf_value(0),
    me => \@ar,

  };

  $match->clear_branches();

};

sub reap($match) {

  my $lv=$match->{leaves};

  $match->{value}=$lv->[0]->leaf_value(0);
  $match->clear_branches();

};

# ---   *   ---   *   ---
# ^bind values

sub sow_opz($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

  my $st   = $match->{value};
  my @path = $ctx->ns_path();

  my $fd   = $st->{fd};

  $st->{fd}="$fd->{sigil}$fd->{name}";

  $ctx->array_vex(0,$st->{me},@path);
  $ctx->vex(0,\$st->{fd},@path);

  my ($fd2,$buff)=$ctx->{mach}->fd_solve($st->{fd});

};

sub reap_opz($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

  my @path = $ctx->ns_path();
  my $fd   = $match->{value};

  $match->{value}="$fd->{sigil}$fd->{name}";
  $ctx->vex(0,\$match->{value},@path);

};

# ---   *   ---   *   ---
# ^exec

sub sow_run($match) {

  my ($tree,$ctx,$f)=get_ctx($match);
  my $s=$NULLSTR;

  for my $v(@{$match->{value}->{me}}) {

    my $deref=(is_hashref($v))
      ? $v->{value}
      : $v
      ;

    $s.=$deref;

  };

  $ctx->{mach}->sow(
    $match->{value}->{fd},$s

  );

};

sub reap_run($match) {

  my ($tree,$ctx,$f)=get_ctx($match);
  my $fh=$match->{value};

  $ctx->{mach}->reap($fh);

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

    chld => [$SVARS,$NTERM,$TERM],

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
      $NTERM,
      $TERM

    ],

  };

# ---   *   ---   *   ---
# test

  Readonly my $OPERATOR=>{

    name => 'op',

    chld => [{

      name => $REGEX->{ops},
      fn   => 'capt',

    }],

  };

  Readonly my $MATCH=>{

    name => 'match',

    fn   => 'mtest',
    dom  => 'Grammar::peso',

    chld => [

      $VALUE,
      {name=>qr{~=}},

      $NTERM,
      $TERM

    ],

  };

# ---   *   ---   *   ---

sub mtest_ctx($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

  my $st     = $match->bhash(0,0);
  my @path   = $ctx->ns_path();

  my $o      = detag($st->{nterm},$ctx,@path);
  my $nterm  = $match->branch_in(qr{^nterm$});

  my $lv     = $match->{leaves};

  my $v      = $ctx->ns_get(

    @path,
    $lv->[0]->{value}

  );

  $match->{value}={

    re => $o,
    v  => $v,

  };

  $match->clear_branches();

};

# ---   *   ---   *   ---
# ^exec

sub mtest_run($match) {

  my $st = $match->{value};

  my $v  = $st->{v}->{value};
  my $re = $st->{re};

  return int($v=~ $re);

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

      {%$NTERM,opt=>1},
      $TERM

    ],

  };

# ---   *   ---   *   ---

sub ret_ctx($match) {

  my ($tree,$ctx,$f)=get_ctx($match);
  $ctx->ns_path(-ret=>1);

};

# ---   *   ---   *   ---
# procedure calls

  Readonly my $CALL=>{

    name => 'call',

    dom  => 'Grammar::peso',
    fn   => 'call',

    chld => [

      {name=>qr{call}},

      $VALUE,

      $VLIST,
      $TERM,

    ],

  };

# ---   *   ---   *   ---
# ^post-parse

sub call($match) {

  my $lv   = $match->{leaves};

  my $fn   = $lv->[0]->{value};
  my @args = $lv->[1]->branch_values();

  $match->clear_branches();

  $match->{value}={
    fn   => [(split $REGEX->{nsop},$fn)],
    args => \@args,

  };

};

# ---   *   ---   *   ---
# ^optimize

sub call_opz($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

  my $st    = $match->{value};
  my @path  = $ctx->ns_path();

  my @rpath = $ctx->ns_search(

    (join q[::],@{$st->{fn}}),

    $REGEX->{nsop},
    @path

  );

  $st->{fn}=$ctx->ns_get(
    @rpath,q[$branch]

  );

  for my $arg(@{$st->{args}}) {
    next if !($arg=~ $REGEX->{bare});
    $ctx->ns_cderef(1,$REGEX->{nsop},\$arg,@path);

  };

};

# ---   *   ---   *   ---
# ^exec

sub call_run($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

  my $st   = $match->{value};

  my $fn   = $st->{fn};
  my @args = @{$st->{args}};

  for my $arg(reverse @args) {
    $ctx->{mach}->stkpush($arg);

  };

  unshift @{$ctx->{callstk}},
    $fn->shift_branch(keepx=>1);

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

sub cond_beg_run($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

  my $st=$match->{-pest};
  my $ev=$st->{eval};

  my $ok=0;

  for my $nd(@{$ev->{leaves}}) {
    $ok|=$nd->{chain}->[-1]->($nd);

  };

  if(!$ok) {

    my $callstk = $ctx->{callstk};
    my $size    = @{$match->{leaves}};

    for(0..$size-1) {
      shift @$callstk;

    };

  };

};

# ---   *   ---   *   ---
# repeat offenders

sub get_ctx($match) {
  my ($tree) = $match->root();
  my $ctx    = $tree->{ctx};
  my $f      = $ctx->{frame};

  return ($tree,$ctx,$f);

};

# ---   *   ---   *   ---
# value expansion

sub vex($ctx,$fet,$vref,@path) {

  $ctx->ns_cderef(
    $fet,$REGEX->{nsop},$vref,@path,q[$LIS]

  ) or $ctx->ns_cderef(
    $fet,$REGEX->{nsop},$vref,@path

  );

};

sub array_vex($ctx,$fet,$ar,@path) {

  for my $v(@$ar) {
    vex($ctx,$fet,\$v,@path);

  };

};

# ---   *   ---   *   ---
# placeholder for file header

sub rdhed($match) {

};

# ---   *   ---   *   ---
# errme for getting an undefined value

sub throw_undef_get(@path) {

  my $path=join q[::],@path;

  errout(

    q[<%s> is undefined],

    args => [$path],
    lvl  => $AR_FATAL,

  );

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

      # proc scope walkback
      if(

         is_hashref($name)
      && defined $ctx->{frame}->{-cproc}

      ) {

        @npath=@rpath[-2..-1];
        @rpath=(@rpath[0..1],@npath);

        $name=$ctx->ns_get(@rpath);

      };

      throw_undef_get(@rpath)
      if(is_hashref($name));

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
  my @path   = $ctx->ns_path();

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
  my @path   = $ctx->ns_path();

  if(uc $st->{name} eq 'ENTRY') {
    $st->{nterm}=[split q[::],$st->{nterm}];

  };

  $ctx->ns_asg(
    $st->{nterm},

    @path,
    $st->{name}

  );

};

# ---   *   ---   *   ---
# turns you on and off

sub switch($match) {

  my $st=$match->bhash(0,1);

  $match->{value}={

    type  => uc $st->{type},
    flags => $st->{flags},

  };

  $match->clear_branches();

};

sub switch_ctx($match) {

  my ($tree,$ctx,$f)=get_ctx($match);

  my $st   = $match->{value};
  my @path = $ctx->ns_path();

  my $value=int($st->{type} eq 'WED');

  for my $f(@{$st->{flags}}) {

    my $fname=$f->{sigil}.$f->{name};

    $tree->{ctx}->ns_asg(
      $value,@path,$fname

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

  my @path=$ctx->ns_path();

  for my $key(keys %$PE_FLAGS) {
    my $value=$PE_FLAGS->{$key};
    $ctx->ns_asg($value,@path,$key);

  };

  my @chld=$match->{parent}->match_until(
    $match,qr{^$type$}

  );

  @chld=$match->{parent}->all_from(
    $match

  ) if !@chld;

  $match->pushlv(@chld);

  @path=grep {$ARG ne '$DEF'} @path;
  $ctx->ns_mkbranch($match,@path);

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

sub ns_path($self,%O) {

  # defaults
  $O{-ret}//=0;

  my @out = ();
  my $f   = $self->{frame};

  if(defined $f->{-cproc}) {

    my $ckey=(defined $f->{-crom})
      ? q[-crom]
      : q[-creg]
      ;

    @out=(
      $f->{-cclan},$f->{$ckey},
      $f->{-cproc}

    );

  } elsif(defined $f->{-crom}) {
    @out=($f->{-cclan},$f->{-crom});

  } elsif(defined $f->{-creg}) {
    @out=($f->{-cclan},$f->{-creg});

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
    $match,'flg'

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

  my @path   = $ctx->ns_path();

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

  my $ptrs=[];

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

    push @$ptrs,$ctx->ns_fetch(@path,$name);

  };

  $match->clear_branches();
  $match->{value}=$ptrs;

};

# ---   *   ---   *   ---
# groups

  Readonly my $BLTN=>{

    name => 'bltn',
    fn   => 'clip',

    chld=>[

      { name => 'nid',
        fn   => 'clip',

        chld => [

          $LIS,$Grammar::OR,

          $SOW,$Grammar::OR,
          $REAP,

        ]

      },

      $TERM

    ],

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
    $PE_INPUT,

    $RE,
    $RET,

    $COND_BEG,
    $COND_END,

    $MATCH,
    $CALL,
    $BLTN,

  );

  my $src  = $ARGV[0];
     $src//= 'lps/peso.rom';

  my $prog = orc($src);

  $prog    =~ m[([\S\s]+)\s*STOP]x;
  $prog    = ${^CAPTURE[0]};

  my $t    = Grammar::peso->parse($prog,-r=>2);

#  $t->prich();
#  fatdump($t->{ctx}->{frame}->{-ns}->{peso});

  Grammar::peso->run(

    $t,

    entry=>1,
    keepx=>1,

    input=>[

      "HLOWRLD\n",

    ],

  );

# ---   *   ---   *   ---
1; # ret
