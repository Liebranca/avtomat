#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M ANIMA
# Soul of computing
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::anima;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Type;
  use Warnme;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::Re;
  use Arstd::IO;

  use parent 'A9M::sysmem';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.6;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # name of system block
  ROOTID => 'ANIMA',

  # full list of registers
  list => [qw(

    ar  br  cr  dr
    er  fr  gr  hr

    xp  xs  sp  sb

    ice ctx opt chan

    rip

  )],


  # ^internal alloc will not
  # mess with these by default
  reserved => [qw(

    sp  sb   ice ctx
    opt chan rip

  )],

  # ^the mask for matchin!
  reserved_mask => sub {


    # get the list
    my $class = $_[0];
    my $name  = $class->reserved();

    my $mask  = 0x00;


    # ^match names in least to an index
    # ^then use index to or with mask
    map{

      my $idex  = $class->tokin($_);
         $mask |= 1 << $idex;

    } @$name;


    # give the mask ;>
    $mask;

  },

  # ^pattern for string stuff
  re => sub {re_eiths $_[0]->list},


  # indices of special-purpose registers
  stack_ptr  => 0x0A,
  stack_base => 0x0B,
  fetch_base => 0x0F,

  exec_ptr   => 0x10,


  # number of encoding registers
  cnt => sub {int(@{$_[0]->list})-1},


  # bit offset for each flag
  flagpos => sub {

    my $idex=0;

    return {

      map {$ARG=>$idex++}
      qw  (zero)

    };

  },

};


# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {


  # defaults
  $O{mcid}  //= 0;
  $O{mccls} //= caller;


  # make ice
  my $self = bless {

    %O,

    mem   => undef,
    ptr   => undef,

    rip   => undef,
    chan  => undef,


    flags => 0x00,


  },$class;


  # make container
  $self->mkroot();
  $self->{almask}=$class->reserved_mask;

  $self->{mem}->brk($class->size);

  # make labels
  my $addr = 0x00;
  my @ptr  = map {

    my $v=$self->{mem}->lvalue(

      0x00,

      addr  => $addr,
      label => $ARG,

      type  => $class->size_k,

    );

    $addr += $class->size;
    $v;

  } @{$class->list};


  # make fetch pointers
  my $mc   = $self->getmc();
  my $rip  = $ptr[$self->exec_ptr];
  my $chan = $ptr[$self->fetch_base];

  my $ISA  = $mc->{bk}->{ISA};

  $rip->{ptr_t} = typefet 'long';
  $rip->{type}  = $ISA->align_t;


  # ^store
  $self->{rip}  = $rip;
  $self->{chan} = $chan;

  # save labels to ice and give
  $self->{ptr}=\@ptr;

  return $self;

};

# ---   *   ---   *   ---
# get register by name or idex

sub fetch($self,$name) {


  # idex passed
  return ($name < $self->cnt())
    ? $self->{ptr}->[$name]
    : warn_invalid($name)

  if $name=~ qr{^\d+$};


  # ^else get idex
  my $idex=$self->tokin($name);
  defined $idex or return warn_invalid($name);

  return $self->{ptr}->[$idex];

};

# ---   *   ---   *   ---
# ^errme

sub warn_invalid($name) {

  Warnme::invalid 'register',

  obj  => $name,
  give => null;

};

# ---   *   ---   *   ---
# get token is register
#
# if so, give idex
# else undef

sub tokin($class,$name) {

  return ($name=~ $class->re())
    ? array_iof($class->list(),$name)
    : undef
    ;

};

# ---   *   ---   *   ---
# update flags register

sub set_flags($self,%O) {

  my $dst=\$self->{flags};

  map {

    my $key = $ARG;
    my $bit = $O{$key} << $self->flagpos->{$key};

    if($bit) {$$dst |=  $bit}
    else     {$$dst &=~ $bit};

  } keys %O;

  return;

};

# ---   *   ---   *   ---
# ^read

sub get_flags($self,@ar) {

  my $src=$self->{flags};

  map {
    my $bit = 1 << $self->flagpos->{$ARG};
    ($src & $bit) != 0;

  } @ar;

};

# ---   *   ---   *   ---
# legacy method from AR/forge
# needs revision!
#
# generates *.pinc ROM file
# if this one is updated

sub update($class,$A9M) {


  # get additional deps
  use Shb7::Path;

  use lib $ENV{'ARPATH'}.'/forge/';
  use f1::blk;


  # file to (re)generate
  my $dst="$A9M->{path}->{rom}/ANIMA.pinc";

  # ^missing or older?
  if(moo($dst,__FILE__)) {

    # dbout
    $A9M->{log}->substep('ANIMA');

    # make codestr with constants
    my $blk=f1::blk->new('ROM');

    $blk->lines(

      'define A9M.REGISTERS '
    . (join ',',@{$class->list()}) . ';'

    . "A9M.REGISTER_CNT    = " . $class->cnt() .';'
    . "A9M.REGISTER_CNT_BS = " . $class->cnt_bs() .';'
    . "A9M.REGISTER_CNT_BM = " . $class->cnt_bm() .';'

    );

    # ^commit to file
    owc($dst,$blk->{buf});

  };

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {


  # defauls
  $O{flags} //= 1;

  # display memory
  my $out=ioprocin(\%O);
  A9M::sysmem::prich($self,%O,mute=>1);


  # display flags?
  push @$out,sprintf "FLAGS: %04Bb\n\n",
    $self->{flags}

  if $O{flags};


  return ioprocout(\%O);

};

# ---   *   ---   *   ---
1; # ret
