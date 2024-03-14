#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M ALLOC:STAB
# Allocator sub-table
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::alloc::stab;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;
  use Icebox;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  ptr_t  => (typefet 'word'),
  stab_t => sub {

    my $class=$_[0];
    my $ptr_t=$class->ptr_t();

    struc 'alloc.stab' =>

      "$ptr_t->{name} blk;"
    . "$ptr_t->{name} next;"

    . q{

      dword id;
      qword mask;

    };

  },

};

# ---   *   ---   *   ---
# GBL

St::vstatic {
  main      => undef,
  -autoload => [qw(get_last get_next)],

};

# ---   *   ---   *   ---
# module kick

sub import($class) {
  $class->stab_t();
  return;

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$frame,$lvl,%O) {


  # get ctx
  my $main = $frame->{main};
  my $root = $main->{mem};
  my $type = $class->stab_t();


  # get addr for link slot
  my ($base,$idex)=
    $frame->get_last($lvl);


  # make ice
  my $self=bless {

    main => $main,
    lvl  => $lvl,

    head => undef,
    blk  => undef,


  },$class;

  # ^register
  my $id=$frame->icemake($self);

  # ^write to mem
  $self->{head}=$root->decl(
    $type,"lvl[$lvl:$idex]",
    {id=>$id},

  );

  # make block
  my $blk_t = $main->blk_t();
  my $head  = $self->{head};

  $self->{blk}=$blk_t->new($self);


  # middle or first entry?
  my $alloc_t=$main->alloc_t();
  my $at=($base >= $alloc_t->{sizeof})

    # middle entry: write to stab.next
    ? $base
    + offsetof $type,'next'

    # ^else write to main.lvl[N]
    : $base

    ;


  # ^write link and give ice
  my $dist=$head->{addr} - $base;
  $root->store(word=>$dist,$at);


  return $self;

};

# ---   *   ---   *   ---
# finds last link in subtable

sub get_last($class,$frame,$lvl) {


  # get ctx
  my $main = $frame->{main};
  my $root = $main->{mem};

  # read first entry
  my $ptr_t = $main->ptr_t();
  my $addr  = $lvl * $ptr_t->{sizeof};

  my $have  = $root->load($ptr_t,$addr);
  my $idex  = 0;

  my @out   = ($addr,$idex);


  # have links to iter?
  if($have) {

    $addr += $have;
    my $stab_t=$class->stab_t();

    while(++$idex) {

      # get entry, stop if it links to null
      my $ahead=$root->load($stab_t,$addr);
      last if ! $ahead->{next};

      # ^else read link
      $addr += $ahead->{next};

    };


    @out=($addr,$idex);

  };


  return @out;

};

# ---   *   ---   *   ---
# fetch subtable entry
# from master table
#
# makes new stabs if missing!

sub get_next($class,$frame,$lvl) {

#  # get ctx
#  my $main=$frame->{main};
#  my $root=$main->{mem};
#  my $type=$class->stab_t();
#
#
#  # iter links until found
#  my $stab=undef;
#
#  map {
#
#
#  } 0..$idex;
#
#
#  return $stab;

};

# ---   *   ---   *   ---
1; # ret
