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

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Type;
  use Warnme;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::Re;
  use Arstd::IO;

  use parent 'A9M::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.6;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # full list of registers
  list => [qw(

    ar    br    cr    dr
    er    fr    gr    hr

    xp    xs    sp    sb

    ice   ctx   opt   chan

  )],


  # ^internal alloc will not
  # mess with these by default
  reserved => [qw(
    xp  xs  sp  sb
    ice ctx opt chan

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
  re => sub {re_eiths $_[0]->list()},


  # indices of special-purpose registers
  exec_ptr  => 0x08,
  stack_ptr => 0x0A,
  stack_bot => 0x0B,


  # default size for each register
  sizek  => 'qword',
  size   => sub {sizeof  $_[0]->sizek()},
  size_t => sub {typefet $_[0]->sizek()},


  # number/masks for encoding registers
  cnt    => sub {int @{$_[0]->list()}},
  cnt_bs => sub {bitsize $_[0]->cnt()-1},
  cnt_bm => sub {bitmask $_[0]->cnt()-1},


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

    mem => undef,
    ptr => undef,

    flags   => 0x00,
    almask  => $class->reserved_mask(),

    alhist  => [],
    memhist => [],


  },$class;


  # get ctx
  my $mc     = $self->getmc();
  my $memcls = $mc->{bk}->{mem};


  # make container
  my $mem=$memcls->mkroot(

    size  =>
        $class->size()
      * $class->cnt(),

    label => 'ANIMA',
    mccls => $O{mccls},

  );


  # ^make labels
  my $addr = 0x00;
  my @ptr  = map {

    my $v=$mem->lvalue(

      0x00,

      addr  => $addr,
      label => $ARG,

      type  => $class->sizek,

    );

    $addr += $class->size;
    $v;

  } @{$class->list};


  # make program pointer
  my $xp  = $ptr[$self->exec_ptr];
  my $ISA = $mc->{bk}->{ISA};

  $xp->{ptr_t} = typefet 'long';
  $xp->{type}  = $ISA->align_t;


  # save to ice and give
  $self->{mem}=$mem;
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
# alloc register and give idex

sub alloci($self) {


  # get ctx
  my $mc = $self->getmc();
  my $al = $mc->{alloc};

  my $mpart_t = $al->mpart_t();


  # have avail register?
  my ($ezy,$pos)=$mpart_t->fit(

    \$self->{almask},1,
    limit=>16,

  );


  # ^validate and give
  return (defined $pos)
    ? $pos
    : null
    ;

};

# ---   *   ---   *   ---
# ^build mem handle

sub alloc($self) {


  # get idex of free register if any
  my $type = $self->size_t();
  my $idex = $self->alloci();
  my $mem  = $self->{mem};


  # give mem handle if avail
  if(length $idex) {

    my $list = $self->list();
    my $view = $mem->view(

      $idex << $type->{sizep2},
      $type->{sizeof},

      $list->[$idex]

    );


    return $view;


  # ^use stack if none!
  } else {
    nyi "alloc stack fallback"

  };

};

# ---   *   ---   *   ---
# free allocated register from idex

sub freei($self,$idex) {

  # clear bit from mask
  $self->{almask} &=~ 1 << $idex;
  return;

};

# ---   *   ---   *   ---
# ^free allocated from mem handle

sub free($self,$mem) {

  my ($base,$off) = $mem->get_addr();
  my $type        = $self->size_t();

  $off >>= $type->{sizep2};

  $self->freei($off);

  return;

};

# ---   *   ---   *   ---
# save current state var
# to their respective stacks

sub backup_alma($self) {

  push @{$self->{alhist}},
    $self->{almask};

  return;

};

sub backup_mem($self) {

  push @{$self->{memhist}},
    ${$self->{mem}->{buf}};

  return;

};

# ---   *   ---   *   ---
# ^undo

sub restore_alma($self) {

  $self->{almask}=
    pop @{$self->{alhist}};

  return;

};

sub restore_mem($self) {

  ${$self->{mem}->{buf}}=
    pop @{$self->{memhist}};

  return;

};

# ---   *   ---   *   ---
# ^the entire thing

sub backup($self) {

  $self->backup_alma();
  $self->backup_mem();

  return;

};

sub restore($self) {

  $self->restore_alma();
  $self->restore_mem();

  return;

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

  my $out=ioprocin(\%O);

  $self->{mem}->prich(

    %O,

    mute  => 1,
    inner => 0,
    root  => 1,

  );

  push @$out,sprintf "FLAGS: %04Bb\n",
    $self->{flags};

  return ioprocout(\%O);

};

# ---   *   ---   *   ---
1; # ret
