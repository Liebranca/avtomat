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

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/avtomat/sys/';

  use Style;
  use Chk;

  use Mach;

  use Arstd::Array;
  use Arstd::IO;

  use Tree::Grammar;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  our $OR={
    name=>q[|]

  };

  sub Frame_Vars($class) { return {

    -ns     => {'$decl:order'=>[]},
    -cns    => [],

    -npass  => 0,
    -passes => [],

  }};

# ---   *   ---   *   ---
# global state

  our $Top;

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
# decon string using rules

sub parse($class,$prog,%O) {

  # defaults
  $O{-r}   //= 0;
  $O{idex} //= 0;
  $O{mach} //= {};

  my $self=bless {
    frame   => $class->new_frame(),
    callstk => [],

    mach    => undef,

  },$class;

  $O{mach}->{ctx}=$self;

  my $mach_f = Mach->get_frame($O{idex});
  my $mach   = $mach_f->nit(%{$O{mach}});

  $self->{mach}=$mach;

  unshift @{
    $self->{frame}->{-passes}

  },$NULLSTR;

  my $gram=$class->get_top();
  my $tree=$gram->parse($self,$prog);

  # exec -r number of passes
  while($O{-r}--) {
    $class->run($tree);

  };

  return $tree;

};

# ---   *   ---   *   ---
# ^executes tree

sub run($class,$tree,%O) {

  # defaults
  $O{entry}//=0;
  $O{keepx}//=0;
  $O{input}//=[];

  my $ctx = $tree->{ctx};
  my $f   = $ctx->{frame};

  $f->{-npass}++;

  my $callstk=$ctx->{callstk};

  # find entry point
  my @branches=($O{entry})
    ? $ctx->get_entry($tree,$O{entry})
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
    $ctx->{mach}->stkpush($arg);

  };

  # ^execute
  while(@$callstk) {

    my $ref=shift @$callstk;

    my ($nd,$fn)=@$ref;
    $fn->($nd);

  };

};

# ---   *   ---   *   ---
# give branches marked for execution

sub get_entry($ctx,$tree,$entry) {

  my @out=(!is_arrayref($entry))
    ? $ctx->get_clan_entries($tree)
    : $ctx->ns_get(@$entry,q[$branch])
    ;

  return @out;

};

# ---   *   ---   *   ---
# finds all branches declared as entry points

sub get_clan_entries($ctx,$tree) {

  my @out=();

  for my $key(keys %{$ctx->{frame}->{-ns}}) {

    next if $key eq q[$decl:order];

    # get name of entry proc
    my $name=$ctx->ns_get(
      $key,'$DEF','ENTRY'

    );

    # ^fetch
    my @path = ($key,@$name,q[$branch]);
    my $o    = $ctx->ns_get(@path);

    # ^validate
    throw_invalid_entry(@path)
    if !%$o || !Tree::Grammar->is_valid($o);

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

  my $valid  = !is_coderef($name);

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

sub fnbreak($class,$X) {

  my ($name,$dom)=($X->{fn},$X->{dom});

  $name //= $X->{name};
  $dom  //= 'Tree::Grammar';

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

    my $value=shift @rules;

    # go back one step in hierarchy
    if($value eq 0) {
      pop @anchors;
      next;

    # grammar incorporates another
    } elsif(!is_hashref($value)) {

      my $subgram=q[Grammar::].$value;
         $subgram=$subgram->get_top();

      $top->pushlv(@{$subgram->{leaves}});

      next;

    };

    # get parent node
    my $anchor=$anchors[-1];

    $class->fnbreak($value);

    # instantiate
    my $nd=$anchor->init(

      $value->{name},

      fn    => $value->{fn},

      opt   => $value->{opt},
      greed => $value->{greed},

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
# add object to specific namespace

sub ns_decl($self,$o,@path) {

  my $ns    = $self->{frame}->{-ns};
  my $order = $ns->{'$decl:order'};

  push @$order,\@path;
  ns_asg($self,$o,@path);

};

# ---   *   ---   *   ---
# gets reference from path

sub ns_fetch($self,@path) {

  my $ns  = $self->{frame}->{-ns};
  my $dst = \$ns;

  for my $key(@path) {

    next if !$key;

    throw_bad_fetch(@path)
    if !is_hashref($$dst);

    $$dst->{$key}//={};
    $dst=\($$dst->{$key});

  };

  return $dst;

};

# ---   *   ---   *   ---
# ^similar, returns existance of path

sub ns_exists($self,@path) {

  my $ns  = $self->{frame}->{-ns};
  my $dst = \$ns;

  my $out = 1;

  for my $key(@path) {

    next if !$key;

    if(

       !is_hashref($$dst)
    || !exists $$dst->{$key}

    ) {

      $out=0;
      last;

    };

    $dst=\($$dst->{$key});

  };

  return $out;

};


# ---   *   ---   *   ---
# ^errme

sub throw_bad_fetch(@path) {

  my $path=join q[/],@path;

  errout(

    q[Invalid path; FET <%s>],

    args => [$path],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# ^same, assigment without order

sub ns_asg($self,$o,@path) {

  my $dst = $self->ns_fetch(@path);
  $$dst   = $o;

};

# ---   *   ---   *   ---
# ^fetches value

sub ns_get($self,@path) {

  my $o=$self->ns_fetch(@path);
  return $$o;

};

# ---   *   ---   *   ---
# dirty and quick backwards evaluating
# to find across namespaces

sub ns_search($self,$name,$sep,@path) {

  my @out=$self->ns_search_nc(
    $name,$sep,@path

  );

  throw_bad_fetch(@out)
  if !($self->ns_exists(@out));

  return @out;

};

# ---   *   ---   *   ---
# ^no errchk

sub ns_search_nc($self,$name,$sep,@path) {

  my @alt=split $sep,$name;

  while(@path) {
    last if $self->ns_exists(@path,@alt);
    pop @path;

  };

  return (@path,@alt);

};

# ---   *   ---   *   ---
# conditionally dereference
# the "condition" being existance of value

sub ns_cderef($self,$fet,$sep,$vref,@path) {

  my @rpath = $self->ns_search_nc(
    $$vref,$sep,@path

  );

  my $valid = $self->ns_exists(@rpath);
  my $fn    = ($fet) ? \&ns_fetch : \&ns_get;

  $$vref    = $fn->($self,@rpath) if $valid;

  return $valid;

};

# ---   *   ---   *   ---
# associates path with a tree node

sub ns_mkbranch($self,$o,@path) {

  throw_invalid_branchref($o,@path)
  if !Tree::Grammar->is_valid($o);

  ns_decl($self,$o,@path,q[$branch]);

};

# ---   *   ---   *   ---
# ^errme

sub throw_invalid_branchref($o,@path) {

  my $path=join q[/],@path;

  errout(

    q[Object at <%s> is not a ].
    q[Tree::Grammar instance but a %s],

    args => [$path,ref $o],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
1; # ret
