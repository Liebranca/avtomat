#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M ALLOC:BLK
# Big old chunks
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::alloc::blk;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;
  use Icebox;
  use Bitformat;

  use Arstd::IO;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # location of sub-block
  loc_t => sub {

    my $class = $_[0];
    my $name  = "$class\::loc";

    return Bitformat $name => (
      size => 5,
      pos  => 5,

    );

  },


  # ^sub-block header
  blk_t => sub {


    # get size of packed location!
    my $class  = $_[0];
    my $loc_t  = $class->loc_t;

    my @loc_sz = typeof $loc_t->{bytesize};
    my $loc    = "$loc_sz[0] loc;";

    # ^build multiple lines if need
    if(1 < @loc_sz) {

      shift @loc_sz;

      my $i=0;

      $loc .= join ";",map {
        "$ARG loc_".$i++

      } @loc_sz;

    };


    # give final struc
    return struc '$class\::blk'
      => "word stab;$loc";

  },

};

# ---   *   ---   *   ---
# GBL

St::vstatic {

  main=>undef,
  -autoload=>[qw(head_from clear)],

};

# ---   *   ---   *   ---
# module kick

sub import($class) {
  $class->blk_t;
  return;

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$frame,$stab) {


  # get ctx
  my $alloc = $stab->{frame}->{main};
  my $root  = $alloc->{mem};

  # get N pages
  my $size = $alloc->{page} << $stab->{lvl};
  my $dst  = $stab->{ptr};
  my $mem  = $root->new($size);


  # make ice
  my $self=bless {
    stab => $stab,
    mem  => $mem,

  },$class;

  my $id=$frame->icemake($self);


  # ^write to table
  my $head=$stab->{head};
  $head->storef(blk=>$id);


  return $self;

};

# ---   *   ---   *   ---
# get block header from input

sub head_from($class,$frame,$src) {


  # get ctx
  my $main = $frame->{main};
  my $mem  = ref $main->{mem};


  # numerical repr passed?
  if(! $mem->is_valid($src)) {
    nyi "pointer decode";

  # ^nope, straight mem ice!
  } else {

    my $type=$class->blk_t;
    my ($base,$addr) = $src->get_addr();

    $addr -= $type->{sizeof};


    my $head=$base->load($type,$addr);
    return ($head,$base,$addr);

  };

};

# ---   *   ---   *   ---
# ^marks as fred

sub clear($class,$frame,$base,$addr=undef) {


  # fetching from ptr!
  if(! defined $addr) {

    my $head;

    ($head,$base,$addr)=
      $frame->head_from($base);

  };


  # ^wipe header
  my $type=$class->blk_t;
  $base->clear($type,$addr);


  return;

};

# ---   *   ---   *   ---
# fit size in blk

sub fit($self,$head,$lvl,$size) {


  # get ctx
  my $stab = $self->{stab};
  my $main = $stab->{frame}->{main};

  my $root = $main->{mem};
  my $mask = $head->{mask};


  # enough space avail?
  my $mpart=$main->mpart_t;

  my ($ezy,$pos)=$mpart->fit(
    \$mask,$size

  );

  return 0 if ! defined $ezy;


  # ^yes, update block
  my $view=$self->blk_write($lvl,$size,$pos);
  $stab->{head}->storef(mask=>$mask);


  return $view;


};

# ---   *   ---   *   ---
# writes sub-block header

sub blk_write($self,$lvl,$size,$pos) {


  # get ctx
  my $stab  = $self->{stab};
  my $main  = $stab->{frame}->{main};

  my $mem   = $self->{mem};
  my $frame = $mem->{frame};


  # build sub-block header
  my $type = $self->blk_t;

  my $head = Bpack::layas $type,(
    $stab->{iced},
    $self->pack_loc($size-1,$pos)

  );


  # ^write
  my $pow  = $lvl  + $main->{pow};
  my $addr = $pos << $pow;

  $mem->store($type,$head,$addr);


  # give beg of user memory!
  return $mem->view(

    $addr + $type->{sizeof},

    ($size << $pow)
  - $type->{sizeof}

  );

};

# ---   *   ---   *   ---
# bit-pack a blocks size
# and location

sub pack_loc($class,$size,$pos) {

  return $$class->loc_t->bor(
    size => $size,
    pos  => $pos,

  );

};

# ---   *   ---   *   ---
# ^undo

sub unpack_loc($class,$loc) {
  return $$class->loc_t->from_value($loc);

};

# ---   *   ---   *   ---
1; # ret
