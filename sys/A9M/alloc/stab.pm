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

  use Arstd::Bytes;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.6;#a;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  blk_t  => 'A9M::alloc::blk',
  ptr_t  => (typefet 'word'),

  stab_t => sub {

    my $class=$_[0];
    my $ptr_t=$class->ptr_t;

    struc "$class\::stab" =>

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

  main   => undef,
  blocks => sub {

    my $class = $_[0];
    my $blk_t = $class->blk_t;

    $blk_t->new_frame();

  },


  -autoload => [qw(

    headof

    get_first
    get_next
    get_last

    fetch
    fit
    release

  )],

};

# ---   *   ---   *   ---
# module kick

sub import($class) {
  $class->stab_t;
  return;

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$frame,$lvl) {


  # get ctx
  my $main = $frame->{main};
  my $root = $main->{mem};
  my $type = $class->stab_t;


  # get addr for link slot
  my ($have,$base)=
    $frame->get_last($lvl);


  # make ice
  my $self=bless {

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
  my $blocks = $frame->{blocks};
  my $head   = $self->{head};

  $self->{blk} = $blocks->new($self);


  # middle or first entry?
  my $alloc_t = $main->alloc_t;
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

  my $ptr_t = $main->ptr_t;
  my $addr  = $lvl * $ptr_t->{sizeof};


  return $addr;

};

# ---   *   ---   *   ---
# get first link in subtable

sub get_first($class,$frame,$lvl) {

  # get ctx
  my $main  = $frame->{main};
  my $root  = $main->{mem};
  my $ptr_t = $main->ptr_t;
  my $type  = $class->stab_t;


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
  my $type=$class->stab_t;


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
# forcefully nits subtable

sub fetch($class,$frame,$lvl) {

  my ($have,$addr)=
    $frame->get_first($lvl);

  my $stab=($have)
    ? $frame->ice($have->{id})
    : $frame->new($lvl)
    ;

  $have=$stab->{head}->load() if ! $have;


  return ($have,$stab);

};

# ---   *   ---   *   ---
# find sub-table that can
# fit an allocation this big

sub fit($class,$frame,$req) {

  # get ctx
  my $main=$frame->{main};

  # get partition/aligned block size
  my $mpart_t=$main->mpart_t;

  my ($lvl,$size)=
    $mpart_t->getlvl($main,$req);

  return null if ! length $lvl;


  # get subtable
  my ($have,$stab)=$frame->fetch($lvl);

  my $addr = $stab->{head}->{addr};
  my $out  = null;


  # ^walk
  my $limit=0x10;
  while($limit--) {


    # can fit request in this entry?
    my $blk=$stab->{blk};
       $out=$blk->fit($have,$lvl,$size);

    last if $out;


    # ^else go next!
    ($have,$addr)=
      $frame->get_next($addr);

    $stab=$frame->ice($have->{id});


  };


  return $out;

};

# ---   *   ---   *   ---
# ^undo

sub release($class,$frame,$have,$addr) {


  # get table entry && block location
  my $stab  = $frame->ice($have->{stab});
  my $main  = $frame->{main};

  my $blk_t = $class->blk_t;
  my %loc   = $blk_t->unpack_loc($have->{loc});


  # ^clear block from occupation mask
  my $mask = $stab->{head}->loadf('mask');
  my $ezy  = bitmask $loc{size}+1;

  $mask &=~ ($ezy << $loc{pos});
  $stab->{head}->storef(mask=>$mask);


  # give total bytes fred
  my $pow=$main->{pow};
     $ezy=$stab->{lvl} + $pow;

  return ($loc{size} << $ezy)
    - $main->blk_t->{sizeof};

};

# ---   *   ---   *   ---
# encode to binary

sub mint($self) {

  return map {
    $ARG=>$self->{$ARG};

  } qw(lvl head blk frame);

};

# ---   *   ---   *   ---
# ^undo

sub unmint($class,$O) {
  return bless $O,$class;

};

# ---   *   ---   *   ---
# ^cleanup kick

sub REBORN($self) {
  $self->{frame}->icemake($self);
  return;

};

# ---   *   ---   *   ---
1; # ret
