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

  our $VERSION = v0.00.3;#a;
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


  -autoload => [qw(

    headof

    get_first
    get_next
    get_last

  )],

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
  my ($have,$base)=
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
    $type,"stab[$id]",{id=>$id},

  );

  # make block
  my $blk_t = $main->blk_t();
  my $head  = $self->{head};

  $self->{blk}=$blk_t->new($self);


  # middle or first entry?
  my $alloc_t = $main->alloc_t();
  my $at      = ($base >= $alloc_t->{sizeof})

    # middle entry: write to stab.next
    ? $base
    + offsetof $type,'next'

    # ^else write to main.lvl[N]
    : $frame->headof($lvl)

    ;


  # ^write link and give ice
  my $dist=$head->{addr} - $base;
  $root->store(word=>$dist,$at);


  return $self;

};

# ---   *   ---   *   ---
# get offset into master table

sub headof($class,$frame,$lvl) {

  my $main  = $frame->{main};

  my $ptr_t = $main->ptr_t();
  my $addr  = $lvl * $ptr_t->{sizeof};


  return $addr;

};

# ---   *   ---   *   ---
# get first link in subtable

sub get_first($class,$frame,$lvl) {

  # get ctx
  my $main  = $frame->{main};
  my $root  = $main->{mem};
  my $ptr_t = $main->ptr_t();
  my $type  = $class->stab_t();


  # offset into master table
  my $addr=$frame->headof($lvl);
     $addr=$root->load($ptr_t,$addr);

  # ^deref if it exists
  my $have=(0 < $addr)
    ? $root->load($type,$addr)
    : 0
    ;

  return ($have,$addr);

};

# ---   *   ---   *   ---
# ^get next to current

sub get_next($class,$frame,$addr) {


  # get ctx
  my $main=$frame->{main};
  my $root=$main->{mem};
  my $type=$class->stab_t();


  # deref current and move ptr
  my $here  = $root->load($type,$addr);
     $addr += $here->{next};

  # ^give next link if it exists
  my $have=(0 < $here->{next})
    ? $root->load($type,$addr)
    : 0
    ;

  return ($have,$addr);

};

# ---   *   ---   *   ---
# finds last link in subtable

sub get_last($class,$frame,$lvl) {


  # get ctx
  my $main = $frame->{main};
  my $root = $main->{mem};

  # read first entry
  my ($have,$addr)=
    $frame->get_first($lvl);


  # have links to iter?
  if($have) {

    my $prev;

    while (1) {

      # save last entry
      my $prev=$have;

      # stop if it links to null
      ($have,$addr)=
        $frame->get_next($addr);


      last if ! $have;

    };


    $have=$prev;

  };


  return ($have,$addr);

};

# ---   *   ---   *   ---
# find sub-table that can
# fit an allocation this big

sub fit($class,$frame,$req) {

  # get ctx
  my $main=$frame->{main};

  # get partition/aligned block size
  my $mpart_t=$main->mpart_t();
  my ($lvl,$size)=$mpart_t->getlvl($main,$req);

  return null if ! length $lvl;


  

};

# ---   *   ---   *   ---
1; # ret
