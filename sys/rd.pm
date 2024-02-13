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
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Tree;

  use Arstd::Array;
  use Arstd::IO;
  use Arstd::PM;
  use Arstd::WLog;

  use Shb7::Path;

  $WLog //= Arstd::WLog->genesis();

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $SF=>{

    blank   => 0x0001,
    string  => 0x0002,
    comment => 0x0004,
    term    => 0x0008,

  };

  Readonly my $FMODE=>{

    (map {$ARG=>0x01} qw($ elf)),
    (map {$ARG=>0x02} qw(% rom)),
    (map {$ARG=>0x04} qw(@ net)),
    (map {$ARG=>0x08} qw(^ gfi)),

  };

# ---   *   ---   *   ---
# cstruc

sub new($class,$src) {

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


    # subclass reading char/token/branch
    l0      => $class->get_l0(),
    l1      => $class->get_l1(),
    l2      => $class->get_l2(),


    # shared vars
    status  => 0x0000,

    # line number!
    lineno  => 1,

    # stringmode term
    strterm => $NULLSTR,


    # I/O
    fmode   => $FMODE->{rom},
    fpath   => $src,
    buf     => $body,


  },$class;


  return $self;

};

# ---   *   ---   *   ---
# in a nutshell

sub crux($src) {

  # make ice
  my $self=rd->new($src);


  # select sub-class
  $self->solve_ipret();

  # parse string
  $self->{l0}->proc($self);
  $self->{l2}->proc($self);


  # dbout
  $self->{tree}->prich();

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

  # parse first expression
  $self->{l0}->proc_single($self);

  # ^decompose
  my $cmd  = $self->{tree}->{leaves}->[-1];
  my @args = @{$cmd->{leaves}};
  my $have = $cmd->{value};

  $self->{token}=$have;


  # is first token operator?
  if($have=$self->{l1}->operator($self)) {

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

# ---   *   ---   *   ---
# check for terminator and
# unset if non-blank passed

sub term($self) {

  my $out=$self->status(term=>1);

  if($out &&! $self->blank()) {
    $self->unset('term');
    $out=0;

  };

  return $out;

};

# ---   *   ---   *   ---
# check for stringmode and
# handle terminator char

sub string($self) {

  my $out=$self->status(string=>1);

  if($out && $self->{char} eq $self->{strterm}) {
    $self->{char}=$NULLSTR;
    $self->unset('string');

    $self->{l0}->commit($self);

    if($self->comment()) {
      $self->{l0}->new_branch($self);

    };

  };


  return $out;

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

  # remove nullargs
  @input=grep {defined $ARG} @input;

  # have values to proc?
  (@input)

    ? map {crux($ARG)} @input

    : $WLog->err('no input',

      from  => 'rd',
      lvl   => $AR_FATAL

    );

};

# ---   *   ---   *   ---
# ^imported as module via use

sub ON_USE($class,$from,@nullarg) {

  *rd=*crux;

  submerge(

    ['rd'],

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


  # give "(errme) at lineno"
  my $loc="<%s> line [num]:%u";
  unshift @{$O{args}},$self->{fpath},$self->{lineno};

  $WLog->err("at $loc:\n$me",%O,from=>'rd');


  return;

};

# ---   *   ---   *   ---
1; # ret
