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

  our $VERSION = v0.00.6;#b
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
# GBL

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

  my $tree    = $self->{tree};
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
# creates rule alternation

sub ralt(@rules) {

  my @out=map {$ARG,$OR} @rules;
  pop @out;

  return @out;

};

# ---   *   ---   *   ---
1; # ret
