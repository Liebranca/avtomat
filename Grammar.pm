#!/usr/bin/perl
# ---   *   ---   *   ---
# GRAMMAR
# Base class for all
# lps-derived parsers
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/avtomat/sys/';

  use Style;
  use Chk;
  use Queue;

  use Mach;

  use Arstd::Array;
  use Arstd::IO;

  use Tree::Grammar;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) { return {

    -ns     => {'$decl:order'=>[]},
    -cns    => [],

    -npass  => 0,
    -passes => [],

  }};

  Readonly my $IS_GRAMMAR=>qr{
    ^Grammar::

  }x;

  Readonly my $RULE_RE=>qr{

    \s*
    (?<sign> [\$ \%\~\|\?\+\*]+ )?

    \s*
    (?<max> \d+)?

    \s* < \s*
    (?<name> [^>]+ )

    \s* > \s*

    (?<has_fn>

      \& \s*
      (?<fn> [\w:]+)?

    )?

    \s*
    (?<chld> [\S\s]+ )?

    \s*

  }x;

# ---   *   ---   *   ---
# GBL

  our $Top     = undef;
  our $Rules   = {};
  our $Ice_Map = {};

  Readonly our $REGEX=>{};

# ---   *   ---   *   ---
# adds to your namespace

  my @EXPORT=qw(
    rule

  );

# ---   *   ---   *   ---
# custom inheritance mambo

  sub import {

    my ($pkg)=caller;

    return

    if ! ($pkg=~ $IS_GRAMMAR)
    || exists $Ice_Map->{$pkg}
    ;

    no strict 'refs';

    for my $sym(@EXPORT) {
      *{"$pkg\::$sym"}=*{"$sym"};

    };

    push @{"$pkg\::ISA"},'Grammar';

    no warnings;
    ${"$pkg\::Rules"}={};

    $Ice_Map->{$pkg}=1;

  };

# ---   *   ---   *   ---
# ^initialize parsers

  INIT {

    no strict 'refs';

    map {
      $ARG->mkrules(@{"$ARG\::CORE"});

    } keys %$Ice_Map;

  };

# ---   *   ---   *   ---
# returns our $Top for calling package

sub get_top($class) {

  no strict 'refs';
  return ${"$class\::Top"};

};

sub set_top($class,$name) {

  no strict 'refs';

  my $f=Tree::Grammar->get_frame();
  ${"$class\::Top"}=$f->nit(value=>$name);

  return ${"$class\::Top"};

};

# ---   *   ---   *   ---
# get module's regex table

sub get_retab($class) {
  no strict 'refs';
  return ${"$class\::REGEX"};

};

# ---   *   ---   *   ---
# get rules declared by module

sub get_ruletab($class) {
  no strict 'refs';
  return ${"$class\::Rules"};

};

sub push_rule($class,$rule) {
  my $tab=$class->get_ruletab();
  $tab->{$rule->{name}}=$rule;

};

sub fetch_rule($class,$name) {
  my $tab=$class->get_ruletab();

  throw_bad_rfetch($class,$name)
  if ! exists $tab->{$name};

  return $tab->{$name};

};

# ---   *   ---   *   ---
# ^errme

sub throw_bad_rfetch($class,$name) {

  errout(

    q[Cannot find <%s> ] .
    q[in %s::Rules],

    args => [$name,$class],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# make parser ice

sub new($class,%O) {

  # defaults
  $O{idex} //= 0;
  $O{mach} //= {idex=>$O{idex}};

  # make new
  my $gram=$class->get_top();
  my $self=bless {
    frame   => $class->new_frame(),
    callstk => [],

    mach    => Mach->new(%{$O{mach}}),
    Q       => Queue->nit(),
    gram    => $gram,

    anchors => [],
    pending => [],

  },$class;

  # first pass is blank
  # that means 'parsing stage'
  unshift @{
    $self->{frame}->{-passes}

  },$NULLSTR;

  # create parse tree
  $self->{p3}=$gram->new_p3($self);
  return $self;

};

# ---   *   ---   *   ---
# decon string using rules

sub parse($self,$s,%O) {

  # defaults
  $O{-r}//=0;

  # invoked as Grammar->parse
  if(! length ref $self) {
    my $class = $self;
       $self  = $class->new(%O);

  };

  # run-through
  $self->{p3}->parse($s);

  # exec -r number of passes
  while($O{-r}--) {
    $self->run();

  };

  return $self;

};

# ---   *   ---   *   ---
# ^execute tree from ice

sub run($self,%O) {

  # defaults
  $O{entry}//=0;
  $O{keepx}//=0;
  $O{input}//=[];

  my $tree    = $self->{p3};
  my $f       = $self->{frame};
  my $callstk = $self->{callstk};

  $f->{-npass}++;

  # find entry point
  my @branches=($O{entry})
    ? $self->get_entry($O{entry})
    : $tree
    ;

  # build callstack
  for my $branch(@branches) {

    my @refs=$branch->shift_branch(
      keepx=>$O{keepx}

    );

    push @$callstk,@refs;

  };

  for my $arg(reverse @{$O{input}}) {
    $self->{mach}->stkpush($arg);

  };

  # ^execute
  while(@$callstk) {

    my $ref=shift @$callstk;

    my ($nd,$fn)=@$ref;
    $fn->($self,$nd);

  };

};

# ---   *   ---   *   ---
# give branches marked for execution

sub get_entry($self,$entry) {

  my $mach=$self->{mach};

  my @out=(!is_arrayref($entry))
    ? $self->get_clan_entries()
    : $mach->{scope}->get(@$entry,q[$branch])
    ;

  return @out;

};

# ---   *   ---   *   ---
# finds all branches declared as entry points

sub get_clan_entries($self) {

  my @out  = ();

  my $mach = $self->{mach};
  my $tree = $mach->{scope}->{tree};

  for my $branch(@{$tree->{leaves}}) {

    my $key=$branch->{value};
    next if $key eq q[$decl:order];

    # get name of entry proc
    my $procn=$mach->{scope}->has(
      $key,'ENTRY'

    );

    next if ! defined $procn;

    # ^fetch
    my @path = ($key,@{$$procn},q[$branch]);
    my $o    = $mach->{scope}->get(@path);

    # ^validate
    throw_invalid_entry(@path)
    if ! Tree::Grammar->is_valid($o);

    push @out,$o;


  };

  return @out;

};

# ---   *   ---   *   ---
# ^errme

sub throw_invalid_entry(@path) {

  my $path=join q[/],@path;

  errout(

    q[Path <%s> points to null],

    args => [$path],
    lvl  => $AR_FATAL,


  );

};

# ---   *   ---   *   ---
# ensure chain slot per pass

sub cnbreak($class,$X,$dom,$name) {

  my $vars   = $class->Frame_Vars();
  my @passes = (@{$vars->{-passes}});

  my $i=0;
  $X->{chain}//=[];

  my $valid=!is_coderef($name);

  for my $ext(@passes) {

    # get context
    my $r=(undef,\($X->{chain}->[$i]));
    my $f=codefind($dom,$name.$ext)
    if $valid;

    # use fptr if no override provided
    $$r=(defined $f) ? $f : $$r;
    $$r//=$NOOP;

    $i++;

  };

};

# ---   *   ---   *   ---
# branch function search
#
# generates [dom]::[rule]_[pass] fn array
# ie, chains

sub fnbreak($class,$X) {

  my ($name,$dom)=($X->{fn},$X->{dom});

  $name //= $X->{name};
  $dom  //= 'Grammar';

  goto SKIP if is_qre($name);

  # get sub matching name
  $X->{fn}=codefind($dom,$name)
  if !is_coderef($name);

  # generate chain
  $class->cnbreak($X,$dom,$name);

SKIP:

  # ^default if none found
  $X->{fn}//=$NOOP;

  return;

};

# ---   *   ---   *   ---
# generates branches from descriptor array

sub mkrules($class,@rules) {

  # shorten subclass name
  my $name    = $class;
  $name       =~ s[^Grammar\::][];

  # build root
  my $top     = $class->set_top($name);
  my @anchors = ($top);

  # walk
  while(@rules) {

    my $key=shift @rules;

    errout(

      q[mkrules encountered NULL CHLD],
      lvl=>$AR_FATAL,

    ) unless defined $key;

    # go back one step in hierarchy
    if($key eq 0) {
      pop @anchors;
      next;

    # grammar incorporates another
    } elsif($key=~ $IS_GRAMMAR) {

      my $subgram=$key->get_top();
      $top->pushlv(@{$subgram->{leaves}});

      next;

    };

    my $value = (! is_hashref($key))
      ? $class->fetch_rule($key)
      : $key
      ;

    # get parent node
    my $anchor=$anchors[-1];

    $class->fnbreak($value);

    # instantiate
    my $nd=$anchor->init(

      $value->{name},

      fn    => $value->{fn},
      hier  => $value->{hier},

      opt   => $value->{opt},
      greed => $value->{greed},
      max   => $value->{max},
      alt   => $value->{alt},

      chain => $value->{chain},

    );

    # recurse
    if($value->{chld}) {

      unshift @rules,@{$value->{chld}},0;
      push    @anchors,$nd;

    };

  };

};

# ---   *   ---   *   ---
# gives attributes from
# string repr

sub rule_attrs($class,$s) {

  throw_bad_rule($s)
  if ! ($s=~ $RULE_RE);

  my ($sign,$max,$name,$fn,$chld)=(
    $+{sign},
    $+{max},
    $+{name},
    $+{fn},
    $+{chld}

  );

  $sign //= $NULLSTR;
  $max  //= 0;
  $fn   //= $NULLSTR;
  $chld //= $NULLSTR;

  $chld   = [split $NSPACE_RE,$chld];

  my $out={

    name => $name,
    max  => int($max),

    chld => [],

  };

  $class->rfunc(

    $out,
    $fn,

    $class->rsign($out,$sign)

  );

  $class->rchld($out,$chld);
  $class->rdef($out,$name);

  return $out;

};

# ---   *   ---   *   ---
# ^defaults

sub rdef($class,$O,$name) {

  $O->{opt}   //= 0;
  $O->{alt}   //= 0;
  $O->{greed} //= 0;

  $O->{fn}    //= $name;
  $O->{dom}   //= $class;

  $O->{chld}  //= [];

};

# ---   *   ---   *   ---
# ^set re, alt, greed and opt modifiers

sub rsign($class,$O,$sign) {

  state $IS_HIER  = qr{ \$ }x;

  state $IS_OPT   = qr{[\?\*]};
  state $IS_GREED = qr{[\+\*]};

  state $IS_ALT   = $BOR_RE;
  state $IS_RE    = $ATILDE_RE;

  state $IS_LIT = qr{\%};

  $O->{hier}  = int($sign=~ $IS_HIER);
  $O->{alt}   = int($sign=~ $IS_ALT);
  $O->{opt}   = int($sign=~ $IS_OPT);
  $O->{greed} = int($sign=~ $IS_GREED);

  return $class->retab($O) if $sign=~ $IS_RE;
  return $class->relit($O) if $sign=~ $IS_LIT;

};

# ---   *   ---   *   ---
# ^make from caller's regex table

sub retab($class,$O) {

  my $retab = $class->get_retab();

  my $name  = $O->{name};
  my $ar    = $O->{chld};
  my $c     = {name=>$retab->{$name}};

  push @$ar,$c;

  return 1;

};

# ---   *   ---   *   ---
# ^make regex from name

sub relit($class,$O) {

  my $full = $O->{name};
  my $ar   = $O->{chld};

  my ($name,$value)=split m[\=],$full;

  $O->{name}=$name;
  my $c={name=>qr{$value}};

  push @$ar,$c;

  return 1;

};

# ---   *   ---   *   ---
# ^sub-rules

sub rchld($class,$O,$rule_names) {

  my $ar=$O->{chld};

  push @$ar,map {
    $class->fetch_rule($ARG)

  } @$rule_names;

};

# ---   *   ---   *   ---
# ^sets module::function

sub rfunc($class,$O,$fn,$got_re=undef) {

  my @ar    = split $DCOLON_RE,$fn;

  my $name  = pop @ar;
  my $dom   = join q[::],@ar;

  $O=$O->{chld}->[-1] if $got_re;

  $O->{fn}  = ($name) ? $name : undef;
  $O->{dom} = ($dom) ? $dom : undef;

};

# ---   *   ---   *   ---
# ^errme

sub throw_bad_rule($s) {

  errout(

    q[Invalid Grammar rule: '%s'],

    args => [$s],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# makes single pattern

sub rule($s) {

  my ($class) = caller;
  my $out     = $class->rule_attrs($s);

  $class->push_rule($out);

  return $out;

};

# ---   *   ---   *   ---
# rewind current rule

sub rew($self,$branch) {

  my $pending = $self->{pending}->[-1];
  my $anchors = $self->{anchors}->[-1];
  my $other   = $branch->{other};

  my $par     = (is_qre($other->{value}))
    ? $other->{parent}->{parent}
    : $other->{parent}
    ;

  my $anchor  = $anchors->[-1];
  my $status  = $anchor->status_ok();

  unshift @$pending,
    @{$par->{leaves}},
    $branch->depth(),

  if $status;

  discard($self,$anchor);

};

# ---   *   ---   *   ---
# replace branch with it's children

sub clip($self,$branch) {

  my $par = $branch->{parent};
  my @lv  = @{$branch->{leaves}};

  my $Q   = $self->{Q};

  $Q->add(sub {$branch->flatten_branch()});

  if($par) {
    $par->status_add($branch);

  };

};

# ---   *   ---   *   ---
# removes branch

sub discard($self,$branch) {

  my $Q   = $self->{Q};
  my $par = \$branch->{parent};

  $Q->add(sub {$$par->pluck($branch) if $$par});

};

# ---   *   ---   *   ---
# ^special case

sub lcom($self,$branch) {
  discard($self,$branch);

};

# ---   *   ---   *   ---
# terminates an expression

sub term($self,$branch) {

  discard($self,$branch);
  @{$self->{pending}->[-1]}=();

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

sub list_flatten($self,@branches) {

  # confused yet? ;>
  map {

    my @lv=@{$ARG->{leaves}};
    array_filter(\@lv);

    map {
      $ARG->flatten_branch();

    } @lv;

  } @branches;

};

# ---   *   ---   *   ---
# removes terminator from a
# rew-ed down branch

sub list_pop($self,$branch) {

  $branch->pluck($branch->{leaves}->[-1])
  if 1 < @{$branch->{leaves}};

};

# ---   *   ---   *   ---
1; # ret
