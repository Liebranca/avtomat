#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M ALLOC
# avto:mem!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::alloc;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;
  use Bpack;
  use Warnme;

  use Arstd::Int;
  use Arstd::Bytes;
  use Arstd::IO;
  use Arstd::PM;

  use parent 'A9M::component';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # mpart implementation
  mpart => 'A9M::mpart',


  # number of sub-tables
  lvlcnt => 0x02,

  # default alignment
  defbase => 'byte',


  # master partition table
  head_t => sub {


    my $class = $_[0];
    my $cnt   = $class->lvlcnt();


    struc 'alloc.head' => "word lvl[$cnt]";

  },


  # ^sub-table entry
  lvl_t => (struc 'alloc.lvl' => q{

    word  buf;
    word  next;

    qword mask;

  }),

  # ^block header
  blk_t => (struc 'alloc.blk' => q{

    word stab;

    byte lvl;
    byte loc;

  }),

};

# ---   *   ---   *   ---
# module kick

sub import($class) {

  $class->head_t();
  $class->lvl_t();
  $class->blk_t();

  cload $class->mpart();


  return;

};

# ---   *   ---   *   ---
# recalc sizes accto base alignment

sub set_base($self,$base) {


  # validate in
  $base=typefet $base
  or return null;


  # ^save and re-run calcs
  $self->{base} = $base;

  $self->{page} = $base->{sizebs} ** 2;
  $self->{pow}  = $base->{sizep2}  * 2;


  return;

};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {


  # defaults
  $O{mcid}  //= 0;
  $O{mccls} //= caller;
  $O{base}  //= $class->defbase();


  # make ice
  my $self   = bless \%O,$class;

  my $mc     = $self->getmc();
  my $memcls = $mc->{bk}->{mem};

  $self->set_base($O{base});


  # make container
  my $type = $self->head_t();
  my $mem  = $memcls->mkroot(

    mcid  => $self->{mcid},
    mccls => $self->{mccls},

    label => 'ALLOC',
    size  => $type->{sizeof},

  );

  # ^struc as master table
  $mem->decl($type,'head',0x00);


  # save and give
  $self->{mem}=$mem;

  return $self;

};

# ---   *   ---   *   ---
# determine partition level

sub get_part($self,$req) {


  # get ctx
  my $cnt  = $self->lvlcnt();
  my $base = $self->{base};

  my $bits = $base->{sizebs};
  my $pow  = $self->{pow};


  # add block header size to requested
  my $reqb = $req + sizeof 'alloc.blk';

  # align requested size to granularity
  my $total = int_align $reqb,$bits;
  my $size  = 0;
  my $lvl   = null;


  for my $i(0..$cnt-1) {


    # get next partition level
    my $ezy = 1 << $pow;
    my $cap = $ezy * $bits;

    # ^total fits within three sub-blocks?
    if($total <= $ezy * 3) {

      $lvl  = $i;
      $size = int $total/$ezy;

      last;

    # ^total fits within maximum size?
    } elsif($i == $cnt-1) {

      $lvl=($total >= $cap)
        ? warn_reqsize($req,$total)
        : $i
        ;

      $size=int $total/$ezy;

      last;

    };


    # go next
    $pow++;

  };


  return ($lvl,$size);


};

# ---   *   ---   *   ---
# ^errme

sub warn_reqsize($req,$total) {

  warnproc

    'block of size $[num]:%X '
  . '(requested: $[num]:%X) '

  . 'exceeds maximum partition size',

  args => [$total,$req],
  give => null;

};

# ---   *   ---   *   ---
# make new sub-table entry

sub mkstab($self,$lvl,$at) {


  # get ctx
  my $lvl_t = $self->lvl_t();
  my $mem   = $self->{mem};


  # make container
  my $stab = $mem->decl(
    $lvl_t,"STAB:$mem->{ptr}",0x00

  );


  # get mem
  my $size = $self->{page} << $lvl;
  my $blk  = $mem->new($size);

  $stab->store($blk->{segid});


  # ^write to table and give
  $mem->store(word=>$stab->{addr},$at);

  return $stab;

};

# ---   *   ---   *   ---
# ^get existing

sub getstab($self,$addr) {

  # get ctx
  my $mem   = $self->{mem};
  my $lvl_t = $self->lvl_t();


  # tree lookup
  my $have=$mem->deref("STAB:$addr");

  # ^validate and give
  return (! defined $have)
    ? null
    : $have
    ;

};

# ---   *   ---   *   ---
# fit size in blk

sub blkfit($self,$ctx) {


  # unpack
  my $data  = $ctx->{head};
  my $mask  = $data->{mask};
  my $mpart = $self->mpart();

  # enough space avail?
  my ($ezy,$pos)=$mpart->fit(
    \$mask,$ctx->{size}

  );

  return 0 if ! defined $ezy;


  # ^yes, update block
  $ctx->{ezy}=$ezy;
  $ctx->{pos}=$pos;

  my $addr=$self->blk_write($ctx);

  # ^update subtable
  my $stab=$ctx->{stab};

  $data->{mask} |= $mask;
  $stab->store($data);


  return $addr;


};

# ---   *   ---   *   ---
# writes block header

sub blk_write($self,$ctx) {


  # unpack
  my $stab  = $ctx->{stab};
  my $data  = $ctx->{head};
  my $mem   = $self->{mem};
  my $frame = $mem->{frame};


  # build header
  my $blk   = $frame->getseg($data->{buf});
  my $blk_t = $self->blk_t();

  my $head  = Bpack::layas $blk_t,

    $stab->{addr},
    $ctx->{lvl},

    ($ctx->{ezy}-1)
  | ($ctx->{pos} << 2);


  # ^write
  my $pow  = $ctx->{lvl} + $self->{pow};
  my $addr = $ctx->{pos} << $pow;

  $blk->store($blk_t,$head,$addr);


  # give beg of user memory!
  return $addr + $blk_t->{sizeof};

};

# ---   *   ---   *   ---
# fetch/make block

sub get_block($self,$req) {


  # get partition/aligned block size
  my ($lvl,$size)=
    $self->get_part($req);

  return null if ! length $lvl;


  # get ctx
  my $mem    = $self->{mem};
  my $top    = $mem->{ptr};
  my $head_t = $self->head_t();


  # fetch subtable
  my $head = $mem->load($head_t,0x00);
  my $addr = $head->{lvl}->[$lvl];
  my $base = $lvl * sizeof 'word';

  # ^make first entry?
  retry: my $stab=(! $addr)
    ? $self->mkstab($lvl,$base)
    : $self->getstab($addr)
    ;


  # TODO:
  #
  # * mem::view

  my $ctx={

    stab => $stab,
    head => $stab->load(),

    lvl  => $lvl,
    ezy  => undef,
    pos  => undef,

    size => $size,

  };


  # have enough space?
  my $fit=$self->blkfit($ctx);

  # ^nope, go next/make new
  if(! $fit) {

    my $data = $ctx->{head};


    $addr  = $data->{next};
    $base  = $ctx->{stab}->{addr};
    $base += sizeof 'word';

    goto retry;

  };


  return $fit;

};

# ---   *   ---   *   ---
# ~

sub take($self,$req) {};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {
  $self->{mem}->prich(%O,root=>1);

};

# ---   *   ---   *   ---
1; # ret
