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

  use Carp;
  use Storable qw(store retrieve file_magic);
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Cli;
  use Type;
  use Bpack;
  use Ring;
  use Vault;
  use id;

  use Arstd::IO;
  use Arstd::PM;
  use Arstd::WLog;

  use parent 'rd';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.1;#a
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

  pipeline => [qw(solve assemble)],

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
  $ice=bless {%$ice,entry=>undef},$class;

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


  $self->assemble();
  return $self;

};

# ---   *   ---   *   ---
# get current byte

sub cpos($self) {
  my $mc=$self->{mc};
  return $mc->{segtop}->{ptr};

};

# ---   *   ---   *   ---
# generates binary from solved tree

sub assemble($self) {


  # get ctx
  my $enc   = $self->{encoder};
  my $lx    = $self->{lx};

  my $stage = $self->{stage};
     $stage = $lx->stages->[$stage-1];

  my $limit = $self->{passes};
     $limit = $limit->{$stage};


  # walk the tree
  my $prev={};

  while($limit--) {

    my @tab=$enc->exewrite_run();
    my $inc=0;


    # walk nodes
    map {


      # get current/previous addr of node
      my $vref = $ARG->{vref};
      my $have = $prev->{$ARG->{-uid}} //= [];

      # did it move?
      $inc |= int(

         defined $have->[-1]
      && $have->[-1] != $vref->{addr}

      );


      # record current
      push @$have,$vref->{addr};


    } @tab;


    # if we detected a change in the addresses,
    # that means bytes were moved around!
    #
    # in that case, and if the loop is about to
    # end, we want to extend it -- just to make
    # sure that all labels get recalculated ;>

    $self->next_pass();
    $limit++ if $inc && $limit < 1;

  };


  # go next and give OK
  $self->next_stage();
  return 1;

};

# ---   *   ---   *   ---
# stores program as linkable

sub to_obj($self) {


  # get ctx
  my $enc = $self->{encoder};
  my $Q   = $enc->{Q}->{asm};


  # transform to flat memory model
  my $root=$self->{mc}->memflat();

  # redirect encoder
  map {

    my $seg   = $ARG->[0];

    $ARG->[0] = $seg->{vref};
    $ARG->[1] = $seg->{route};

  } grep {defined $ARG} @$Q;


  # re-assemble!
  $self->{stage}--;
  $self->assemble();

  return;

};

# ---   *   ---   *   ---
# jump to entry and execute

sub run($self,$entry=undef) {


  # overwrite/validate
  $entry //= $self->{entry};

  $WLog->err(

    "No entry point for <%s>",

    args => [$self->{fpath}],
    lvl  => $AR_FATAL,

    from => ref $self,

  ) if ! $entry;


  # get ctx
  my $mc    = $self->{mc};
  my $anima = $mc->{anima};
  my $chan  = $anima->{chan};
  my $rip   = $anima->{rip};
  my $cas   = $mc->{cas};


  # make sure the addressing space exists!
  my $have=$cas->{inner}->haslv($entry->[0]);

  $WLog->err(

    "undefined [ctl]:%s '%s'",

    args => ['clan',$entry->[0]],
    lvl  => $AR_FATAL,

    from => ref $self,

  ) if ! defined $have;


  # fetch symbol
  my $sym=$mc->valid_ssearch(@$entry);


  # ^validate ;>
  $WLog->err(

    "Invalid entry point '%s' for <%s>",

    args => [$entry->[1],$self->{fpath}],
    lvl  => $AR_FATAL,

    from => ref $self,

  ) if ! length $sym;


  # have pointer or segment?
  my $ptr   = $mc->{bk}->{ptr};
  my $isptr = $ptr->is_valid($sym);

  # get [segment:offset]
  my ($segid,$addr);

  # to deref or not to deref?
  if($isptr) {

    ($segid,$addr)=(defined $sym->{ptr_t})
      ? ($sym->{chan},$sym->load(deref=>0))
      : ($sym->{segid},$sym->{addr})
      ;

  # start of segment
  } else {
    ($segid,$addr)=($sym->{iced},0x00);

  };


  # make the jump!
  $rip->store(
    $addr,
    deref=>0

  );

  $rip->{chan}=$segid;


  return $self->{engine}->exe();

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

sub import($class,@args) {

  return IMP(

    $class,

    \&ON_USE,
    \&ON_EXE,

    @args

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
