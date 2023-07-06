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
  use Arstd::String;
  use Arstd::IO;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/avtomat/hacks/';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/avtomat/';

  use Lang;
  use Grammar;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  sub Frame_Vars($class) { return {

    -creg   => undef,
    -cclan  => 'non',
    -cproc  => undef,

    -nest   => {

      parens=>0,
      switch=>0,

    },

    %{Grammar->Frame_Vars()},

    -passes => ['_ctx','_opz','_cl','_run'],

  }};

# ---   *   ---   *   ---

  Readonly our $PE_FLAGS=>{

    -qwor   => 0,
    -insens => 0,
    -escape => 0,
    -sigws  => 0,

  };

  Readonly our $PE_SDEFS=>{

    VERSION => 'v0.00.1b',
    AUTHOR  => 'anon',
    ENTRY   => 'crux',

  };

# ---   *   ---   *   ---
# op => F
# precedence given by array idex

  Readonly our $OPERATORS=>[

    q[->*] => 'm_call',
    q[->]  => 'm_attr',

    q[*^]  => 'pow',
    q[*]   => 'mul',
    q[%]   => 'mod',
    q[/]   => 'div',

    q[+]   => 'add',
    q[-]   => 'sub',

    q[<<]  => 'lshift',
    q[>>]  => 'rshift',

    q[&]   => 'b_and',
    q[|]   => 'b_or',
    q[^]   => 'b_xor',
    q[~]   => 'b_not',

    q[!]   => 'not',

    q[<]   => 'lt',
    q[<=]  => 'e_lt',
    q[>]   => 'gt',
    q[>=]  => 'e_gt',

    q[&&]  => 'and',
    q[||]  => 'or',
    q[^^]  => 'xor',

    q[~=]  => 'match',
    q[==]  => 'eq',
    q[!=]  => 'ne',

  ];

  Readonly our $OPHASH=>{@$OPERATORS};
  Readonly our $OP_KEYS=>[array_keys($OPERATORS)];

# ---   *   ---   *   ---
# ^makes note of unary ops

  Readonly our $OP_UNARY=>{
    q[!]=>1,
    q[~]=>1,

  };

# ---   *   ---   *   ---
# ^makes note of ops taking slurp args

  Readonly our $OP_SLURP=>{
    q[->*] => 1,
    q[->]  => 1,

  };

# ---   *   ---   *   ---
# call member F/getset member var

sub op_m_call($lhs,$rhs,@args) {};
sub op_m_attr($lhs,$rhs,@args) {};

# ---   *   ---   *   ---
# math

sub op_pow($lhs,$rhs) {return $lhs ** $rhs};

sub op_mul($lhs,$rhs) {return $lhs * $rhs};
sub op_mod($lhs,$rhs) {return $lhs % $rhs};
sub op_div($lhs,$rhs) {return $lhs / $rhs};
sub op_add($lhs,$rhs) {return $lhs + $rhs};
sub op_sub($lhs,$rhs) {return $lhs - $rhs};

# ---   *   ---   *   ---
# bits

sub op_lshift($lhs,$rhs) {return $lhs << $rhs};
sub op_rshift($lhs,$rhs) {return $lhs >> $rhs};

sub op_b_and($lhs,$rhs) {return $lhs & $rhs};
sub op_b_or($lhs,$rhs) {return $lhs | $rhs};
sub op_b_xor($lhs,$rhs) {return $lhs ^ $rhs};

sub op_b_not($rhs) {return ~ $rhs};

# ---   *   ---   *   ---
# logic

sub op_not($rhs) {return ! $rhs};

sub op_lt($lhs,$rhs) {return $lhs < $rhs};
sub op_e_lt($lhs,$rhs) {return $lhs <= $rhs};
sub op_gt($lhs,$rhs) {return $lhs > $rhs};
sub op_e_gt($lhs,$rhs) {return $lhs >= $rhs};

sub op_and($lhs,$rhs) {return $lhs && $rhs};
sub op_or($lhs,$rhs) {return $lhs || $rhs};

sub op_xor($lhs,$rhs) {

  my $a=($lhs) ? 1 : 0;
  my $b=($rhs) ? 1 : 0;

  return $lhs ^ $rhs;

};

# ---   *   ---   *   ---
# equality

sub op_match($lhs,$rhs) {};

sub op_eq($lhs,$rhs) {return $lhs eq $rhs};
sub op_ne($lhs,$rhs) {return $lhs ne $rhs};

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    hexn  => qr{\$  [0-9A-Fa-f\.:]+}x,
    octn  => qr{\\ [0-7\.:]+}x,
    binn  => qr{0b  [0-1\.:]+}x,
    decn  => qr{[0-9\.:]+}x,

    term  => Lang::nonscap(q[;]),
    clist => Lang::nonscap(q[,]),
    lcom  => Lang::eaf(q[\#]),

    nsop  => qr{::},

# ---   *   ---   *   ---

    nterm=>Lang::nonscap(

      q[;],

      iv    => 1,
      mod   => '+',
      sigws => 1,

    ),

    sigil=>Lang::eiths(

      [qw(

        $ $: $:% $:/

        %% %

        / // /: //:
        @ @:

        ~:

        * : -- - ++ + ^ &

        >> >>: << <<:

        |> &>

      )],

      escape=>1

    ),

    ops=>Lang::eiths(

      $OP_KEYS,
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

    q[hier-type]=>Lang::eiths(

      [qw(reg rom clan proc)],

      bwrap  => 1,
      insens => 1,

    ),

    q[io-type]=>Lang::eiths(

      [qw(io in out)],

      bwrap  => 1,
      insens => 1,

    ),

    q[wed-type]=>Lang::eiths(

      [qw(wed unwed)],

      bwrap  => 1,
      insens => 1,

    ),

    q[re-type]=>Lang::eiths(

      [qw(re)],

      bwrap  => 1,
      insens => 1,

    ),

# ---   *   ---   *   ---

    width=>Lang::eiths(

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

    tag  => Lang::delim_capt('<','>'),
    repl => Lang::delim_capt('%'),

    branch => qr{
      (?<leaf> (.+))?
      (?: \\ \-* >)

    }x,

# ---   *   ---   *   ---

    dqstr => qr{"([^"]|\\")*?"},
    sqstr => qr{'([^']|\\')*?'},

    vstr  => qr{v[0-9]\.[0-9]{2}\.[0-9][ab]?},

    q[sdef-name] => Lang::eiths(

      [keys %$PE_SDEFS],

      -insens => 1,
      -bwrap  => 1,

    ),

# ---   *   ---   *   ---
# switch cases

    q[on-key]  => Lang::insens('on',mkre=>1),
    q[or-key]  => Lang::insens('or',mkre=>1),
    q[off-key] => Lang::insens('off',mkre=>1),

  };

# ---   *   ---   *   ---
# lets call these "syntax ops"

  rule('~?<clist> &rew');
  rule('~<term>');
  rule('~<lcom>');

# ---   *   ---   *   ---
# pe file header

  rule('~<sigil>');
  rule('~<nterm>');

  rule('?<opt-nterm> &clip nterm');
  rule('$<header> &rdhed sigil opt-nterm');

# ---   *   ---   *   ---
# placeholder for file header

sub rdhed($self,$branch) {
  my $mach=$self->{mach};
  my @path=$mach->{scope}->path();

};

# ---   *   ---   *   ---
# numerical notations

  rule('~<hexn>');
  rule('~<octn>');
  rule('~<binn>');
  rule('~<decn>');

  # ^combined
  rule('|<num> &rdnum hexn octn binn decn');

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

  Grammar::list_flatten($self,$branch);

};

# ---   *   ---   *   ---
# common patterns

  rule('~<width>');
  rule('~<spec>');
  rule('*<specs> &list_flatten spec');

  rule('~<bare>');
  rule('~<seal>');

# ---   *   ---   *   ---
# string types

  rule('~<dqstr>');
  rule('~<sqstr>');

  rule('~<vstr>');

  # ^combo
  rule('|<str> dqstr sqstr vstr');

# ---   *   ---   *   ---
# ipret double quoted

sub dqstr($self,$branch) {

  my $ct=$branch->leaf_value(0);
  return unless defined $ct;

  ($ct=~ s[^"([\s\S]*)"$][$1])
  or throw_badstr($ct);

  charcon(\$ct);

  $branch->{value}={

    ipol => 1,
    ct   => $ct,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^single quoted

sub sqstr($self,$branch) {

  my $ct=$branch->leaf_value(0);
  return unless defined $ct;

  ($ct=~ s[^'([\s\S]*)'$][$1])
  or throw_badstr($ct);

  $branch->{value}={

    ipol => 0,
    ct   => $ct,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^errme

sub throw_badstr($s) {

  errout(

    q[Malformed string: %s],

    args => [$s],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# soul of perl!

  rule('|<flg-name> &clip bare seal');
  rule('$<flg> sigil flg-name');
  rule('$<flist> &list_pop flg clist');

# ---   *   ---   *   ---
# ^post-parse

sub flg($self,$branch) {

  my $st   = $branch->bhash();
  my $type = (exists $st->{seal})
    ? 'seal'
    : 'bare'
    ;

  $branch->{value}={

    sigil => $st->{sigil},
    name  => $st->{$type},

    type  => $type,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# combo

  rule(q[

    |<value>
    &value_sort

    num str flg bare

  ]);

# ---   *   ---   *   ---
# get values in branch

sub find_values($self,$branch) {

  state $re=qr{^value$};

  return $branch->branches_in(
    $re,keep_root=>0

  );

};

# ---   *   ---   *   ---
# branch is value

sub is_value($self,$branch) {
  return $branch->{value} eq 'value';

};

# ---   *   ---   *   ---
# ^bat

sub array_is_value($self,@ar) {

  return int(grep {
   $self->is_value($ARG)

  } @ar) eq @ar;

};

# ---   *   ---   *   ---
# ^handler

sub value_sort($self,$branch) {

  my $st     = $branch->bhash();
  my $xx     = $branch->leaf_value(0);

  my ($type) = keys %$st;

  if(is_hashref($xx)) {
    $type='flg';

  };

  $branch->clear();

  my $o=undef;
  if(defined $st->{$type}) {

    $o={
      type => $type,
      raw  => $st->{$type}

    };

  } else {

    $o={
      type => $type,
      raw  => $xx,

    };

  };

  $branch->init($o);

};

# ---   *   ---   *   ---
# entry point for all hierarchicals

  rule('~<hier-type>');

  rule(q[

    $<hier>
    &hier_sort

    hier-type bare

  ]);

# ---   *   ---   *   ---
# preprocesses hierarchicals

sub hier_sort($self,$branch) {

  my ($type)=$branch->pluck(
    $branch->branch_in(qr{^hier\-type$})

  );

  $branch->{value}=$type->leaf_value(0);

  my $st=$branch->bhash();
  $branch->{-pest}=$st;

  $branch->clear();

};

# ---   *   ---   *   ---
# forks accto hierarchical type

sub hier_sort_ctx($self,$branch) {

  my $type = $branch->{value};
  my $ckey = q[-c].(lc $type);
  my $st   = $branch->{-pest};
  my $f    = $self->{frame};

  # set type of current scope
  $f->{$ckey}=$st->{bare};

  # get altered path
  my @cur=$self->cpath_change($type);
  @cur=$self->cpath() if ! @cur;

  # ^set path
  my $mach=$self->{mach};
  my @path=$mach->{scope}->path(@cur);

  # initialize scope
  $self->hier_nit($type);

  # parent nodes to this branch
  $self->hier_chld($branch,$type);

  # save pointer to branch
  # used for jumping later ;>
  @path=grep {$ARG ne '$DEF'} @path;
  $mach->{scope}->decl_branch($branch,@path);

};

# ---   *   ---   *   ---
# alters current path when
# stepping on a hierarchical

sub cpath_change($self,$type) {

  my @out = ();
  my $f   = $self->{frame};

  if($type eq 'ROM') {
    $f->{-creg}=undef;
    $f->{-cproc}=undef;

    @out=($f->{-cclan},$f->{-crom});

  } elsif($type eq 'REG') {
    $f->{-crom}=undef;
    $f->{-cproc}=undef;

    @out=($f->{-cclan},$f->{-creg});

  } elsif($type eq 'CLAN') {
    $f->{-creg}=undef;
    $f->{-crom}=undef;
    $f->{-cproc}=undef;

    @out=($f->{-cclan});

  };

  return @out;

};

# ---   *   ---   *   ---
# ^get current path from
# previously stepped hierarchicals

sub cpath($self) {

  my @out = ();
  my $f   = $self->{frame};

  if(defined $f->{-creg}) {
    @out=(
      $f->{-cclan},
      $f->{-creg},
      $f->{-cproc}

    );

  } elsif(defined $f->{-crom}) {
    @out=(
      $f->{-cclan},
      $f->{-crom},
      $f->{-cproc}

    );

  } else {
    @out=(
      $f->{-cclan},
      $f->{-cproc}

    );

  };

  return @out;

};

# ---   *   ---   *   ---
# get children nodes of a hierarchical
# performs parenting

sub hier_chld($self,$branch,$type) {

  # alter type for tree search
  if($type eq 'REG' || $type eq 'ROM') {
    $type=q[REG|ROM];

  };

  my @out=
    $branch->match_up_to(qr{^$type$});

  $branch->pushlv(@out);

  return @out;

};

# ---   *   ---   *   ---
# defaults out all flags for
# current scope

sub hier_nit($self,$type) {

  my $mach=$self->{mach};
  my @path=$mach->{scope}->path();

  # major scope properties
  if($type eq 'CLAN') {

    for my $key(keys %$PE_SDEFS) {
      my $value=$PE_SDEFS->{$key};
      $mach->{scope}->decl($value,@path,$key);

    };

  };

  # minor flags
  for my $key(keys %$PE_FLAGS) {
    my $value=$PE_FLAGS->{$key};
    $mach->{scope}->decl($value,@path,$key);

  };

  # match stacks
  if($type eq 'PROC') {

    $mach->{scope}->decl(
      {},@path,q[~:rematch]

    );

  };

};

# ---   *   ---   *   ---
# patterns for declaring members

  rule('$<type> width specs');
  rule('$<nlist> &list_flatten bare clist');
  rule('$<vlist> &list_flatten value clist');

  rule('?<opt-vlist> &clip vlist');

  # ^combo
  rule(q[

    $<ptr-decl>
    &ptr_decl

    type nlist opt-vlist

  ]);

# ---   *   ---   *   ---
# pushes constructors to current namespace

sub ptr_decl($self,$branch) {

  my $st   = $branch->bhash(0,1,1);
  my $type = $st->{type}->bhash(0,1);

  # ^lis
  $branch->{value}={

    type   => $type,

    names  => $st->{nlist},
    values => $st->{vlist},

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^pre-run step

sub ptr_decl_ctx($self,$branch) {

  my $mach   = $self->{mach};
  my @path   = $mach->{scope}->path();

  my $st     = $branch->{value};
  my $f      = $self->{frame};

  my @names  = @{$st->{names}};

  # errchk
  throw_invalid_scope(\@names,@path)
  if !$f->{-crom}
  && !$f->{-creg}
  && !$f->{-cproc}
  ;

  # enforce zero as default value
  for my $i(0..$#names) {
    $st->{values}->[$i]//=0;

  };

  $self->bind_decls($branch);

};

# ---   *   ---   *   ---
# ^errme

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
# register decls to current scope

sub bind_decls($self,$branch) {

  # data
  my $st     = $branch->{value};

  my @names  = @{$st->{names}};
  my @values = @{$st->{values}};

  # ctx
  my $mach=$self->{mach};
  my @path=$mach->{scope}->path();

  # dst
  my $ptrs=[];

  while(@names && @values) {

    my $name    = shift @names;
    my $value   = shift @values;

    my $o     = {
      type  => $st->{type},
      value => $value,

    };

    $mach->{scope}->decl($o,@path,$name);

    push @$ptrs,
      $mach->{scope}->rget(@path,$name);

  };

  $branch->{value}=$ptrs;

};

  rule('~<io-type>');
  rule('$<io> &rdio io-type ptr-decl');

# ---   *   ---   *   ---
# ^forks

sub rdio($self,$branch) {

  state $table={
    io  => undef,

    out => undef,
    in  => 'rdin',

  };

  my @lv    = @{$branch->{leaves}};
  my $class = $self->{frame}->{-class};

  my $st={
    type  => $lv[0]->leaf_value(0),
    value => $lv[1],

  };

  $branch->{value}=$st;
  $branch->clear_nproc();

  $branch->fork_chain(
    dom  => $class,
    name => $table->{$st->{type}},

  );

};

# ---   *   ---   *   ---
# ^proc input

sub rdin_opz($self,$branch) {

  my $st=$branch->{value};
  my $ar=$st->{value};

  $branch->{value}=$ar->{value};

};

sub rdin_run($self,$branch) {

  for my $ptr(@{$branch->{value}}) {
    $$ptr->{value}=$self->{mach}->stkpop();

  };

};

# ---   *   ---   *   ---
# soul of perl v2.0

  rule('%<beg-curly=\{>');
  rule('%<end-curly=\}>');
  rule('$<vglob> beg-curly flg end-curly');

# ---   *   ---   *   ---
# aliasing

  rule('%<lis-key=lis>');
  rule('$<lis> lis-key vglob value');

# ---   *   ---   *   ---
# ^post-parse

sub lis($self,$branch) {

  my $st=$branch->bhash();
  $self->{Q}->add(sub {

    $branch->{value}={
      from => $st->{value},
      to   => $st->{vglob},

    };

    $branch->clear();

  });

};

# ---   *   ---   *   ---

sub vglob($self,$branch) {

  my @ar  = $branch->branch_values();
  my $out = $ar[1];

  $branch->clear();
  $branch->init($out);

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

  rule('%<sow-key=sow>');
  rule('%<reap-key=reap>');

  rule('<sow> sow-key vglob vlist');
  rule('<reap> reap-key vglob');

# ---   *   ---   *   ---
# ^post-parse

sub sow($self,$branch) {

  my $lv=$branch->{leaves};
  my @ar=$lv->[1]->branch_values();

  $branch->{value}={

    fd => $lv->[1]->leaf_value(0),
    me => \@ar,

  };

  $branch->clear();

};

sub reap($self,$branch) {

  my $lv=$branch->{leaves};

  $branch->{value}=$lv->[1]->leaf_value(0);
  $branch->clear();

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
    $st->{fd}->{raw}

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

  map {
    $s.=$self->deref($ARG)

  } @{$st->{me}};

  $mach->sow($st->{fd}->{raw},$s);

};

sub reap_run($self,$branch) {

  my $mach = $self->{mach};
  my $fh   = $branch->{value};

  $mach->reap($fh->{raw});

};

# ---   *   ---   *   ---
# for internal/out tree manipulation

  rule('~<branch>');
  rule('+<branches> branch vlist');

# ---   *   ---   *   ---
# ^post-parse

sub branches($self,$branch) {

  # get value list
  my $lv=$branch->{leaves};

  # BUG:
  #
  #   value sort refuses to trigger
  #   for strings in trees and i
  #   can't figure out why

  # ^this bit patches it out for now...
  if($lv->[1]->deepchk(1)) {
    $self->value_sort($lv->[1]);

  };

  my @values = $lv->[1]->branch_values();

  # get depth
  my $expr =  $branch->leaf_value(0);
     $expr =~ $REGEX->{branch};
  my $leaf = $+{leaf};

  # get dot count
  $leaf //=  $NULLSTR;
  $leaf   =~ s[\s+][]sxmg;

  my $lvl=length $leaf;

  $branch->clear();

  my $ar   = $branch->{ar};
     $ar //= [];

  push @$ar,{
    lvl   => $lvl,
    value => (@values > 1)
      ? \@values
      : $values[0]
      ,

  };

  $branch->{ar}=$ar;

};

# ---   *   ---   *   ---
# branch array

  rule('%<tree-key=tree>');
  rule('<tree> tree-key vglob branches');

# ---   *   ---   *   ---
# ^post-parse

sub tree($self,$branch) {

  # TODO:
  #
  #   function calls and derefs
  #   in tree decls; we have to
  #   look into expanding $VALUE
  #   itself...
  #
  #   or create different types of
  #   values, which i'd prefer ;>

  my $st    = $branch->bhash();
  my $exprs = $branch->branch_in(qr{^branches$});
  my $ar    = $exprs->{ar};

  $branch->{value}={
    vglob    => $st->{vglob},
    branches => $ar,

  };

  $branch->clear();2

};

sub tree_ctx($self,$branch) {

  my $st = $branch->{value};
  my $ar = $st->{branches};

  my $depth   = 0;
  my @anchors = ($branch);

  for my $ref(@$ar) {

    my ($lvl,$value)=(
      $ref->{lvl},
      $ref->{value}

    );

    my $anchor = $anchors[-1];
    my $prev   = $anchor->{leaves}->[-1];

    if($lvl > $depth) {
      push @anchors,$prev;
      $depth++;

    };

    while($lvl < $depth) {
      pop @anchors;
      $depth--;

    };

    $anchors[-1]->init($value);

  };

  $branch->{value}="$st->{vglob}->{name}";
  $branch->prich();

  exit;

};

# ---   *   ---   *   ---
# special definitions

  rule('~<sdef-name>');
  rule('$<sdef> sdef-name nterm');

# ---   *   ---   *   ---
# placeholder for special defs

sub sdef($self,$branch) {

  my $st=$branch->bhash(0,0);

  $branch->{value}={
    name  => $st->{q[sdef-name]},
    value => $st->{nterm},

  };

  $branch->clear();

};

sub sdef_ctx($self,$branch) {

  my $mach = $self->{mach};

  my $st   = $branch->{value};
  my @path = $mach->{scope}->path();

  if(uc $st->{name} eq 'ENTRY') {

    $st->{value}=[split
      $REGEX->{nsop},
      $st->{value}

    ];

  };

  my $o=$mach->{scope}->asg(

    $st->{value},

    @path,
    $st->{name}

  );

  $branch->{parent}->pluck($branch);

};

# ---   *   ---   *   ---
# switch flips

  rule('~<wed-type>');
  rule('$<wed> wed-type flist');

# ---   *   ---   *   ---
# ^handler

sub wed($self,$branch) {

  my $st=$branch->bhash(0,1);

  $branch->{value}={

    type  => uc $st->{q[wed-type]},
    flags => $st->{flist},

  };

  $branch->clear();

};

sub wed_ctx($self,$branch) {

  my $mach = $self->{mach};
  my $st   = $branch->{value};
  my @path = $mach->{scope}->path();

  my $value=int($st->{type} eq 'WED');

  for my $f(@{$st->{flags}}) {

    my $fname=$f->{sigil} . $f->{name};

    $mach->{scope}->asg(
      $value,@path,$fname

    );

  };

};

# ---   *   ---   *   ---
# regex definitions

  rule('~<re-type>');
  rule('$<re> &rdre re-type seal nterm');

# ---   *   ---   *   ---
# interprets regex definitions

sub rdre($self,$branch) {

  my $st=$branch->bhash(0,0,0);

  $branch->{value}={

    type  => $st->{q[re-type]},

    nterm => $st->{nterm},
    seal  => $st->{seal},

  };

  $branch->clear();

};

sub rdre_ctx($self,$branch) {

  my $st   = $branch->{value};

  my $mach = $self->{mach};
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
# soul of lisp

  rule('%<beg-parens=\(> &erew');
  rule('%<end-parens=\)> &erew');

  rule('$?<fbeg-parens> &nest_parens beg-parens');
  rule('$?<fend-parens> &nest_parens end-parens');

# ---   *   ---   *   ---
# ^post-parse

sub nest_parens($self,$branch) {

  state $is_beg = qr{beg\-parens}x;

  # no match
  my $lv=$branch->{leaves}->[0];
  if(! @{$lv->{leaves}}) {
    Grammar::discard($self,$branch);
    return;

  };

  # ^its a trap
  my $f   = $self->{frame};
  my $top = \$f->{-nest}->{parens};

  # go up one recursion level
  if($branch->{value}=~ $is_beg) {
    $branch->{value}=$$top++;

  # ^mark end
  } else {
    $branch->{value}=--$$top . '<';

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^context pass

sub nest_parens_ctx($self,$branch) {

  state $re = qr{
    (?<num> \d+)
    (?<end> \< )?

  }x;

  my $f    = $self->{frame};
  my $nest = $f->{-nest}->{parens};

  $branch->{value}=~ $re;

  my $num=$+{num};
  my $end=$+{end};

  # get all nodes from beg+1 to end
  if(! defined $end) {

    my $pat=qr{$branch->{value} \<}x;

    my @lv=$branch->match_up_to($pat);

    # ^parent to beg
    $branch->pushlv(@lv);
    $branch->{value}="()";

  } else {
    $branch->{parent}->pluck($branch);

  };

};

# ---   *   ---   *   ---
# operations

  rule('~?<ops> &erew');

  rule(q[

    $<value-op-value>
    &value_ops

    fbeg-parens
    value ops

    fend-parens

  ]);

  rule(q[

    $<ari>
    &erew

    value-op-value ops

  ]);

  rule('$<expr> &expr ari');
  rule('?<opt-expr> &clip expr');

# ---   *   ---   *   ---
# get operators in branch

sub find_ops($self,$branch) {

  state $re=qr{^ops$};

  return $branch->branches_in(
    $re,keep_root=>0

  );

};

# ---   *   ---   *   ---
# get descriptor for operator
# from the parsed symbol

sub opnit($self,$branch) {

  # remove childless branches
  if(! @{$branch->{leaves}}) {
    Grammar::discard($self,$branch);
    return;

  };

  # get function matching operator
  my $key  = $branch->leaf_value(0);
  my $name = $OPHASH->{$key};

  my $fn   = codefind(
    'Grammar::peso',
    "op_$name"

  );

  my $st={

    fn    => $fn,

    name  => $name,
    key   => $key,

    unary => exists $OP_UNARY->{$key},
    slurp => exists $OP_SLURP->{$key},

    idex  => array_iof($OP_KEYS,$key),

  };

  $branch->{leaves}->[0]->{value}=$st;

};

# ---   *   ---   *   ---
# ^post-parse
#
# find execution data for
# operators in tree

sub value_ops($self,$branch) {

  my @ops=$self->find_ops($branch);
  map {$self->opnit($ARG)} @ops;

};

# ---   *   ---   *   ---
# ^sort operators by precedence

sub opsort($self,$branch) {

  my $st     = $branch->leaf_value(0);
  my $idex   = $branch->{idex};
  my $lv     = $branch->{parent}->{leaves};

  # get operands
  my @move=($st->{unary})
    ? ($lv->[$idex+1])
    : ($lv->[$idex-1],$lv->[$idex+1])
    ;

  my ($st_lv)=$branch->pluck(
    $branch->{leaves}->[0]

  );

  my $st_br=$branch->init('D');
  $st_br->pushlv($st_lv);

  my $v_br=$branch->init('V');
  $v_br->pushlv(@move);

  $branch->{parent}->idextrav();

};

# ---   *   ---   *   ---
# ^pre-run solve operation
#
# ops that are unsolvable at
# this stage are collapsed
# to ease solving them later

sub opsolve($self,$branch) {

  # remove parens
  my $par=$branch->{parent};
  $par->flatten_branch()
  if $par->{value} eq '()';

  # decompose
  my ($D,$V) = @{$branch->{leaves}};

  my @leaves = @{$V->{leaves}};
  my @values = map {$ARG->leaf_value(0)} @leaves;

  # get op is solvable at this stage
  my $valid=

     $self->array_is_value(@leaves)
  && $self->array_needs_deref(@values)
  ;

  # restruc
  $self->op_simplify($branch,@values);

  # attempt solving
  $valid=($valid)
    ? $self->op_to_value($branch,@values)
    : $valid
    ;

  return $valid;

};

# ---   *   ---   *   ---
# ^bat

sub array_opsolve($self,$branch) {
  my @ops=$self->find_ops($branch);
  map {$self->opsolve($ARG)} reverse @ops;

};

# ---   *   ---   *   ---
# ^collapse op tree branch
# into value node

sub op_to_value($self,$branch,@values) {

  my $type=$values[0]->{type};

  $branch->{value}='value';

  my $o={
    raw  => $self->opres($branch),
    type => $type,

    %{$branch->leaf_value(0)}

  };

  $branch->clear();
  $branch->init($o);

  return 1;

};

# ---   *   ---   *   ---
# ^ease eventual solving of op

sub op_simplify($self,$branch,@values) {

  my ($D,$V) = @{$branch->{leaves}};
  my $st     = $D->leaf_value(0);

  my $o={

    D    => $st,
    V    => \@values,

    type => 'ops',

  };

  $branch->clear();
  $branch->init($o);

};

# ---   *   ---   *   ---
# get result of operation

sub opres($self,$branch,@values) {

  my $o=$branch->leaf_value(0);

  return ($self->is_value($branch))
    ? $self->deref($o)->{raw}
    : $self->opres_flat($o,@values)
    ;

};

# ---   *   ---   *   ---
# ^no branch

sub opres_flat($self,$o,@values) {

  my $st=$o->{D};

  @values=(! @values)
    ? @{$o->{V}}
    : @values
    ;

  # apply deref to @values
  # filter out undef from result of map
  my @deref=grep {defined $ARG} map {
    $self->deref($ARG)

  } @values;

  # ^early exit if values cant
  # be all dereferenced
  return $NULL if @deref ne @values;

  # call func with derefenced args
  return $st->{fn}->(map {
    $ARG->{raw}

  } @deref);

};

# ---   *   ---   *   ---
# ^non-runtime crux

sub value_ops_opz($self,$branch) {

  # sort by priority
  my @ops=sort {

     $a->leaf_value(0)->{idex}
  >= $b->leaf_value(0)->{idex}

  } $self->find_ops($branch);

  map {$self->opsort($ARG)} @ops;

  # ^solve from bottom up
  $self->array_opsolve($branch);
  $branch->flatten_branch();

};

# ---   *   ---   *   ---
# recursive sequence

sub expr($self,$branch) {};
sub expr_ctx($self,$branch) {

  my $lv=$branch->{leaves}->[-1];
  $lv->pluck($lv->{leaves}->[-1]);

  $branch->flatten_branches();

};

sub expr_opz($self,$branch) {};

sub expr_cl($self,$branch) {
  $branch->flatten_branch()
  if @{$branch->{leaves}} eq 1;

};

# ---   *   ---   *   ---

  rule('~<on-key>');
  rule('~<or-key>');
  rule('~<off-key>');

  rule('$<on> on-key');
  rule('$<or> or-key');
  rule('$<off> off-key');

  rule('|<switch-type> &clip on or off');
  rule('$<switch> switch-type opt-expr');

# ---   *   ---   *   ---
# if

sub switch_on($self,$branch) {

  my $f    = $self->{frame};
  my $nest = \$f->{-nest}->{switch};

  $$nest++;
  $self->switch_case($branch);

};

sub switch_on_ctx($self,$branch) {
  $self->switch_sort($branch);

};

sub switch_on_run($self,$branch) {

  my $lv  = $branch->{leaves}->[0];
  my $out = $self->opres($lv);

  $self->{c3}->jmp(
    $branch->next_branch()

  ) if ! $out;

};

# ---   *   ---   *   ---
# ^else/else if

sub switch_or($self,$branch) {

  my $f    = $self->{frame};
  my $nest = \$f->{-nest}->{switch};

  $self->switch_case($branch);

};

sub switch_or_ctx($self,$branch) {
  $self->switch_sort($branch);

};

sub switch_or_run($self,$branch) {

  my $lv  = $branch->{leaves}->[0];
  my $out = (defined $lv)
    ? $self->opres($lv)
    : 1
    ;

  $self->{c3}->jmp(
    $branch->next_branch()

  ) if ! $out;

};

# ---   *   ---   *   ---
# adds jmp off at end of switch case

sub switch_end($self,$branch) {

  state $re=qr{^off$};

  my $stop=$branch->next_branch();

  if(

     $branch->{value} ne 'off'
  && $stop->{value} ne 'off'

  ) {

    my $jmp = $branch->init('jmp');
    my $par = $branch->{parent};
    my $f   = $self->{frame};

    $stop=$par->match_from($branch,$re);
    $jmp->init($stop);

    $jmp->fork_chain(

      dom  => 'Grammar::peso',
      name => 'jmp',

      skip => $f->{-npass}+1

    );

  };

};

# ---   *   ---   *   ---
# end of switch

sub switch_off($self,$branch) {

  my $f    = $self->{frame};
  my $nest = \$f->{-nest}->{switch};

  $branch->clear();
  $self->switch_case($branch);

  $$nest--;

};

sub switch_off_cl($self,$branch) {
  $branch->clear();

};

# ---   *   ---   *   ---
# ^common to all

sub switch_case($self,$branch) {

  my $f    = $self->{frame};
  my $nest = \$f->{-nest}->{switch};

  $branch->init({
    lvl  => $$nest-1,
    type => $branch->{value},

  });

};

# ---   *   ---   *   ---
# find next case in switch
# parent in-between nodes to branch

sub switch_sort($self,$branch) {

  state $re=qr{^(?:or|off)$}x;

  my $par    = $branch->{parent};
  my $anchor = $branch;

  my @lv     = ();
  my $helper = $branch->{leaves}->[1];
  my $lvl    = $helper->{value}->{lvl};

REPEAT:

  push @lv,$par->match_until(
    $anchor,$re,
    inclusive=>1

  );

  my $stop = pop @lv;
  my $idex = ($stop->{value} eq 'off')
    ? 0
    : 1
    ;

  my $st=$stop->leaf_value($idex);

  $anchor=$stop;
  goto REPEAT if $st->{lvl} != $lvl;

  $branch->pushlv(@lv);
  $self->switch_end($branch);

  $branch->pluck($helper);

};

# ---   *   ---   *   ---

sub switch($self,$branch) {

  my $lv  = $branch->{leaves}->[0];
  my $key = $lv->{value};

  $branch->pluck($lv);
  $branch->{value}=$key;

  $branch->fork_chain(
    dom  => $self->{frame}->{-class},
    name => "switch_${key}",

  );

};

# ---   *   ---   *   ---
# jump to node

sub jmp($self,$branch) {};

sub jmp_run($self,$branch) {
  my $to=$branch->leaf_value(0);
  $self->{c3}->jmp($to);

};

# ---   *   ---   *   ---

#  Readonly our $MATCH=>{
#
#    name => 'match',
#
#    fn   => 'match',
#    dom  => 'Grammar::peso',
#
#    chld => [
#
#      $VALUE,
#      {name=>qr{~=}},
#
#      $NTERM,
#
#    ],
#
#  };
#
## ---   *   ---   *   ---
#
#sub match_ctx($self,$branch) {
#
#  my $mach       = $self->{mach};
#  my $st         = $branch->bhash();
#  my @path       = $mach->{scope}->path();
#
#  my $value      = $st->{value};
#
#  my ($o,$flags) = $self->re_vex($st->{nterm});
#  my $v          = $mach->{scope}->get(
#
#    @path,
#    $value->{raw}
#
#  );
#
#  $branch->{value}={
#
#    re  => $o,
#    v   => $v,
#
#    flg => $flags,
#
#  };
#
#  $branch->clear();
#
#};
#
## ---   *   ---   *   ---
## ^exec
#
#sub match_run($self,$branch) {
#
#  my $out  = 0;
#  my $st   = $branch->{value};
#
#  my $mach = $self->{mach};
#  my @path = $mach->{scope}->path();
#
#  my $v    = $st->{v}->{value};
#  my $re   = $st->{re};
#
#  # use/ignore whitespace
#  my $chk=($st->{flg}->{-sigws})
#    ? $v=~ m[$re]
#    : $v=~ m[$re]x
#    ;
#
#  # ^save matches
#  if($chk) {
#
#    my $match=$mach->{scope}->get(
#      @path,q[~:rematch]
#
#    );
#
#    for my $key(keys %-) {
#      $match->{$key}=$-{$key};
#
#    };
#
#    $out=1;
#
#  };
#
#  return $out;
#
#};

# ---   *   ---   *   ---
# pop current block

  rule('%<ret-key=ret>');
  rule('<ret> ret-key opt-nterm');

# ---   *   ---   *   ---

sub ret_ctx($self,$branch) {

  my $mach = $self->{mach};
  my $n    = 1;

  $mach->{scope}->ret($n);

};

# ---   *   ---   *   ---
# procedure calls

  rule('%<call-key=call>');
  rule('<call> call-key value vlist');

# ---   *   ---   *   ---
# ^post-parse

sub call($self,$branch) {

  my $st=$branch->bhash(0,1);
  $branch->clear();

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
  my $procr = $mach->{scope}->search(

    (join q[::],@{$st->{fn}},q[$branch]),
    @path,

  );

  $st->{fn}=$$procr;

  for my $arg(@{$st->{args}}) {
    next if ! ($arg=~ m[^$REGEX->{bare}$]);
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

#  Readonly our $FCALL=>{
#
#    name=>'fcall',
#    chld=>[
#      $MATCH
#
#    ],
#
#  };
#
#  Readonly our $FC_OR_V=>{
#
#    name => 'fc_or_v',
#
#    dom  => 'Grammar::peso',
#    fn   => 'fc_or_v',
#
#    chld => [Grammar::ralt(
#      $FCALL,$VALUE
#
#    )],
#
#  };
#
## ---   *   ---   *   ---
## wat
#
#sub fc_or_v($self,$branch) {
#
#  my $par=$branch->{parent};
#
#  for my $nd(@{$branch->{leaves}}) {
#    $branch->pluck($nd) if !$nd->{mfull};
#
#  };
#
#  my $type=$branch->{leaves}->[0]->{value};
#
#  if($type eq 'value') {
#    $branch=$branch->flatten_branch();
#
#  };
#
#  $branch=$branch->flatten_branch();
#  $branch->{value}='eval';
#
#};

# ---   *   ---   *   ---

#  Readonly our $COND_BEG=>{
#
#    name  => 'branch_beg',
#
#    dom   => 'Grammar::peso',
#    fn    => 'cond_beg',
#
#    chld  => [
#
#      {
#
#        name=>'nid',chld=>[{
#
#          fn   => 'capt',
#          name => Lang::eiths(
#
#            [qw(on or)],
#
#            brwap  => 1,
#            insens => 1,
#
#          ),
#
#        }],
#
#      },
#
#      $FC_OR_V
#
#    ],
#
#  };
#
## ---   *   ---   *   ---
#
#  Readonly our $IVCALL=>{
#
#    name => 'ivcall',
#    chld => [
#
#      $VLIST,
#      {name=>qr{\-\>\*}},
#
#      $VALUE,
#
#    ],
#
#  };
#
#  Readonly our $DEFCALL=>{
#
#    name => 'defcall',
#    chld => [
#
#      $VALUE,
#      $VLIST,
#
#    ],
#
#  };
#
## ---   *   ---   *   ---
#
#  Readonly our $FUCK=>{
#
#    name => 'fuck',
#    fn   => 'clip',
#
#    chld => [Grammar::ralt(
#      $IVCALL,$DEFCALL
#
#    )],
#
#  };
#
## ---   *   ---   *   ---
#
#  Readonly our $EXPR=>{
#
#    name => 'expr',
#
#    chld => [
#
#      {name=>qr[\{]},
#
#      $FUCK,
#
#      {name=>qr[\}]},
#
#    ],
#
#  };
#
## ---   *   ---   *   ---
#
#  Readonly our $TEST=>{
#
#    name  => 'test',
#
#    fn    => 'sxtest',
#    dom   => 'Grammar::peso',
#
#    chld => [Grammar::ralt(
#      $VLIST,$EXPR
#
#    )],
#
#  };
#
## ---   *   ---   *   ---
#
#sub sxtest($self,$branch) {
#  $branch->prich();
#
#};
#
## ---   *   ---   *   ---
#
#  Readonly our $COND_END=>{
#
#    name  => 'branch_end',
#
#    dom   => 'Grammar::peso',
##    fn    => 'cond_end',
#
#    chld  => [
#
#      {
#
#        name=>'nid',chld=>[{
#
#          fn   => 'capt',
#          name => Lang::eiths(
#
#            [qw(off)],
#
#            brwap  => 1,
#            insens => 1,
#
#          ),
#
#        }],
#
#      },
#
#    ],
#
#  };
#
## ---   *   ---   *   ---
#
#sub cond_beg_ctx($self,$branch) {
#
#  my $idex  = $branch->{idex};
#  my $depth = 0;
#
#  my @lv    = @{$branch->{parent}->{leaves}};
#  @lv       = @lv[$idex+1..$#lv];
#
#  $idex     = 0;
#
#  for my $nd(@lv) {
#
#    if($nd->{value} eq 'branch_end') {
#      $depth--;
#
#    } elsif($nd->{value} eq 'branch_beg') {
#      $depth++;
#
#    };
#
#    last if $depth<0;
#    $idex++;
#
#  };
#
#  @lv=@lv[0..$idex-1];
#  $branch->{-pest}=$branch->bhash();
#
#  $branch->pluck($branch->branches_in(
#    qr{^nid|eval$}
#
#  ));
#
#  $branch->pushlv(@lv);
#
#};
#
## ---   *   ---   *   ---
#
#sub cond_beg_run($self,$branch) {
#
#  my $st=$branch->{-pest};
#  my $ev=$st->{eval};
#
#  my $ok=0;
#
#  for my $nd(@{$ev->{leaves}}) {
#    $ok|=$nd->{chain}->[-1]->($self,$nd);
#
#  };
#
#  if(! $ok) {
#
#    my $callstk = $self->{callstk};
#    my $size    = @{$branch->{leaves}};
#
#    for(0..$size-1) {
#      shift @$callstk;
#
#    };
#
#  };
#
#};

# ---   *   ---   *   ---
# value expansion

sub vex($self,$fet,$vref,@path) {

  my $mach=$self->{mach};

  # default to current scope
  @path=$mach->{scope}->path()
  if ! @path;

  my $out=$mach->{scope}->cderef(
    $fet,$vref,@path,q[$LIS]

  ) or $mach->{scope}->cderef(
    $fet,$vref,@path

  );

  return $out;

};

# ---   *   ---   *   ---
# ^batch

sub array_vex($self,$fet,$ar,@path) {

  my @ar=@$ar;

  for my $v(@ar) {
    $self->vex($fet,\$v,@path);

  };

  my $valid=int(
    grep {defined $ARG} @ar

  ) eq @ar;

  my @out=($valid)
    ? @ar
    : ()
    ;

  return @out;

};

# ---   *   ---   *   ---
# ^name/ptr

sub bare_vex($self,$o) {

  my $raw=$o->{raw};
  my $out=($self->vex(0,\$raw))
    ? $raw->{value}
    : undef
    ;

  return $out;

};

# ---   *   ---   *   ---
# ^unary calls

sub flg_vex($self,$o) {

  my $raw  = $o->{raw};
  my $out  = $NULLSTR;

  my $mach = $self->{mach};
  my @path = $mach->{scope}->path();

  if($raw->{sigil} eq q[~:]) {

    my $rem=$mach->{scope}->get(
      @path,q[~:rematch]

    );

    my $key=$raw->{name};
    $out=pop @{$rem->{$key}};

  };

  return $out;

};

# ---   *   ---   *   ---
# ^strings

sub str_vex($self,$o) {

  my $raw = $o->{raw};

  my $re  = $REGEX->{repl};
  my $ct  = $raw->{ct};

  if($raw->{ipol}) {

    while($ct=~ $re) {

      my $name  = $+{capt};
      my $value = $self->bare_vex($name);

      $ct=~ s[$re][$value];

    };

    nobs(\$ct);

  };

  return $ct;

};

# ---   *   ---   *   ---
# ^operations

sub ops_vex($self,$o) {

  my @values=map {
    $self->deref($ARG)

  } @{$o->{V}};

  return {

    raw  => $self->opres_flat($o,@values),
    type => $values[0]->{type}

  };

};

# ---   *   ---   *   ---
# applies value expansion when needed

sub deref($self,$v) {

  my $out=$v;

  if($self->needs_deref($v)) {
    my $fn = $v->{type} . '_vex';
    $out   = $self->$fn($v);

  };

  return $out;

};

# ---   *   ---   *   ---
# ^check value can be derefenced

sub needs_deref($self,$v) {

  state $re=qr{(?:bare|str|flg|re|ops)};

  return
     is_hashref($v)
  && $v->{type}=~ $re
  ;

};

# ---   *   ---   *   ---
# ^batch

sub array_needs_deref($self,@ar) {

  return int(grep {
    $self->needs_deref($ARG)

  } @ar) eq @ar;

};

# ---   *   ---   *   ---
# solves compound regexes

sub detag($self,$o) {

  my @tags=();

  my $mach=$self->{mach};
  my @path=$mach->{scope}->path();

  while($o=~ s[$REGEX->{tag}][$Shwl::PL_CUT]) {

    my @ar=split q[\|],$+{capt};

    for my $name(@ar) {

      my @npath = split $REGEX->{nsop},$name;
      $name     = pop @npath;

      push @npath,'re',$name;

      my $rer=$mach->{scope}->search(

        (join q[::],@npath),
        @path

      );

      $name=$$rer;

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

  if(! $flags->{-sigws}) {
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
# groups

  # default F
  rule('|<bltn> &clip sow reap');

  # non-terminated
  rule('|<meta> &clip lcom');

  # ^else
  rule(q[

    |<needs-term-list>
    &clip

    header hier sdef
    wed lis

    re io ptr-decl
    switch
    bltn


  ]);

  rule(q[

    <needs-term>
    &clip

    needs-term-list term

  ]);

# ---   *   ---   *   ---
# ^generate rules

  our @CORE=qw(meta needs-term);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
# test

  my $src=$ARGV[0];
  $src//='lps/peso.rom';

  my $prog=($src=~qr{\.rom$})
    ? orc($src)
    : $src
    ;

  return if ! $src;

  $prog =~ m[([\S\s]+)\s*STOP]x;
  $prog = ${^CAPTURE[0]};

  my $ice=Grammar::peso->parse($prog,-r=>3);

  $ice->{p3}->prich();
#  $ice->{mach}->{scope}->prich();

  $ice->run(

    entry=>1,
    keepx=>1,

    input=>[

      '-hey',

    ],

  );

# ---   *   ---   *   ---
1; # ret
