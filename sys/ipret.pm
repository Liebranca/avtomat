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
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Cli;
  use Type;
  use Bpack;
  use Ring;
  use Mint qw(image mount);
  use Cask;
  use id;

  use Arstd::Bytes;
  use Arstd::IO;
  use Arstd::PM;
  use Arstd::WLog;

  use rd::vref;

  use parent 'rd';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.9;#a
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

  pipeline => [qw(solve bind assemble)],

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$src,%O) {


  # get parse tree
  my $self=(is_filepath "$src.gz")
    ? mount $src
    : rd::crux $src,%O
    ;


  # make interpreter from parser
  $self=$class->mutate($self);

  return $self;

};

# ---   *   ---   *   ---
# mutate parser into interpreter

sub mutate($class,$ice) {


  # update instance
  $ice=bless {%$ice,entry=>undef},$class;
  id->chk($ice);


  # ^notify layers
  $ice->cstruc_layers(
    map {$ARG=>$ice}
    @{$ice->layers}

  );


  $ice->{mc}->{mainid}  = $ice->{iced};
  $ice->{mc}->{maincls} = $class;


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

    self   => $self->{engine},

    limit  => $O{limit},
    rev    => \&$rev,

    cannon => 1,

  );

  $self->bind();


  # force recalculation of node indices
  delete $self->{tree}->{absidex};
  $self->{tree}->absidex;


  # sort assembly queue
  my $enc = $self->{encoder};
  my $Q   = $enc->{Q}->{asm};

  my @tmp = ();

  map {

    my ($branch,@data)=@$ARG;
    my $idex=$branch->absidex;

    $tmp[$idex]=\@data;

  } grep {defined $ARG} @$Q;

  @$Q=@tmp;


  # make binary
  $self->flatten();
#  $self->assemble();

  return $self;

};

# ---   *   ---   *   ---
# get current byte

sub cpos($self) {
  my $mc=$self->{mc};
  return $mc->{segtop}->{ptr};

};

# ---   *   ---   *   ---
# make bindable hierarchical block
# from a given tree branch

sub mkhier($self,$type,$branch) {


  # get ctx
  my $mc   = $self->{mc};
  my $vref = $branch->{vref};

  # run cstruc
  $branch->{vref}=rd::vref->new(

    type => 'HIER',
    spec => $type,

    data => $mc->mkhier(
      type=>$type,
      node=>$branch,
      name=>$vref->{res}->{label},

    ),

    res  => $vref->{res},

  );


  return $branch->{vref};

};

# ---   *   ---   *   ---
# run post-solve execution queues

sub bind($self) {


  # get ctx
  my $l1   = $self->{l1};
  my $mc   = $self->{mc};
  my $root = $self->{tree};
  my $enc  = $self->{encoder};


  # force recalculation of node indices
  delete $root->{absidex};
  $root->absidex;

  # make regex
  my $re=$l1->re(
    CMD=>$mc->{bk}->{hier}->blk_re

  );

  # walk hierarchical blocks
  map {
    $ARG->{vref}->{data}->expand();

  } $root->branches_in($re);


  return;

};

# ---   *   ---   *   ---
# join memory segments by type

sub flatten($self) {


  # get ctx
  my $enc = $self->{encoder};
  my $Q   = $enc->{Q}->{asm};


  # transform to flat memory model
  my $root=$self->{mc}->memflat();

  # redirect encoder
  map {

    my $seg=$ARG->[0];

    $ARG->[0]=$seg->{vref}
    if defined $seg->{vref};

    $ARG->[1]=$seg->{route}
    if defined $seg->{route};


  } grep {defined $ARG} @$Q;

  return;

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


  # F state
  my $prev=[];

  # assemble and reassemble until
  # the code can't be made smaller!
  while($limit--) {

    my @tab = $enc->exewrite_run();
    my $inc = 0;


    # compare result to previous pass!
    map {


      # get current/previous
      my $new = $tab[$ARG];
      my $old = $prev->[$ARG];

      # did it move?
      $inc |= int(
         $new->{size} != $old->{size}
      || $new->{addr} != $old->{addr}

      );


    } 0..@$prev-1;

    $prev=\@tab;


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


  # take the jump!
  $rip->store(
    $addr,
    deref=>0

  );

  $rip->{chan}=$segid;


  return $self->{engine}->exe();

};

# ---   *   ---   *   ---
# encode to binary

sub mint($self) {

  # add general attrs
  my @out=map {
    $ARG=>$self->{$ARG}

  } qw(

    fpath PATH entry

    fmode subpkg lineat lineno
    stage pass passes

    inner l2 preproc

    mc

  );


  # save data for re-encoding
  my $enc=$self->{encoder};
  push @out,asm_Q=>$enc->{Q}->{asm};

  return @out;

};

# ---   *   ---   *   ---
# ^undo

sub unmint($class,$O) {


  # make ice
  my $self=bless {%$O},$class;

  # regen missing layers ;>
  $self->cstruc_layers(
    map {$ARG=>$self} qw(l1 lx encoder engine)

  );


  # reinstate Q
  $self->{encoder}->{Q}->{asm}=[grep {
    length $ARG

  } @{$self->{asm_Q}}];

  delete $self->{asm_Q};

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
