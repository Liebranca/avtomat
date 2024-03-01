#!/usr/bin/perl
# ---   *   ---   *   ---
# RD
# Code reader
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Storable;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Tree;
  use Cli;

  use Arstd::Array;
  use Arstd::IO;
  use Arstd::PM;
  use Arstd::WLog;

  use Shb7::Path;
  use Mach::Scope;

  $WLog //= Arstd::WLog->genesis();

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.8;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $SF=>{

    blank   => 0x0001,
    string  => 0x0002,
    comment => 0x0004,
    nterm   => 0x0008,
    exprbeg => 0x0010,

  };

  Readonly my $FMODE=>{

    (map {$ARG=>0x01} qw($ elf)),
    (map {$ARG=>0x02} qw(% rom)),
    (map {$ARG=>0x04} qw(@ net)),
    (map {$ARG=>0x08} qw(^ gfi)),

  };


  Readonly my $SF_DEFAULT=>
    $SF->{exprbeg};


# ---   *   ---   *   ---
# cstruc

sub new($class,$src,%O) {

  # defaults
  $O{mc}={

    cls     => 'A9M',

    memroot => 'non',
    pathsep => $DCOLON_RE,

  };


  # make parse tree root
  my $frame = Tree->new_frame();
  my $root  = $frame->new(undef,$NULLSTR);


  # file or string passed?
  my $body=$NULLSTR;

  if(is_filepath($src)) {
    $body = orc($src);
    $src  = shpath($src);

  } else {
    $body = $src;
    $src  = '(%$)';

  };


  # make ice
  my $self=bless {


    # parse tree root
    tree    => $root,


    # current l0/l1/l2 value
    char    => $NULLSTR,
    token   => $NULLSTR,
    branch  => undef,

    # nesting within current branch
    nest    => [],


    # parse layers: char/token/branch
    l0      => undef,
    l1      => undef,
    l2      => undef,

    # execution layer
    lx      => undef,
    pass    => 0,

    mc      => $O{mc}->{cls}->new(%{$O{mc}}),


    # shared vars
    status  => $SF_DEFAULT,

    # line number!
    lineno  => 1,
    lineat  => 1,

    # branch idex
    -at     => 0,

    # stringmode term
    strterm => $NULLSTR,


    # I/O
    fmode   => $FMODE->{rom},
    fpath   => $src,
    buf     => $body,


  },$class;


  # init layers and give ice
  $self->cstruc_layers();

  return $self;

};

# ---   *   ---   *   ---
# in a nutshell

sub crux($src,%O) {

  # make ice
  my $self=rd->new($src,%O);

  # ^run and give
  $self->proc_parse();
  $self->proc_ctx();

  return $self;

};

# ---   *   ---   *   ---
# advance pass

sub next_pass($self) {
  $self->{pass}++;
  $self->{-at}=0;

};

# ---   *   ---   *   ---
# cannonical tree-walk

sub step($self,$fn,@args) {

  # get next *top* branch in tree
  my $idex   = $self->{-at}++;

  my $tree   = $self->{tree}->{leaves};
  my $branch = $tree->[$idex];


  # exit if whole tree walked ;>
  return 0 if ! $branch;


  # ^walk
  my @Q=$branch;
  while(@Q) {

    # set current
    my $nd=shift @Q;
    $self->{branch}=$nd;

    # recurse only if F returns true
    unshift @Q,@{$nd->{leaves}}
    if $fn->(@args,$nd,\@Q);

  };


  # give true if branches pending
  return defined $tree->[$idex+1];

};

# ---   *   ---   *   ---
# first pass

sub proc_parse($self) {

  # select sub-class
  $self->solve_ipret();

  # parse
  $self->{l0}->proc_parse();

  # ^expr pending?
  $self->unset('blank');
  $self->term();


  # cleanup parse-only values
  delete $self->{buf};
  delete $self->{status};
  delete $self->{strterm};
  delete $self->{nest};

  # go next and give
  $self->next_pass();
  return;

};

# ---   *   ---   *   ---
# ^second pass

sub proc_ctx($self) {

  # get ctx
  my $l2 = $self->{l2};

  my $fn = (ref $l2).'::proc_ctx';
     $fn = \&$fn;

  # ^run for whole tree
  while($self->step($fn,$l2)) {};


  # go next and give
  $self->next_pass();
  return;

};

# ---   *   ---   *   ---
# push token to tree

sub commit($self) {

  # have token?
  my $have=0;

  if(length $self->{token}) {

    # classify
    $self->unset('exprbeg');
    $self->{token}=$self->{l1}->proc_parse();


    # start of new branch?
    if(! defined $self->{branch}) {

      $self->{branch}=
        $self->{tree}->inew($self->{token});

      $self->{branch}->{lineno}=
        $self->{lineat};

    # ^cat to existing
    } else {

      my $branch=
        $self->{branch}->inew($self->{token});

      $branch->{lineno}=$self->{lineat};

    };


    $self->{lineat}=$self->{lineno};
    $have |= 1;

  };


  # give true if token added
  $self->{token}=$NULLSTR;
  return $have;

};

# ---   *   ---   *   ---
# clear current if not nesting
# else make sub-branch

sub new_branch($self) {


  # leaving branch undefined will trigger
  # it's making on next token commited
  if(! @{$self->{nest}}) {
    $self->{branch}=undef;


  # ^nesting, so not so simple
  } else {

    # get last, deepest sub-branch
    my $anchor = $self->{nest}->[-1];
       $anchor = $anchor->{leaves}->[-1];

    # ^get sub-branch idex relative to it's parent
    my $idex   = int @{$anchor->{leaves}};
    my $l1     = $self->{l1};

    # ^make new sub-branch next to it
    $self->{branch}=$anchor->inew(
      $l1->make_tag('BRANCH'=>$idex)

    );

  };


  # mark beggining of expression
  $self->set('exprbeg');

};

# ---   *   ---   *   ---
# nest one sub-branch deeper

sub nest_up($self) {
  push @{$self->{nest}},$self->{branch};
  $self->new_branch();

};

# ---   *   ---   *   ---
# ^return to previous sub-branch

sub nest_down($self) {
  $self->{branch}=pop @{$self->{nest}};

};

# ---   *   ---   *   ---
# terminate branch or sub-branch

sub term($self) {

  $self->commit();
  $self->{l2}->proc_parse();
  $self->new_branch();
  $self->set_termf();

};

# ---   *   ---   *   ---
# defines whether an operator
# is a valid char for a name

sub cmd_name_rule($self) {

  return ! defined $self->{branch}

  &&  @{$self->{tree}->{leaves}}
  &&! @{$self->{nest}}
  &&! $self->blank()

  ;

};

# ---   *   ---   *   ---
# read ipret line
#
# this mutates the parser into
# a derived class!

sub solve_ipret($self) {

  # get ctx
  my $l0=$self->{l0};
  my $l1=$self->{l1};

  # parse first expression
  $l0->proc_parse_single();

  # ^decompose
  my $cmd  = $self->{tree}->{leaves}->[-1];
  my @args = @{$cmd->{leaves}};
  my $have = $cmd->{value};



  # is first token operator?
  if(defined ($have=$l1->is_opera($have))) {

    # validate sigil
    $self->perr(
      "fmode '%s' not in table",
      args=>[$have],

    ) if ! exists $FMODE->{$have};


    # set output mode from table
    my $fmode=$FMODE->{$have};

    # reset cmd
    $cmd=shift @args;
    $self->{tree}->{value} .= $have;

  };


  # subclass provided?
  if($cmd) {

    # get path to language definitions
    my $fpath="lps/$cmd->{value}.rom";

    # ^validate
    $self->perr(
      "could not find '%s'",
      args=>[$fpath],

    ) if ! -f $fpath;


    # [INSERT SUBCLASS-MUTATE]

    $self->{tree}->{value} .= $cmd;

  };


  # pop expression from tree
  $self->{tree}->{leaves}->[-1]->discard();
  $self->{token}=undef;

};

# ---   *   ---   *   ---
# set status flag

sub set($self,$name) {
  $self->{status} |= $SF->{$name};

};

# ---   *   ---   *   ---
# ^undo

sub unset($self,$name) {
  $self->{status} &=~ $SF->{$name};

};

# ---   *   ---   *   ---
# read status flags are set/unset

sub status($self,@order) {

  # array as hash
  my @fk  = array_keys(\@order);
  my @fv  = array_values(\@order);

  my $fi  = 0;
  my $out = 1;


  # ^walk
  for my $k(@fk) {


    # get [flag => expected state]
    my $v    = $fv[$fi++];

    # ^get actual state
    my $have = (
      $self->{status}
    & $SF->{$k}

    ) != 0;


    # fail on no match
    if($have != $v) {
      $out=0;
      last;

    };

  };


  return $out;

};

# ---   *   ---   *   ---
# ^icebox

sub blank($self) {
  return $self->status(blank=>1);

};

sub comment($self) {
  return $self->status(comment=>1);

};

sub nterm($self) {
  return $self->status(nterm=>1);

};

sub exprbeg($self) {
  return $self->status(exprbeg=>1);

};

# ---   *   ---   *   ---
# ^set terminator flags

sub set_termf($self) {
  $self->set('blank');
  $self->unset('nterm');

};

# ---   *   ---   *   ---
# ^set *non* terminator flags

sub set_ntermf($self) {
  $self->unset('blank');
  $self->unset('exprbeg');
  $self->set('nterm');

};

# ---   *   ---   *   ---
# check for stringmode and
# handle terminator char

sub string($self) {

  my $out=$self->status(string=>1);

  if($out && $self->{char} eq $self->{strterm}) {

    $self->{char}=$NULLSTR;
    $self->unset('string');

    $self->commit();

    if($self->comment()) {
      $self->unset('comment');
      $self->new_branch();

    };

  };


  return $out;

};

# ---   *   ---   *   ---
# fetch classes for each parser layer
# then cstruc new ice for each

sub cstruc_layers($self) {

  my $class=ref $self;

  map {

    my $fn    = "get_$ARG";
    my $layer = $self->$fn();

    $self->{$ARG}=$layer->new($self)
    if ! defined $self->{$ARG};


  } qw(l0 l1 l2 lx);


  return;

};

# ---   *   ---   *   ---
# get char-parse logic

sub get_l0($class) {
  cload('rd::l0');
  return 'rd::l0';

};

# ---   *   ---   *   ---
# get token logic

sub get_l1($class) {
  cload('rd::l1');
  return 'rd::l1';

};

# ---   *   ---   *   ---
# get expression logic

sub get_l2($class) {
  cload('rd::l2');
  return 'rd::l2';

};

# ---   *   ---   *   ---
# get execution layer

sub get_lx($class) {
  cload('rd::lx');
  return 'rd::lx';

};

# ---   *   ---   *   ---
# AR/IMP:
#
# * runs crux with provided
#   input if run as executable
#
# * if imported as a module,
#   it aliaes 'crux' to 'rd'
#   and adds it to the calling
#   module's namespace

sub import($class,@req) {

  return IMP(

    $class,

    \&ON_USE,
    \&ON_EXE,

    @req

  );

};

# ---   *   ---   *   ---
# ^imported as exec via arperl

sub ON_EXE($class,@input) {


  my $m=Cli->new(

    {id=>'out',short=>'-o',argc=>1},
    {id=>'echo',short=>'-e',argc=>0},
    {id=>'strip',short=>'-s',argc=>0,default=>1},
    {id=>'mc',short=>'-mc',argc=>1},

  );


  # remove nullargs and proc cmd
  @input=grep {defined $ARG} @input;

  # have values to proc?
  my ($src)=$m->take(@input);

  $WLog->err('no input',
    from  => 'rd',
    lvl   => $AR_FATAL

  ) if ! $src;


  # proc options
  my %O=();

  if($m->{mc} ne $NULL) {

    my ($cls,$memroot,$pathsep)=
      split ',',$m->{mc};

    $O{mc}={

      cls     => $cls,

      memroot => $memroot,
      pathsep => $pathsep,

    };

  };

  # get parse tree
  my $ice=crux($src,%O);

  # ^remove comments?
  $ice->{l2}->strip_comments($ice->{tree})
  if $m->{strip} eq 1;


  # write to file?
  store($ice,$m->{out})
  if $m->{out} ne $NULL;


  # dbout to tty?
  $ice->{tree}->prich()

  if $m->{echo} ne $NULL
  || $m->{out}  eq $NULL

  ;


  return;

};

# ---   *   ---   *   ---
# ^imported as module via use

sub ON_USE($class,$from,@nullarg) {

  no strict 'refs';

  *{"$class"}=*crux;

  submerge(

    [$class],

    main  => $from,
    subok => qr{^crux$},

  );

  return;

};

# ---   *   ---   *   ---
# parse error

sub perr($self,$me,%O) {

  # defaults
  $O{lvl}  //= $AR_FATAL;
  $O{args} //= [];


  # each branch saves at which line
  # it was spawned; use that if avail
  my $lineno=($self->{branch})
    ? $self->{branch}->{lineno}
    : $self->{lineat}
    ;


  # give "(errme) at lineno"
  my $loc="<%s> line [num]:%u";
  unshift @{$O{args}},$self->{fpath},$lineno;

  $WLog->err("at $loc:\n$me",%O,from=>(ref $self));


  return;

};

# ---   *   ---   *   ---
1; # ret
