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

  our $VERSION = v0.01.0;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

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

  Readonly our $PE_SDEFS=>{

    VERSION => 'v0.00.1b',
    AUTHOR  => 'anon',
    ENTRY   => 'crux',

  };

# ---   *   ---   *   ---

  Readonly our $REGEX=>{

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
  rule('<header> &rdhed sigil opt-nterm');

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

  rule('~<type>');
  rule('~<spec>');
  rule('*<specs> &clip spec');

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

  $branch->clear_branches();

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

  $branch->clear_branches();

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
  rule('<flg> sigil flg-name');
  rule('<flist> flg clist');

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

  $branch->clear_branches();

};

# ---   *   ---   *   ---
# combo

  rule(q[

    |<value>
    &value_sort

    num str flg bare

  ]);

# ---   *   ---   *   ---
# ^handler

sub value_sort($self,$branch) {

  my $st     = $branch->bhash();
  my $xx     = $branch->leaf_value(0);

  my ($type) = keys %$st;

  if(is_hashref($xx)) {
    $type='flg';

  };

  $branch->clear_branches();

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

    <hier>
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

  $branch->clear_branches();

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
  if(!@cur) {
    @cur=$self->cpath()

  };

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

  my @out=();

  # alter type for tree search
  if($type eq 'REG' || $type eq 'ROM') {
    $type=q[REG|ROM];

  };

  # get nodes up to next hierarchical
  @out=$branch->{parent}->match_until(
    $branch,qr{^$type$}

  );

  # ^all remaining on fail
  @out=$branch->{parent}->all_from(
    $branch

  ) if ! @out;

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

  rule('<full-type> type specs');
  rule('<nlist> &list_flatten bare clist');
  rule('<vlist> &list_flatten value clist');

  rule('?<opt-vlist> &clip vlist');

  # ^combo
  rule(q[

    <ptr-decl>
    &ptr_decl

    full-type nlist opt-vlist

  ]);

# ---   *   ---   *   ---
# pushes constructors to current namespace

sub ptr_decl($self,$branch) {

#  # flatten lists
#  for my $key(qw(names flg value)) {
#
#    my @ar=$branch->branches_in(
#      qr{^$key$},
#      max_depth=>1,
#
#    );
#
#    Grammar::list_flatten($self,@ar);
#
#  };
#
##  $branch->branch_in(
##    qr{^specs$}
##
##  )->flatten_branch();
#
#  # hashrefy
#  my $st    = $branch->bhash(1,1,1);
#
#  # first value is type
#  # rest is specifiers
#  my $type  = shift @{$st->{type}};
#  my @specs = @{$st->{type}};
#
#  # ^put together
#  $branch->{value}={
#
#    type   => $type,
#    specs  => \@specs,
#
#    names  => $st->{names},
#    values => $st->{values},
#
#  };
#
#  $branch->clear_branches();

};

# ---   *   ---   *   ---
# ^pre-run step

sub ptr_decl_ctx($self,$branch) {

$branch->prich();
exit;

  my $st     = $branch->{value};
  my $mach   = $self->{mach};
  my @path   = $mach->{scope}->path();
  my $type   = $st->{type};

  my $f      = $self->{frame};

  my @names  = @{$st->{names}};
  my @values = @{$st->{values}};

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
  my $type   = $st->{type};
  my @specs  = @{$st->{specs}};
  my @names  = @{$st->{names}};
  my @values = @{$st->{values}};

  # ctx
  my $mach=$self->{mach};
  my @path=$mach->{scope}->path();

  # dst
  my $ptrs=[];

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

  $branch->{value}=$ptrs;

};

  rule('~<io-type>');
  rule('<io> &rdio io-type ptr-decl');

# ---   *   ---   *   ---
# ^forks

sub rdio($self,$branch) {

  state $table={
    io  => undef,

    out => undef,
    in  => 'rdin',

  };

  my $st=$branch->bhash();

  say {*STDERR}
    "rdio fork not implemented";

  exit;

};

# ---   *   ---   *   ---
# ^proc input

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

  rule('%<beg_curly=\{>');
  rule('%<end_curly=\}>');
  rule('<vglob> beg_curly flg end_curly');

# ---   *   ---   *   ---
# aliasing

  rule('%<lis-key=lis>');
  rule('<lis> lis-key vglob value');

# ---   *   ---   *   ---
# ^post-parse

sub lis($self,$branch) {

  my $st=$branch->bhash();

  $branch->{value}={

    from => $st->{value},
    to   => $st->{vglob},

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

  $branch->clear_branches();

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

  $branch->clear_branches();2

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
  rule('<sdef> sdef-name nterm');

# ---   *   ---   *   ---
# placeholder for special defs

sub sdef($self,$branch) {

  my $st=$branch->bhash(0,0);

  $branch->{value}={
    name  => $st->{q[sdef-name]},
    value => $st->{nterm},

  };

  $branch->clear_branches();

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
  rule('<wed> wed-type flist');

# ---   *   ---   *   ---
# ^handler

sub wed($self,$branch) {

  my $st=$branch->bhash(0,1);

  $branch->{value}={

    type  => uc $st->{type},
    flags => $st->{flags},

  };

  $branch->clear_branches();

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
  rule('<re> &rdre re-type seal nterm');

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

  $branch->clear_branches();
  $branch->{value}="$st->{type}:$st->{seal}";

};

# ---   *   ---   *   ---
# test

  rule('~<ops>');

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
#  $branch->clear_branches();
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

  $mach->{scope}->cderef(
    $fet,$vref,@path,q[$LIS]

  ) or $mach->{scope}->cderef(
    $fet,$vref,@path

  );

};

# ---   *   ---   *   ---
# ^batch

sub array_vex($self,$fet,$ar,@path) {

  for my $v(@$ar) {
    $self->vex($fet,\$v,@path);

  };

};

# ---   *   ---   *   ---
# ^name/ptr

sub bare_vex($self,$raw) {

  $self->vex(0,\$raw);
  return $raw->{value};

};

# ---   *   ---   *   ---
# ^unary calls

sub flg_vex($self,$raw) {

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

sub str_vex($self,$raw) {

  my $re=$REGEX->{repl};
  my $ct=$raw->{ct};

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
# applies value expansion when needed

sub deref($self,$v) {

  my $out=$v;

  if(is_hashref($v)) {

    my $fn = $v->{type} . '_vex';
    $out   = $self->$fn($v->{raw});

  };

  return $out;

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

  # non-terminated
  rule('|<meta> &clip lcom');

  # ^else
  rule(q[

    |<needs-term-list>

    hier ptr-decl header sdef


  ]);

  rule(q[

    <needs-term>
    &clip

    needs-term-list term

  ]);

# ---   *   ---   *   ---
# ^generate rules

  our @CORE=qw(ptr-decl);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
# test

  my $src  = $ARGV[0];
     $src//= 'lps/peso.rom';

  my $prog = orc($src);

  $prog    =~ m[([\S\s]+)\s*STOP]x;
  $prog    = ${^CAPTURE[0]};

  my $ice  = Grammar::peso->parse($prog,-r=>2);

  $ice->{p3}->prich();
  $ice->{mach}->{scope}->prich();

#  $ice->run(
#
#    entry=>1,
#    keepx=>1,
#
#    input=>[
#
#      '-hey',
#
#    ],
#
#  );

# ---   *   ---   *   ---
1; # ret
