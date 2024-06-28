#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M ISA
# Arcane 9 instruction set
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::ISA;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_words);
  use List::Util qw(max);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;
  use Warnme;

  use Arstd::Array;
  use Arstd::Path;
  use Arstd::Int;
  use Arstd::Bytes;
  use Arstd::PM;

  use parent 'A9M::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.02.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # where is this module?
  SYSNAME => 'ARPATH',


  # use this id to fetch ROM from cache!
  TABID  => 'ROMTAB',

  # instruction implementation
  guts_t => 'A9M::ISA::opera',
  enc_t  => 'A9M::ISA::encoding',
  make_t => 'A9M::ISA::MAKE',


  # minimum executable alignment
  align_t => (typefet 'dword'),

  # default operand size
  def_t   => (typefet 'word'),


  # reference byte sizes
  ins_def_t    => (typefet 'word'),
  ptr_def_t    => (typefet 'short'),
  opcode_rom_t => (typefet 'dword'),


};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # defaults
  $O{mcid}  //= 0;
  $O{mccls} //= caller;


  # kick ~
  my $guts_t=$class->guts_t;
  cloadi $guts_t;

  my $guts=$guts_t->new(%O);

  # make ice and give
  my $self=bless {

    %O,
    guts=>$guts

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# get [bitsize:data] array
# for encoding instruction + operands

sub full_encoding($self,$idex,$args) {

  my $class = ref $self;
  my $enc_t = $self->enc_t;

  my $tab   = $class->opcode_table;

  return (

    [$tab->{id_bs},$idex],

    map {

      my $fmat=$enc_t->operand_encoding(
        $class,
        $ARG->{type}

      );

      [$fmat->{bitsize},$fmat->bor(%$ARG)];

    } @$args

  );

};

# ---   *   ---   *   ---
# fetch instruction idex
# from cache

sub _get_ins_idex($class,$name,$size,@args) {


  my $opsz_list = Type::MAKE->LIST;
  my $opsz      = $opsz_list->{ezy}->[$size];

  my $meta      = $class->get_ins_meta($name);
  my $full_form = ($meta->{argcnt})

    ? $name

    . '_' . (join '_',@args)

    . '_' . $opsz


    : $name

    ;


  return (
    $meta->{icetab}->{$full_form},
    $full_form

  );

};

# ---   *   ---   *   ---
# ^validates instruction!

sub get_ins_idex($class,$name,$size,@args) {

  my ($ins,$full)=$class->_get_ins_idex(
    $name,$size,@args

  );

  return (defined $ins)
    ? $ins
    : warn_invalid($full)
    ;

};

# ---   *   ---   *   ---
# ^get the whole metadata hash

sub get_ins_meta($class,$name) {

  my $tab=$class->opcode_table;

  return warn_invalid($name)
  if ! exists $tab->{insmeta}->{$name};

  return $tab->{insmeta}->{$name};

};

# ---   *   ---   *   ---
# ^errme

sub warn_invalid($name) {

  Warnme::invalid 'instruction',

  obj  => $name,
  give => null;

};

# ---   *   ---   *   ---
# lazy get attr from meta

sub get_ins_fix_size($self,$name) {

  my $meta=$self->get_ins_meta($name);
  return null if ! defined $meta;

  return $meta->{fix_size};

};

sub get_ins_ipret_fn($self,$name) {

  my $meta=$self->get_ins_meta($name);
  return null if ! defined $meta;

  return $meta->{ipret_fn};

};

# ---   *   ---   *   ---
# ^runs interpreter bit if
# instruction has one

sub ins_ipret($self,$main,$name,@args) {

  my $fn=$self->get_ins_ipret_fn($name);
  return if ! $fn;

  my $guts=$self->{guts};
  return $guts->$fn($main,@args);

};

# ---   *   ---   *   ---
# dbout, nevermind this

sub insname($self,$ins) {

  my $tab=$self->opcode_table;
  return $tab->{exetab}->[$ins->{idx}];

};

# ---   *   ---   *   ---
# translates from operation
# symbol to instruction

sub xlate($self,$sym,$size,@args) {


  # get type descriptor
  $size=typefet $size;

  # fetch instruction name from symbol
  my $guts = $self->guts_t;
  my $name = $guts->xlate($sym,@args);


  # ^fetch the instruction itself
  my ($ins,$full) = $self->_get_ins_idex(
    $name,$size->{sizep2},map {
      $ARG->{type}

    } @args

  );


  # ^if we don't have a full instruction,
  # that means we need to break it down!
  my @out=();

  # ^that's what we do here...
  if(! defined $ins) {

    my $meta=$self->get_ins_meta($name);


    # imm dst to reg
    if(! index $meta->{dst},'r') {

      my ($dst,$imload)=
        $self->imload($size,$args[0]);

      unshift @out,$imload;
      $args[0]=$dst;

    };

    # ^imm src to reg
    if(! index $meta->{src},'r') {

      my ($dst,$imload)=
        $self->imload($size,$args[1]);

      unshift @out,$imload;
      $args[1]=$dst;

    };

  };


  return @out,[$size,$name,@args];

};

# ---   *   ---   *   ---
# when we want to allocate some
# registers or stack to do an
# intermediate load...

sub imload($self,$size,$src) {

  # get ctx
  my $mc  = $self->getmc();
  my $reg = $mc->{anima};

  # fetch mem
  my $ri  = $reg->alloci();
  my $dst = {type=>'r',reg=>$ri};

  # give (dst,ins)
  return $dst,[$size,'ld',$dst,$src];

};

# ---   *   ---   *   ---
# get immediate type matching
# bitsize of value

sub immsz($self,$x) {


  # value pending resolution?
  my ($isref)=Chk::cderef $x,0;

  return sub {

    my ($isref,$have)=
      Chk::cderef $x,1;

    $self->immsz($have);

  } if $isref;


  # ^nope, get size ;>
  my $enc  = $self->enc_t;
  my $size = bitsize $x;

  my $type=($size > $enc->ix_bs)
    ? ($size > $enc->iy_bs)
      ? 'iz'
      : 'iy'

    : 'ix'
    ;

  return $type;

};

# ---   *   ---   *   ---
# rebuild module if need
# return if already done

sub ready_or_build($self) {


  # run only once for each class!
  state $nit   = {};
  my    $class = ref $self;

  return if exists $nit->{$class};

  $nit->{$class}=1;


  # load implementation
  my $guts_t = $self->guts_t;
  my $enc_t  = $self->enc_t;
  my $make_t = $self->make_t;

  cload $guts_t;
  cload $enc_t;
  cload $make_t;

  $enc_t->generate($self);
  $class->load_ROM();
  $enc_t->postgen($class);

  return;

};

# ---   *   ---   *   ---
# spawn container for table
# generator

sub make_builder {

  my $class = St::cpkg;
  my $enc_t = $class->enc_t;

  return {

    operand_tid => $enc_t->operand_tid($class),
    ins_def_t   => $class->ins_def_t,

    guts_t      => $class->guts_t,

  };

};

# ---   *   ---   *   ---
# get *cached* opcode table

sub opcode_table($class) {

  $class=(length ref $class)
    ? ref $class
    : $class
    ;

  return $class->classcache($class->TABID);

};

# ---   *   ---   *   ---
# load/regen opcode table

sub load_ROM($class,@args) {


  # load sub packages
  my $make_t = $class->make_t;
  my $guts_t = $class->guts_t;
  my $enc_t  = $class->enc_t;


  # set dependencies
  our $sysname=$class->SYSNAME;
  use Vault $sysname;

  Vault::depson map {
    find_pkg $ARG

  } $guts_t,$make_t,$enc_t;


  # initialize
  my $tab = $class->opcode_table;
  %$tab   = (

    romcode    => 0,
    execode    => 0,

    id_bs      => 0,
    id_bm      => 0,
    idx_bs     => 0,
    idx_bm     => 0,

    insmeta    => {},

    mnemonic   => {},
    exetab     => [],
    romtab     => [],

  ) if ! int %$tab;


  # fetch or regen table if need
  my $fn   = "$make_t\::crux";
     $fn   = \&$fn;

  my $have = Vault::cached(

    ROMTAB  => $fn,
    $make_t => $tab,

    \&make_builder,

  );

  %$tab = %$have;


  return;

};

# ---   *   ---   *   ---
1; # ret
