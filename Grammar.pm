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

  use Tree::Exec;
  use Tree::Grammar;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.2;#b
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

  our $Top    = undef;
  our $Rules  = {};
  our $Icemap = {};

  Readonly our $REGEX=>{};

# ---   *   ---   *   ---
# adds to your namespace

  my @EXPORT=qw(

    rule
    ext_rule
    ext_rules

    drule
    dext_rule
    dext_rules

  );

# ---   *   ---   *   ---
# custom inheritance mambo

  sub import(@args) {

    my ($pkg)=caller;

    return

    if ! ($pkg=~ $IS_GRAMMAR)
    || exists $Icemap->{$pkg}
    ;


    # get passed switches
    my $O={
      dynamic => 0

    };

    map {$O->{$ARG}=1} @args;


    # make subclass
    no strict 'refs';

    for my $sym(@EXPORT) {
      *{"$pkg\::$sym"}=*{"$sym"};

    };

    push @{"$pkg\::ISA"},'Grammar';


    # ^register
    no warnings;

    if($O->{dynamic}) {
      $O->{icemap}={};

    } else {
      ${"$pkg\::Rules"} = {};

    };

    $Icemap->{$pkg}=$O;

  };

# ---   *   ---   *   ---
# ^initialize parsers

  INIT {

    no strict 'refs';

    map {

      my $class=$Icemap->{$ARG};

      $ARG->mkrules(@{"$ARG\::CORE"})
      if ! $class->{dynamic};

    } keys %$Icemap;

  };

# ---   *   ---   *   ---
# returns our $Top for calling package

sub get_top($class) {

  # dynamic
  if(length ref $class) {
    return $class->{top};

  # static
  } else {
    no strict 'refs';
    return ${"$class\::Top"};

  };

};

# ---   *   ---   *   ---
# ^set

sub set_top($class,$name) {

  my $f=Tree::Grammar->get_frame();

  # dynamic
  if(length ref $class) {
    $class->{top}=$f->nit(value=>$name);
    return $class->{top};

  # static
  } else {

    no strict 'refs';

    ${"$class\::Top"}=$f->nit(value=>$name);
    return ${"$class\::Top"};

  };

};

# ---   *   ---   *   ---
# get module's regex table

sub get_retab($class) {

  # dynamic
  if(length ref $class) {
    return $class->{regex};

  # static
  } else {
    no strict 'refs';
    return ${"$class\::REGEX"};

  };

};

# ---   *   ---   *   ---
# get rules declared by module

sub get_ruletab($class) {

  # dynamic
  if(length ref $class) {
    return $class->{rules};

  # static
  } else {
    no strict 'refs';
    return ${"$class\::Rules"};

  }

};

# ---   *   ---   *   ---
# ^add rule to list

sub push_rule($class,$rule) {
  my $tab=$class->get_ruletab();
  $tab->{$rule->{name}}=$rule;

};

# ---   *   ---   *   ---
# ^get from list

sub fetch_rule($class,$name) {

  my $tab=$class->get_ruletab();

  throw_bad_rfetch($class,$name)
  if ! exists $tab->{$name};

  return $tab->{$name};

};

# ---   *   ---   *   ---
# ^errme

sub throw_bad_rfetch($class,$name) {

  $class=$class->{pkg}
  if length ref $class;

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
  $O{iced} //= undef;
  $O{idex} //= 0;
  $O{mach} //= {idex=>$O{idex}};
  $O{frame_vars} //= {};

  # arg is cstruc or ice
  my $mach=(! Mach->is_valid($O{mach}))
    ? Mach->new(%{$O{mach}})
    : $O{mach}
    ;


  # chk class attrs
  my $gram  = undef;
  my $attrs = $Icemap->{$class};

  # ^is dynamic
  if($attrs->{dynamic}) {

    # get cstruc
    my $icemap = $attrs->{icemap};
    my $ice    = $icemap->{$O{iced}}

    or throw_dynamic_new(
      $class,$icemap,$O{iced}

    );

    $gram=$ice->get_top();

  # ^static
  } else {
    $gram=$class->get_top();

  };


  # ^make parser ice
  my $self=bless {

    frame   => $class->new_frame(),
    c3      => Tree::Exec->new_root(),

    mach    => $mach,
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

  # sync frame values to external
  map {
    $self->{frame}->{$ARG}=
      $O{frame_vars}->{$ARG}

  } keys %{$O{frame_vars}};


  # create parse tree
  $self->{p3}=$gram->new_p3($self);
  return $self;

};

# ---   *   ---   *   ---
# ^dynamic new errme

sub throw_dynamic_new($class,$icemap,$iced) {

  $iced='undef' if ! defined $iced;

  my $list=join q[,],keys %$icemap;

  errout(

    q[Invalid iced '%s' for class <%s>] . "\n"
  . q[Avail: %s],

    lvl  => $AR_FATAL,
    args => [$iced,$class,$list],

  );

};

# ---   *   ---   *   ---
# make subclass of dynamic grammar

sub dnew($class,$name,%O) {

  # defaults
  $O{dom} //= $class;

  my $self=bless {

    iced  => $name,
    pkg   => "$class\::$name",

    top   => undef,
    regex => {},
    rules => {},

    dom   => $O{dom},

  },$class;

  my $attrs=$Icemap->{$class};
  $attrs->{icemap}->{$name}=$self;

  return $self;

};

# ---   *   ---   *   ---
# ^get sub-grammar initialized

sub dhave($class,$name) {
  my $attrs=$Icemap->{$class};
  return $attrs->{icemap}->{$name};

};

# ---   *   ---   *   ---
# get number of post-parse passes

sub num_passes($self) {

  my $ar=(! length ref $self)
    ? $self->Frame_Vars()->{-passes}
    : $self->{frame}->{-passes};
    ;

  return @$ar;

};

# ---   *   ---   *   ---
# decon string using rules

sub parse($self,$s,%O) {

  # defaults
  $O{-r}   //= $self->num_passes()-1;
  $O{skip} //= 0;

  # clamp post-parse num passes
  $O{-r}=($O{-r} < 0)
    ? 0
    : $O{-r}
    ;

  # invoked as Grammar->parse
  if(! length ref $self) {
    my $class = $self;
       $self  = $class->new(%O);

  };

  # pass own context
  $O{mach}=$self->{mach};

  # run-through
  $self->{p3}->parse($s,%O);

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


  my $f     = $self->{frame};

  my $ptree = $self->{p3};
  my $ctree = $self->{c3};

  $f->{-npass}++;


  # find entry point
  my @branches=($O{entry})
    ? $self->get_entry($O{entry})
    : $ptree
    ;

  # ^build callstack
  $ctree->new_cstack($O{keepx},@branches);


  # ^exec
  $self->{mach}->set_args(@{$O{input}});
  $ctree->walk($self);

};

# ---   *   ---   *   ---
# ^similar, single branch

sub run_branch($self,$path,@input) {

  my $ptree = $self->{p3};
  my $ctree = $self->{c3};


  # get entry point
  my @branches=$self->get_entry(
    [split $DCOLON_RE,$path]

  );

  # ^build callstack
  $ctree->push_cstack();
  $ctree->new_cstack(1,@branches);


  # ^exec and restore
  $self->{mach}->set_args(@input);
  my $out=$ctree->walk($self);

  $ctree->pop_cstack();


  return $out;

};

# ---   *   ---   *   ---
# give branches marked for execution

sub get_entry($self,$entry) {

  my $mach=$self->{mach};

  my @out=(! is_arrayref($entry))
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

  my $valid=! is_coderef($name);

  for my $ext(@passes) {

    # point to slot
    my $r=\$X->{chain}->[$i++];

    # attempt fetch
    my $f=codefind($dom,$name.$ext)
    if $valid;

    # use fptr if no override provided
    $$r=(defined $f) ? $f : $$r;
    $$r//=$NOOP;

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
  if ! is_coderef($name);

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
  my $name=(length ref $class)
    ? $class->{pkg}
    : $class
    ;

  $name=~ s[^Grammar\::][];


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
  $O->{dom}   //= (length ref $class)
    ? $class->{dom}
    : $class
    ;

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
# makes single pattern for static

sub rule($s) {

  my ($class) = caller;
  my $out     = $class->rule_attrs($s);

  $class->push_rule($out);

  return $out;

};

# ---   *   ---   *   ---
# ^dynamic

sub drule($class,$s) {

  my $out=$class->rule_attrs($s);
  $class->push_rule($out);

  return $out;

};

# ---   *   ---   *   ---
# ^import from other static

sub ext_rule($other,$name) {

  my ($class) = caller;
  my $out     = $other->fetch_rule($name);

  $class->push_rule($out);

  return $out;

};

# ---   *   ---   *   ---
# ^dynamic

sub dext_rule($class,$other,$name) {

  my $out=$other->fetch_rule($name);
  $class->push_rule($out);

  return $out;

};

# ---   *   ---   *   ---
# ^bat static

sub ext_rules($other,@names) {

  my ($class) = caller;

  my @out     = map {
    $other->fetch_rule($ARG)

  } @names;

  map {$class->push_rule($ARG)} @out;

  return @out;

};

# ---   *   ---   *   ---
# ^dynamic

sub dext_rules($class,$other,@names) {

  my @out=map {
    $other->fetch_rule($ARG)

  } @names;

  map {$class->push_rule($ARG)} @out;

  return @out;

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

sub erew($self,$branch) {

  my $pending = $self->{pending}->[-1];
  my $anchors = $self->{anchors}->[-1];
  my $other   = $branch->{other};

  my $par     = (is_qre($other->{value}))
    ? $other->{parent}->{parent}
    : $other->{parent}
    ;

  my $anchor  = (defined $anchors->[-1])
    ? $anchors->[-1]
    : $branch
    ;

  my $status  = $anchor->status_ok();

  unshift @$pending,
    @{$par->{leaves}},
    $branch->depth(),

  if $status && defined $par;

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
# ^applied to children

sub cclip($self,$branch) {

  for my $nd(@{$branch->{leaves}}) {
    clip($self,$nd);

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

  @{$self->{pending}->[-1]}=()
  unless ! defined $self->{pending}->[-1];

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
# removes first and last leaf

sub tween($self,$branch) {

  my @lv=@{$branch->{leaves}};

  # throw if lv < 3

  $branch->pluck($lv[0],$lv[-1]);

};

# ---   *   ---   *   ---
# ^for nested rules

sub tween_clip($self,$branch) {

  tween($self,$branch);

  for my $nd(@{$branch->{leaves}}) {
    clip($self,$nd);

  };

};

# ---   *   ---   *   ---
1; # ret
