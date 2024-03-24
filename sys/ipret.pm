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

  our $VERSION = v0.00.7;#a
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

  $ice=bless {%$ice},$class;
  $ice->cstruc_layers(
    map {$ARG=>$ice}
    @{$ice->layers}

  );

  map {$ice->{$ARG}->{main}=$ice}
  @{$ice->layers};


  return $ice;

};

# ---   *   ---   *   ---
# in a nutshell

sub crux($src) {

  my $self = ipret->new($src);

  my $eng  = $self->engine_t;
  my $rev  = "$eng\::branch_solve";

  $self->walk(limit=>2,rev=>\&$rev);


  return $self;

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
    from  => 'ipret',
    lvl   => $AR_FATAL

  ) if ! $src;


  # ~
  my $ice=crux($src);


  return;

};

# ---   *   ---   *   ---
# ^imported as module via use

sub ON_USE($class,$from,@nullarg) {

  no strict 'refs';

  *ipret=*crux;

  submerge(

    [$class],

    main  => $from,
    subok => qr{^ipret$},

  );

  return;

};

# ---   *   ---   *   ---
1; # ret
