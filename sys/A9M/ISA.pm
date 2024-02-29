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
  use Type;
  use Warnme;

  use Bitformat;
  use FF;

  use Arstd::Array;
  use Arstd::Int;
  use Arstd::String;
  use Arstd::Bytes;
  use Arstd::PM;

  use parent 'A9M::component';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.7;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {
  exeali => (typefet 'word'),
  imp    => 'A9M::opera',

};

  Readonly our $INS_DEF_SZ    => 'word';
  Readonly our $PTR_DEF_SZ    => 'short';
  Readonly our $OPCODE_ROM_SZ => 'dword';


  # default sizes as bitfield
  Readonly our $INS_DEF_SZ_BITS =>
    bitsize(sizeof($INS_DEF_SZ))-1;

  Readonly our $PTR_DEF_SZ_BITS =>
    bitsize(sizeof($PTR_DEF_SZ))-1;


  # names for 0/1/2 operands
  Readonly my $ARGNAMES=>[
    [],['dst'],['dst','src'],

  ];

  # argument type-flags
  Readonly our $ARGFLAG_BS=>3;
  Readonly our $ARGFLAG_BM=>bitmask $ARGFLAG_BS;

  our $ARGFLAG={


    # base format
    %{Bitformat argflag=>(
      dst => $ARGFLAG_BS,
      src => $ARGFLAG_BS,

    )},


    # ^possible values
    r    => 0b000,

    mstk => 0b001,
    mimm => 0b010,
    msum => 0b011,
    mlea => 0b100,

    ix   => 0b101,
    iy   => 0b110,

  };


  # ^values shifted to src bit
  Readonly my $ARGFLAG_BITS=>[qw(

    r

    mstk mimm msum mlea
    ix   iy

  )];

  map {

    $ARGFLAG->{"src_$ARG"}=
       $ARGFLAG->{$ARG}
    << $ARGFLAG->{pos}->{src};

  } @$ARGFLAG_BITS;


  # encoder fetches from here
  Readonly my $ARGFLAG_TAB=>{

    $NULLSTR => 0b000000,
    d        => 0b000000,
    s        => 0b000000,


    dr       => $ARGFLAG->{r},

    dmstk    => $ARGFLAG->{mstk},
    dmimm    => $ARGFLAG->{mimm},
    dmsum    => $ARGFLAG->{msum},
    dmlea    => $ARGFLAG->{mlea},

    dix      => $ARGFLAG->{ix},
    diy      => $ARGFLAG->{iy},


    sr       => $ARGFLAG->{src_r},

    smstk    => $ARGFLAG->{src_mstk},
    smimm    => $ARGFLAG->{src_mimm},
    smsum    => $ARGFLAG->{src_msum},
    smlea    => $ARGFLAG->{src_mlea},

    six      => $ARGFLAG->{src_ix},
    siy      => $ARGFLAG->{src_iy},

  };


# ---   *   ---   *   ---
# GBL

  our $Cache={

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

  };

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # defaults
  $O{mcid}  //= 0;
  $O{mccls} //= caller;

  # nothing to do here ;>
  my $self=bless \%O,$class;
  return $self;

};

# ---   *   ---   *   ---
# makes internal formats

sub mkfmat($self) {


  # run only once!
  state $nit=0;
  return if $nit;

  $nit++;


  # get ctx
  my $mc    = $self->getmc();
  my $anima = $mc->{bk}->{anima};

  cload $self->imp();


  # instruction meta
  Bitformat opcode=>(

    load_src    => 1,
    load_dst    => 1,
    overwrite   => 1,

    argcnt      => 2,
    argflag     => $ARGFLAG->{bitsize},

    opsize      => 2,
    idx         => 16,

  );


  # enconding for register operands
  Bitformat 'r'=>(
    reg => 4,

  );


  # encodings for immediate operands
  Bitformat 'ix'=>(
    imm => 8,

  );

  Bitformat 'iy'=>(
    imm => 16,

  );


  # encodings for memory operands
  Bitformat 'mstk'=>(
    imm => 8,

  );

  Bitformat 'mimm'=>(
    seg => $mc->sizep2_segtab(),
    imm => 16,

  );

  Bitformat 'msum'=>(
    seg => $mc->sizep2_segtab(),
    reg => $anima->cnt_bs(),
    imm => 8,

  );

  Bitformat 'mlea'=>(

    seg   => $mc->sizep2_segtab(),

    rX    => $anima->cnt_bs(),
    rY    => $anima->cnt_bs(),

    imm   => 10,
    scale => 2,

  );


  # fmat for binary section
  # of resulting ROM
  FF 'opcode-tab'=>q[

    word id_mask;
    word idx_mask;

    byte id_bits;
    byte idx_bits;

    bit<opcode> opcode[word];

  ];


  return;

};

# ---   *   ---   *   ---
# make opcode

sub encode($self,$type,$name,@args) {


  # get type from table
  $type=typefet $type
  or return null;


  # find instruction id
  my $idex=$self->get_ins_idex(
    $name,$type->{sizep2},
    map {$ARG->{type}} @args

  );

  return null if $idex eq null;


  # ^get [bitsize:data] array
  # for both instruction and operands
  my @enc=([$Cache->{id_bs},$idex],map {
    my $fmat=Bitformat $ARG->{type};
    [$fmat->{bitsize},$fmat->bor(%$ARG)];

  } @args);


  # ^pack and give
  my $opcd = 0x00;
  my $cnt  = 0;

  map {

    my ($bs,$data)=@$ARG;

    $opcd |= $data << $cnt;
    $cnt  += $bs;

  } @enc;


  return ($opcd,int_urdiv($cnt,8));

};

# ---   *   ---   *   ---
# ^undo ;>

sub decode($self,$opcd) {


  # get ctx
  my $mask = $Cache->{id_bm};
  my $bits = $Cache->{id_bs};

  # count number of bits consumed
  my $csume = 0;


  # get opid and shift out bits
  my $opid    = $opcd & $mask;
     $opcd  >>= $bits;
     $csume  += $bits;

  # read instruction meta
  my $idex = ($opid << 1) + 1;
  my $ins  = $Cache->{romtab}->[$idex]->{ROM};


  # decode args
  my $cnt   = $ins->{argcnt};
  my $flags = $ins->{argflag};
  my @load  = ($ins->{load_dst},$ins->{load_src});

  my @args    = map {

    $self->decode_args(

      \$opcd,
      \$flags,
      \$csume,

      shift @load

    )

  } 0..$cnt-1;


  return {

    ins  => $ins,
    size => int_urdiv($csume,8),

    dst  => $args[0],
    src  => $args[1],

  };

};

# ---   *   ---   *   ---
# ^read next argument from opcode

sub decode_args(

  $self,

  $opcdref,
  $flagsref,
  $csumeref,

  $load

) {


  # read elem flags and shift out bits
  my $flag        = $$flagsref & $ARGFLAG_BM;
     $$flagsref >>= $ARGFLAG_BS;


  # get binary format for arg
  my $fmat=undef;
  for my $key(@$ARGFLAG_BITS) {

    if($flag eq $ARGFLAG->{$key}) {
      $fmat=Bitformat $key;
      last;

    };

  };


  # read bits as hash
  my $mc   = $self->getmc();
  my %data = $fmat->from_value($$opcdref);

  $$opcdref  >>= $fmat->{bitsize};
  $$csumeref  += $fmat->{bitsize};


  # have memory operand?
  if(0 == index $fmat->{id},'m',0) {
    my $fn="decode_$fmat->{id}_ptr";
    $mc->$fn(\%data);


  # have register?
  } elsif($fmat->{id} eq 'r') {

    %data=(
      seg  => $mc->{anima}->{mem},
      addr => $data{reg} * $mc->{anima}->size(),

    );

  };


  return \%data;

};

# ---   *   ---   *   ---
# fetch implementation of
# instruction and call it
# with given args

sub run($self,$type,$idx,@args) {

  my $imp = $self->imp();
  my $fn  = $Cache->{exetab}->[$idx];

  $imp->$fn($type,\@args);

};

# ---   *   ---   *   ---
# get mnemonic id

sub get_idx($name,%O) {

  my $key = $Cache->{mnemonic};
  my $tab = $Cache->{exetab};


  if(! exists $key->{$O{fn}}) {

    push @$tab,$O{fn};

    $key->{$O{fn}}={
      name => $name,
      idx  => $Cache->{execode}++,

    };

  };


  return $key->{$O{fn}}->{idx};

};

# ---   *   ---   *   ---
# fetch instruction idex
# from cache

sub get_ins_idex($class,$name,$size,@ar) {


  my $meta      = $class->get_ins_meta($name);
  my $full_form = ($meta->{argcnt})

    ? $name

    . '_' . (join '_',@ar)

    . '_' . $Type::MAKE::LIST->{ezy}->[$size]


    : $name

    ;


  return warn_invalid($full_form)
  if ! exists $meta->{icetab}->{$full_form};


  return $meta->{icetab}->{$full_form};

};

# ---   *   ---   *   ---
# ^get the whole metadata hash

sub get_ins_meta($class,$name) {

  return warn_invalid($name)
  if ! exists $Cache->{insmeta}->{$name};

  return $Cache->{insmeta}->{$name};

};

# ---   *   ---   *   ---
# ^errme

sub warn_invalid($name) {

  Warnme::invalid 'instruction',

  obj  => $name,
  give => null;

};

# ---   *   ---   *   ---
# cstruc instruction(s)

sub opcode($name,%O) {

  # defaults
  $O{fn}          //= $name;
  $O{argcnt}      //= 2;
  $O{nosize}      //= 0;

  $O{load_src}    //= int($O{argcnt} == 2);
  $O{load_dst}    //= 1;

  $O{fix_immsrc}  //= 0;
  $O{fix_regsrc}  //= 0;
  $O{fix_size}    //= undef;

  $O{overwrite}   //= 1;
  $O{dst}         //= 'rm';
  $O{src}         //= 'rmi';

  $Cache->{insmeta}->{$name}=\%O;

  # ^for writing/instancing
  my $ROM={

    load_src    => $O{load_src},
    load_dst    => $O{load_dst},
    overwrite   => $O{overwrite},

    argcnt      => $O{argcnt},

  };

  # ^just for the compiler
  my $meta=$Cache->{insmeta}->{$name};
  $meta->{icetab}={};


  # queue logic generation
  my $idx=get_idx($name,%O);


  # get possible operand sizes
  my @size=(! $O{nosize})
    ? qw(byte word dword qword)
    : $INS_DEF_SZ
    ;

  @size=(@{$O{fix_size}})
  if defined $O{fix_size};


  # get possible operand combinations
  my @combo=();

  # ^for two-operand instruction
  if($O{argcnt} eq 2) {

    @combo=grep {length $ARG} map {

      my $dst   = substr $ARG,0,1;
      my $src   = substr $ARG,2,1;

      my $allow =
         (0 <= index $O{dst},$dst)
      && (0 <= index $O{src},$src)
      ;

      $ARG if $allow;

    } 'r_r','r_m','r_i','m_r','m_i';


  # ^single operand, so no combo ;>
  } elsif($O{argcnt} eq 1) {
    @combo=split $NULLSTR,$O{dst};

  # ^no operands!
  } else {

    my $data={

      %$ROM,

      argflag => 0x00,
      opsize  => 0x00,
      idx     => $idx,

    };

    $meta->{icetab}->{$name}=$Cache->{romcode};

    return $name => {
      id  => $Cache->{romcode}++,
      ROM => $data,

    };

  };


  # ^generate further variations
  my $round=0;
  combo_vars:

  @combo=map {

    my $cpy  = $ARG;
    my @list = ();


    # have memory operand?
    if($round == 0) {
      @list=(qr{m},qw(mstk mimm msum mlea));

    } else {

      my @ar=($O{fix_immsrc})
        ? 'i'.(qw(x y)[$O{fix_immsrc}-1])
        : qw(ix iy)
        ;

      @list=(qr{i(?!mm)},@ar);

    };


    # ^need to generate specs?
    if(@list) {

      # replace plain combo with
      # specific variations!

      my ($re,@repl)=@list;

      map {

        my $cpy2=$cpy;

        $cpy2=~ s[$re][$ARG];
        $cpy2;

      } @repl;


    # ^nope, use plain combo
    } else {
      $ARG;

    };


  } @combo;

  goto combo_vars if $round++ < 1;
  array_dupop(\@combo);


  # make argument type variations
  return map {

    my ($dst,$src)=split '_',$ARG;

    $src //= $NULLSTR;

    my $argflag =
      ($ARGFLAG_TAB->{"d$dst"})
    | ($ARGFLAG_TAB->{"s$src"})

    ;


    my $ins   = "${name}_$ARG";
    my @sizeb = @size;


    if($src eq 'iy' || $dst eq 'iy') {
      @sizeb=grep {$ARG ne 'byte'} @sizeb;

    };


    # make sized variations
    map {

      my $data={

        %$ROM,

        argflag => $argflag,
        opsize  => (sizeof($ARG) >> 1),
        idx     => $idx,

      };

      $data->{opsize} -= 1
      if $data->{opsize} > 2;

      # perl-side copy
      $meta->{icetab}->{"${ins}_${ARG}"}=
        $Cache->{romcode};

      # ^for use by decoder
      "${ins}_${ARG}" => {
        id  => $Cache->{romcode}++,
        ROM => $data,

      };

    } @sizeb;

  } @combo;

};

# ---   *   ---   *   ---
# load/save tables from cache

sub gen_ROM_table($class) {
  $Cache->{romtab}=$class->_gen_ROM_table();
  return $Cache;

};

# ---   *   ---   *   ---
# ^definitions

sub _gen_ROM_table($class) {


  # fetch instruction table
  my $imp=$class->imp();
  cload $imp;

  my $tab = $imp->table();


  # ^array as hash
  my $ti  = 0;
  my @tk  = array_keys($tab);
  my @tv  = array_values($tab);


  # ^walk
  my $out=[
    map  {opcode $ARG,%{$tv[$ti++]}} @tk

  ];


  # ^save bitsizes and give
  $Cache->{id_bs}   = bitsize $Cache->{romcode};
  $Cache->{idx_bs}  = bitsize $Cache->{execode};
  $Cache->{id_bm}   = bitmask $Cache->{id_bs};
  $Cache->{idx_bm}  = bitmask $Cache->{idx_bs};


  return $out;

};

# ---   *   ---   *   ---
# cache result of generator

  sub thiscls {__PACKAGE__};
  use Vault 'ARPATH';

  $Cache=Vault::cached(
    'Cache',\&gen_ROM_table,thiscls

  );

# ---   *   ---   *   ---
1; # ret
