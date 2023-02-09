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

package cvalue;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/avtomat/sys/';

  use Style;
  use Fmat;
  use parent 'St';

# ---   *   ---   *   ---

sub nit($class,%O) {
  my $self=bless {%O},$class;
  return $self;

};

sub deref($self) {
  return ($self->{sigil},$self->{name});

};

# ---   *   ---   *   ---

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

  our $VERSION = v0.00.7;#b
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

# ---   *   ---   *   ---

  Readonly our $PE_FLAGS=>{

    -qwor   => 0,
    -insens => 0,
    -escape => 0,
    -sigws  => 0,

  };

  Readonly our $REGEX=>{

    hexn  => qr{\$  [0-9A-Fa-f\.:]+}x,
    octn  => qr{\\ [0-7\.:]+}x,
    binn  => qr{0b  [0-1\.:]+}x,
    decn  => qr{[0-9\.:]+}x,

    term  => Lang::nonscap(q[;]),
    sep   => Lang::nonscap(q[,]),
    lcom  => Lang::eaf(q[\#]),

    nsop  => qr{::},

# ---   *   ---   *   ---

    nterm=>Lang::nonscap(

      q[;],

      iv     => 1,
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

# ---   *   ---   *   ---

    tag=>qr{

      (?: (?!< \\\\) <)
      ((?: [^>]|\\\\>)+)
      (?: (?!< \\\\) >)

    }x,

  };

# ---   *   ---   *   ---
# lets call these "syntax ops"

  Readonly our $CLIST=>{

    name => $REGEX->{sep},
    fn   => 'rew',

    opt  => 1,

  };

  Readonly our $TERM=>{
    name => $REGEX->{term},
    fn   => 'term',

  };

  Readonly our $LCOM=>{
    name => $REGEX->{lcom},

  };

  Readonly our $COMMENT=>{

    name => 'comment',
    fn   => 'discard',

    chld => [$LCOM],

  };

# ---   *   ---   *   ---
# pe file header

  Readonly our $SIGIL=>{

    name => 'sigil',

    chld => [{
      name => $REGEX->{sigil},
      fn   => 'capt',

    }],

  };

  Readonly our $NTERM=>{

    name => 'nterm',

    chld => [{
      name => $REGEX->{nterm},
      fn   => 'capt',

    }],

  };

  Readonly our $HEADER=>{

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

  Readonly our $HEX=>{
    name => $REGEX->{hexn},
    fn   => 'capt',

  };

  Readonly our $OCT=>{
    name => $REGEX->{octn},
    fn   => 'capt',

  };

  Readonly our $BIN=>{
    name => $REGEX->{binn},
    fn   => 'capt',

  };

  Readonly our $DEC=>{
    name => $REGEX->{decn},
    fn   => 'capt',

  };

# ---   *   ---   *   ---
# ^combined into a single rule

  Readonly our $NUM=>{

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

  Readonly our $TYPE=>{
    name => $REGEX->{type},
    fn   => 'capt',

  };

  Readonly our $SPEC=>{
    name => $REGEX->{spec},
    fn   => 'capt',

  };

  Readonly our $SPECS=>{

    name  => 'specs',
    greed => 1,

    chld  => [$SPEC],

  };

  Readonly our $BARE=>{

    name => 'bare',

    chld => [{
      name => $REGEX->{bare},
      fn   => 'capt',

    }],

  };

  Readonly our $SEAL=>{

    name => 'seal',

    chld => [{
      name => $REGEX->{seal},
      fn   => 'capt',

    }],

  };

# ---   *   ---   *   ---
# string types

  Readonly our $QSTR=>{

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

sub qstr($self,$branch) {
  $branch->{value}=eval($branch->leaf_value(0));
  $branch->clear_branches();

};

# ---   *   ---   *   ---

  Readonly our $CSTR=>{

    name => qr{'([^']|\\')*?'},
    fn   => 'capt',

  };

  Readonly our $VSTR=>{

    name => qr{v[0-9]\.[0-9]{2}\.[0-9][ab]?},
    fn   => 'capt',

  };

# ---   *   ---   *   ---
# ^combo rule

  Readonly our $STR=>{

    name => 'str',

    chld => [

      $QSTR,$Grammar::OR,
      $CSTR,$Grammar::OR,
      $VSTR

    ],

  };

# ---   *   ---   *   ---
# soul of perl!

  Readonly our $FLG=>{

    name => 'flg',

    dom  => 'Grammar::peso',
    fn   => 'flg',

    chld => [

      $SIGIL,{name=>'x',fn=>'clip',chld=>[

        $BARE,$Grammar::OR,
        $SEAL

      ]},

    ],

  };

  Readonly our $FLIST=>{
    name => 'flags',
    chld => [$FLG,$CLIST],

  };

# ---   *   ---   *   ---
# ^post-parse

sub flg($self,$branch) {

  my $st   = $branch->bhash();
  my $type = (exists $st->{seal})
    ? 'seal'
    : 'bare'
    ;

  $branch->{value}=cvalue->nit(

    sigil => $st->{sigil},
    name  => $st->{$type},

    type  => $type,

  );

};

# ---   *   ---   *   ---
# all non-bare

  Readonly our $VALUE=>{

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

sub value_sort($self,$branch) {

  my $st     = $branch->bhash();
  my ($type) = keys %$st;

  my $xx     = $branch->leaf_value(0);
  if(is_hashref($xx)) {
    $type=$xx;

  };

  $branch->clear_branches();

  $branch->init(

    (defined $st->{$type})
      ? $st->{$type}
      : $type,

  );

};

# ---   *   ---   *   ---
# entry point for all hierarchicals

  Readonly our $THIER=>{

    name => 'type',
    chld =>[{
      name => $REGEX->{hier},
      fn   => 'capt',

    }],

  };

  Readonly our $HIER=>{

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

  Readonly our $FULL_TYPE=>{

    name => 'type',
    chld => [

      $TYPE,
      {%$SPECS,opt=>1},

    ],

  };

  Readonly our $NLIST=>{
    name => 'names',
    chld => [$BARE,$CLIST],

  };

  Readonly our $VLIST=>{
    name => 'values',
    fn   => 'list_flatten',

    chld => [$VALUE,$CLIST],

  };

# ---   *   ---   *   ---
# ^combo

  Readonly our $PTR_DECL=>{

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

  Readonly our $PE_INPUT=>{

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

sub rdin_opz($self,$branch) {

  my $h=$branch->leaf_value(0);

  $branch->{value}=$h;
  $branch->clear_branches();

};

sub rdin_run($self,$branch) {

  for my $ptr(@{$branch->{value}}) {
    $$ptr->{value}=$self->{mach}->stkpop();

  };

};

# ---   *   ---   *   ---
# soul of perl v2.0

  Readonly our $VGLOB=>{

    name=>'vglob',
    chld=>[

      {name=>qr[\{]},
      $FLG,

      {name=>qr[\}]},

    ],

  };

# ---   *   ---   *   ---
# aliasing

  Readonly our $LIS=>{

    name => 'lis',

    dom  => 'Grammar::peso',
    fn   => 'lis',

    chld => [

      {name=>qr{lis}},

      $VGLOB,
      $VALUE

    ],

  };

# ---   *   ---   *   ---
# ^post-parse

sub lis($self,$branch) {

  my $st=$branch->bhash();

  $branch->{value}={

    from => $st->{value},
    to   => $st->{vglob}->leaf_value(0),

  };

  $branch->clear_branches();

};

# ---   *   ---   *   ---
# ^context build

sub lis_ctx($self,$branch) {

  my $st   = $branch->{value};

  my $mach = $self->{mach};
  my @path = $mach->{scope}->path();

  my $key  = $st->{to};
  $key     = "$key->{sigil}$key->{name}";

  $mach->{scope}->decl(
    $st->{from},
    @path,q[$LIS],$key

  );

};

# ---   *   ---   *   ---
# buffered IO

  Readonly our $SOW=>{

    name => 'sow',

    fn   => 'sow',
    dom  => 'Grammar::peso',

    chld => [

      {name=>qr{sow}},

      $VGLOB,
      $VLIST,

    ]

  };

  Readonly our $REAP=>{

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

sub sow($self,$branch) {

  my $lv=$branch->{leaves};
  my @ar=$lv->[1]->branch_values();

  $branch->{value}={

    fd => $lv->[0]->leaf_value(0),
    me => \@ar,

  };

  $branch->clear_branches();

};

sub reap($self,$branch) {

  my $lv=$branch->{leaves};

  $branch->{value}=$lv->[0]->leaf_value(0);
  $branch->clear_branches();

};

# ---   *   ---   *   ---
# ^bind values

sub sow_opz($self,$branch) {

  my $st   = $branch->{value};
  my $mach = $self->{mach};
  my @path = $mach->{scope}->path();

  my $fd   = $st->{fd};

  $st->{fd}="$fd->{sigil}$fd->{name}";

  $self->array_vex(0,$st->{me},@path);
  $self->vex(0,\$st->{fd},@path);

  my ($fd2,$buff)=$mach->fd_solve(
    $st->{fd}

  );

};

sub reap_opz($self,$branch) {

  my $mach = $self->{mach};
  my @path = $mach->{scope}->path();
  my $fd   = $branch->{value};

  $branch->{value}="$fd->{sigil}$fd->{name}";
  $self->vex(0,\$branch->{value},@path);

};

# ---   *   ---   *   ---
# ^exec

sub sow_run($self,$branch) {

  my $mach = $self->{mach};
  my $st   = $branch->{value};
  my $s    = $NULLSTR;

  my @path = $mach->{scope}->path();

  for my $v(@{$branch->{value}->{me}}) {

    my $deref;

    if(cvalue->is_valid($v)) {
      say 'IMPLEMENT DEREF';

      my ($sigil,$name)=$v->deref();
      exit;

    };

    $deref//=(is_hashref($v))
      ? $v->{value}
      : $v
      ;

    if(Tree::Grammar->is_valid($deref)) {
      my ($sigil,$name)=$deref->{value}->deref();

      if($sigil eq '*') {

        if($name=~ $REGEX->{tag}) {

          $name  =~ s[^<|>$][]sxmg;
          $deref =  pop @{$self->{-MATX}->{$name}};

        };

      };

    };

    $s.=$deref;

  };

  $mach->sow(
    $branch->{value}->{fd},$s

  );

};

sub reap_run($self,$branch) {

  my $mach = $self->{mach};
  my $fh   = $branch->{value};

  $mach->reap($fh);

};

# ---   *   ---   *   ---
# special definitions

  Readonly our $SVARS=>{

    name => 'name',

    chld=>[{
      name => Lang::eiths(

        [qw(VERSION AUTHOR ENTRY)],
        -insens=>1,

      ),

      fn   => 'capt',

    }],

  };

# ---   *   ---   *   ---

  Readonly our $DEFK=>{

    name=>'nid',
    chld=>[{
      name => Lang::eiths(
        [qw(def redef undef)],
        -insens => 1,

      ),

      fn   => 'capt',

    }],

  };

  Readonly our $PRIME=>{

    name => 'prime',

    fn   => 'prime',
    dom  => 'Grammar::peso',

    chld=>[

      $DEFK,

      $VGLOB,
      $NTERM,

      $TERM

    ],

  };

# ---   *   ---   *   ---
# ^exec

sub prime($self,$branch) {
  my $st=$branch->bhash();

};

# ---   *   ---   *   ---

  Readonly our $SDEFS=>{

    name => 'sdef',

    fn   => 'sasg',
    dom  => 'Grammar::peso',

    chld => [$SVARS,$NTERM,$TERM],

  };

# ---   *   ---   *   ---
# switch flips

  Readonly our $WED=>{

    name => 'type',
    chld => [{

      name => Lang::eiths(
        [qw(wed unwed)],
        insens=>1,

      ),

      fn   => 'capt',

    }],

  };

  Readonly our $SWITCH=>{

    name => 'switch',

    fn   => 'switch',
    dom  => 'Grammar::peso',

    chld => [$WED,$FLIST,$TERM],

  };

# ---   *   ---   *   ---
# regex definitions

  Readonly our $RETYPE=>{

    name => 'type',

    chld =>[{
      name => Lang::insens('re',mkre=>1),
      fn   => 'capt',

    }],

  };

  Readonly our $RE=>{

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

  Readonly our $OPERATOR=>{

    name => 'op',

    chld => [{

      name => $REGEX->{ops},
      fn   => 'capt',

    }],

  };

  Readonly our $MATCH=>{

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

sub mtest_ctx($self,$branch) {

  my $mach       = $self->{mach};
  my $st         = $branch->bhash();
  my @path       = $mach->{scope}->path();

  my ($o,%flags) = $self->re_vex($st->{nterm});
  my $v          = $mach->{scope}->get(

    @path,
    $st->{value}

  );

  $branch->{value}={

    re  => $o,
    v   => $v,

    flg => \%flags,

  };

  $branch->clear_branches();

};

# ---   *   ---   *   ---
# ^exec

sub mtest_run($self,$branch) {

  my $out = 0;
  my $st  = $branch->{value};

  my $v   = $st->{v}->{value};
  my $re  = $st->{re};

  my $chk = ($st->{flg}{-sigws})
    ? $v=~ m[$re]
    : $v=~ m[$re]x
    ;

  if($chk) {

    for my $key(keys %+) {

      $self->{-MATX}->{$key}//=[];
      my $ar=$self->{-MATX}->{$key};

      push @$ar,$+{$key};

    };

    $out=1;

  };

  return $out;

};

# ---   *   ---   *   ---
# pop current block

  Readonly our $RET=>{

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

sub ret_ctx($self,$branch) {

  my $mach = $self->{mach};
  my $n    = 1;

  $mach->{scope}->ret($n);

};

# ---   *   ---   *   ---
# procedure calls

  Readonly our $CALL=>{

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

sub call($self,$branch) {

  my $st=$branch->bhash(0,1);
  $branch->clear_branches();

  $branch->{value}={
    fn   => [(split $REGEX->{nsop},$st->{value})],
    args => $st->{values},

  };

};

# ---   *   ---   *   ---
# ^optimize

sub call_opz($self,$branch) {

  my $mach  = $self->{mach};
  my $st    = $branch->{value};

  my @path  = $mach->{scope}->path();
  my @rpath = $mach->{scope}->search(

    (join q[::],@{$st->{fn}}),
    @path

  );

  $st->{fn}=$mach->{scope}->get(
    @rpath,q[$branch]

  );

  for my $arg(@{$st->{args}}) {
    next if ! ($arg=~ $REGEX->{bare});
    $mach->{scope}->cderef(1,\$arg,@path);

  };

};

# ---   *   ---   *   ---
# ^exec

sub call_run($self,$branch) {

  my $st   = $branch->{value};

  my $fn   = $st->{fn};
  my @args = @{$st->{args}};

  for my $arg(reverse @args) {
    $self->{mach}->stkpush($arg);

  };

  unshift @{$self->{callstk}},
    $fn->shift_branch(keepx=>1);

};

# ---   *   ---   *   ---

  Readonly our $FCALL=>{

    name=>'fcall',
    chld=>[
      $MATCH

    ],

  };

  Readonly our $FC_OR_V=>{

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

sub fc_or_v($self,$branch) {

  my $par=$branch->{parent};

  for my $nd(@{$branch->{leaves}}) {
    $branch->pluck($nd) if !$nd->{mfull};

  };

  my $type=\($branch->{leaves}->[0]->{value});

  if($$type eq 'value') {
    $branch=$branch->flatten_branch();

  } else {

  };

  $branch=$branch->flatten_branch();
  $branch->{value}='eval';

};

# ---   *   ---   *   ---

  Readonly our $COND_BEG=>{

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

  Readonly our $COND_END=>{

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

sub cond_beg_ctx($self,$branch) {

  my $idex  = $branch->{idex};
  my $depth = 0;

  my @lv    = @{$branch->{parent}->{leaves}};
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
  $branch->{-pest}=$branch->bhash();

  $branch->pluck($branch->branches_in(
    qr{^nid|eval$}

  ));

  $branch->pushlv(@lv);

};

# ---   *   ---   *   ---

sub cond_beg_run($self,$branch) {

  my $st=$branch->{-pest};
  my $ev=$st->{eval};

  my $ok=0;

  for my $nd(@{$ev->{leaves}}) {
    $ok|=$nd->{chain}->[-1]->($nd);

  };

  if(! $ok) {

    my $callstk = $self->{callstk};
    my $size    = @{$branch->{leaves}};

    for(0..$size-1) {
      shift @$callstk;

    };

  };

};

# ---   *   ---   *   ---
# value expansion

sub vex($self,$fet,$vref,@path) {

  my $mach=$self->{mach};

  $mach->{scope}->cderef(
    $fet,$vref,@path,q[$LIS]

  ) or $mach->{scope}->cderef(
    $fet,$vref,@path

  );

};

sub array_vex($self,$fet,$ar,@path) {

  for my $v(@$ar) {
    $self->vex($fet,\$v,@path);

  };

};

# ---   *   ---   *   ---
# placeholder for file header

sub rdhed($self,$branch) {

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

sub detag($self,$o,@path) {

  my @tags=();
  my $mach=$self->{mach};

  while($o=~ s[$REGEX->{tag}][$Shwl::PL_CUT]) {

    my @ar=split q[\|],$1;

    for my $name(@ar) {

      my @npath = split $REGEX->{nsop},$name;
      $name     = pop @npath;

      push @npath,'re',$name;

      my @rpath=$mach->{scope}->search(

        (join q[::],@npath),
        @path,'re'

      );

      $name=$mach->{scope}->get(@rpath);

      # proc scope walkback
      if(

         is_hashref($name)
      && defined $self->{frame}->{-cproc}

      ) {

        @npath=@rpath[-2..-1];
        @rpath=(@rpath[0..1],@npath);

        $name=$mach->{scope}->get(@rpath);

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
# regex expansion

sub re_vex($self,$o) {

  my $mach  = $self->{mach};
  my @path  = $mach->{scope}->path();
  my $flags = {};

  for my $key(keys %$PE_FLAGS) {
    my $x=$mach->{scope}->get(@path,$key);
    $flags->{$key}=$x;

  };

  $o=$self->detag($o);

  if(!$sigws) {
    $o=~ s[[\s\n]+][ ]sxmg;

  };

  if($flags->{-qwor}) {

    my @ar=split $SPACE_RE,$o;
    array_filter(\@ar);

    $o=Lang::eiths(
      \@ar,

      escape=>$flags->{-escape},
      insens=>$flags->{-insens},

    );

  };

  return ($o,$flags);

};

# ---   *   ---   *   ---
# interprets regex definitions

sub rdre_ctx($self,$branch) {

  my $mach = $self->{mach};
  my $st   = $branch->bhash(0,0,0);
  my @path = $mach->{scope}->path();

  my ($o,$flags)=$self->re_vex($st->{nterm});

  $o=q[(?<].$st->{seal}.q[>].$o.q[)];

  $o=(! $flags->{-sigws})
    ? qr{$o}x
    : qr{$o}
    ;

  $mach->{scope}->decl(

    $o,

    @path,
    $st->{type},
    $st->{seal}

  );

};

# ---   *   ---   *   ---
# placeholder for special defs

sub sasg_ctx($self,$branch) {

  my $mach = $self->{mach};
  my $st   = $branch->bhash(0,0);
  my @path = $mach->{scope}->path();

  if(uc $st->{name} eq 'ENTRY') {

    $st->{nterm}=[split
      $REGEX->{nsop},
      $st->{nterm}

    ];

  };

  $mach->{scope}->asg(
    $st->{nterm},

    @path,
    $st->{name}

  );

};

# ---   *   ---   *   ---
# turns you on and off

sub switch($self,$branch) {

  my $st=$branch->bhash(0,1);

  $branch->{value}={

    type  => uc $st->{type},
    flags => $st->{flags},

  };

  $branch->clear_branches();

};

sub switch_ctx($self,$branch) {

  my $mach = $self->{mach};
  my $st   = $branch->{value};
  my @path = $mach->{scope}->path();

  my $value=int($st->{type} eq 'WED');

  for my $f(@{$st->{flags}}) {

    my $d=$f->leaf_value(0);
    my $fname=$d->{sigil} . $d->{name};

    $mach->{scope}->asg(
      $value,@path,$fname

    );

  };

};

# ---   *   ---   *   ---
# converts all numerical
# notations to decimal

sub rdnum($self,$branch) {

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

    } $branch->branches_in(
      $REGEX->{$type}

    );

  };

};

# ---   *   ---   *   ---
# preprocesses hierarchicals

sub hier_sort($self,$branch) {

  Tree::Grammar::list_flatten(
    $branch->branch_in(qr{^name$})

  );

  my ($type)=$branch->pluck(
    $branch->branch_in(qr{^type$})

  );

  $branch->{value}=$type->leaf_value(0);

  my $st=$branch->bhash(1,0);
  $branch->{-pest}=$st;

  $branch->clear_branches();

};

# ---   *   ---   *   ---
# forks accto hierarchical type

sub hier_sort_ctx($self,$branch) {

  my $type    = $branch->{value};
  my $ckey    = q[-c].(lc $type);
  my $st      = $branch->{-pest};
  my $f       = $self->{frame};

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

  my $mach=$self->{mach};
  my @path=$mach->{scope}->path();

  for my $key(keys %$PE_FLAGS) {
    my $value=$PE_FLAGS->{$key};
    $mach->{scope}->asg($value,@path,$key);

  };

  my @chld=$branch->{parent}->match_until(
    $branch,qr{^$type$}

  );

  @chld=$branch->{parent}->all_from(
    $branch

  ) if !@chld;

  $branch->pushlv(@chld);

  @path=grep {$ARG ne '$DEF'} @path;
  $mach->{scope}->decl_branch($branch,@path);

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

  $mach->{scope}->path($branch->ances());

  ns_ret($f) if $O{-ret};

  return @out;

};

# ---   *   ---   *   ---
# pushes constructors to current namespace

sub ptr_decl($self,$branch) {

  Tree::Grammar::list_flatten(
    $branch->branch_in(qr{^names$})

  );

  Tree::Grammar::nest_flatten(
    $branch,'flg'

  );

  Tree::Grammar::nest_flatten(
    $branch,'value'

  );

  $branch->branch_in(
    qr{^specs$}

  )->flatten_branch();

};

# ---   *   ---   *   ---
# ^call made when executing tree

sub ptr_decl_ctx($self,$branch) {

  my $mach   = $self->{mach};
  my $st     = $branch->bhash(1,1,1);
  my $type   = shift @{$st->{type}};

  my @specs  = @{$st->{type}};
  my @names  = @{$st->{names}};
  my @values = @{$st->{'values'}};

  my @path   = $mach->{scope}->path();

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

    $mach->{scope}->decl($o,@path,$name);

    push @$ptrs,
      $mach->{scope}->rget(@path,$name);

  };

  $branch->clear_branches();
  $branch->{value}=$ptrs;

};

# ---   *   ---   *   ---
# groups

  Readonly our $BLTN=>{

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

  Readonly our $CORE=>[

    $HEADER,
    $COMMENT,
    $PRIME,

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

  ];

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

#  my $t    = Grammar::peso->parse($prog,-r=>2);
#
#  Grammar::peso->run(
#
#    $t,
#
#    entry=>1,
#    keepx=>1,
#
#    input=>[
#
#      "HLOWRLD\n",
#
#    ],
#
#  );

# ---   *   ---   *   ---
1; # ret
