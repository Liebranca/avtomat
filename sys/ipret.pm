#!/usr/bin/perl
# ---   *   ---   *   ---
# IPRET
# Executes rd parse trees
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret;

  use v5.36.0;
  use strict;
  use warnings;

  use Storable qw(store retrieve file_magic);
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Cli;
  use Type;
  use Bpack;
  use Ring;

  use Arstd::IO;
  use Arstd::PM;
  use Arstd::WLog;

  use parent 'rd';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  encoder_t => 'ipret::encoder',
  engine_t  => 'ipret::engine',

  layers    => sub { return [
    @{rd->layers},
    qw(encoder engine),

  ]},

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$src,%O) {


  # get parse tree
  my $self=(is_filepath($src) && file_magic($src))
    ? retrieve $src
    : rd::crux $src,%O
    ;

  return $class->mutate($self);

};

# ---   *   ---   *   ---
# mutate parser into interpreter

sub mutate($class,$ice) {


  # update instance
  $ice=bless {%$ice},$class;

  # ^notify layers
  $ice->cstruc_layers(
    map {$ARG=>$ice}
    @{$ice->layers}

  );

  map {$ice->{$ARG}->{main}=$ice}
  @{$ice->layers};

  $ice->{cmdlib}->{main}=$ice;


  # reload commands
  my $pkg=$ice->{subpkg};
     $pkg=$ice->{cmdlib}->mutate($pkg);

  $ice->{subpkg}=$pkg;
  $ice->{lx}->load_CMD(1);


  return $ice;

};

# ---   *   ---   *   ---
# in a nutshell

sub crux($src,%O) {


  # defaults
  $O{limit} //= 1;


  # get parse tree
  my $self = ipret->new($src,%O);

  # ^solve values
  my $eng = $self->engine_t;
  my $rev = "$eng\::branch_solve";

  $self->walk(

    self  => $self->{engine},

    limit => $O{limit},
    rev   => \&$rev

  );


  return $self;

};

# ---   *   ---   *   ---
# CVYC: get handle to current byte,
# but in the ~ F U T U R E ~

sub cpos($self) {

  my $mc=$self->{mc};
  return sub {

  (  $mc->{segtop}->{ptr}
  << $mc->segtab_t->{sizep2})

  | $mc->segid($mc->{segtop})

  };

};

# ---   *   ---   *   ---
# AR/IMP:
#
# * runs crux with provided
#   input if run as executable
#
# * if imported as a module,
#   it aliaes 'crux' to 'ipret'
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

  );


  # remove nullargs and proc cmd
  @input=grep {defined $ARG} @input;

  # have values to proc?
  my ($src)=$m->take(@input);

  $WLog->err('no input',
    from  => $class,
    lvl   => $AR_FATAL

  ) if ! $src;


  # run!
  my $ice=crux($src);


  return;

};

# ---   *   ---   *   ---
# ^imported as module via use

sub ON_USE($class,$from,@nullarg) {

  no strict 'refs';

  Arstd::PM::add_symbol(
    "$from\::$class",
    "$class\::crux"

  );


  return;

};

# ---   *   ---   *   ---
1; # ret
