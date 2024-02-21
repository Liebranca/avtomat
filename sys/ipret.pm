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

  use Readonly;
  use Storable;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Cli;

  use Arstd::IO;
  use Arstd::PM;
  use Arstd::WLog;

  use parent 'rd';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,$src) {

  # get parse tree
  my $self=(is_filepath($src))
    ? retrieve($src)
    : rd($src)
    ;

  # ^mutate into interpreter
  $self=bless {%$self},$class;
  $self->cstruc_layers();


  return $self;

};

# ---   *   ---   *   ---
# in a nutshell

sub crux($src) {

  my $self=ipret->new($src);
  while($self->step(\&proc_solve,$self)) {};


  return $self;

};

# ---   *   ---   *   ---
# analyze next branch

sub proc_solve($self,$nd,@Q) {


  # get ctx
  my $l1    = $self->{l1};
  my $lx    = $self->{lx};
  my $scope = $self->{scope};
  my $path  = $scope->{path};


  # have command?
  if(exists $nd->{cmdkey}) {

    my $cmd = $NULLSTR;
    my $key = $nd->{value};

    my $fn  = $lx->passf($nd->{cmdkey});

  };


  return 1;

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
1; # ret
