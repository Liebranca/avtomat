#!/usr/bin/perl
# ---   *   ---   *   ---
# IPRET:ENCODER
# Program to bytes!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::encoder;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;
  use Chk;
  use Type;
  use Bpack;
  use Bitformat;

  use Arstd::Bytes;
  use Arstd::Int;
  use Arstd::IO;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT=>{

    main => undef,
    Q    => {asm=>[]},

  },

  exewrite_skip => qr{^(?:

    data\-decl
  | seg\-decl

  | raw

  )$}x,

  exewrite_noderef => qr{^(?:
    seg\-decl|raw

  )$}x,

};

# ---   *   ---   *   ---
# get instruction id from descriptor

sub insid($self,$type,$name,$args) {

  # get type from table
  $type=typefet $type
  or return null;

  # give valid instruction or null
  return $self->ISA->get_ins_idex(

    $name,
    $type->{sizep2},

    map {$ARG->{type}}
    @$args

  );

};

# ---   *   ---   *   ---
# bytepack insid and operands

sub packins($self,$idex,$args) {

  # fstate
  my $opcd = 0x00;
  my $cnt  = 0;

  # walk and join [bitsize,bitpacked]
  map {

    my ($bs,$data)=@$ARG;

    $opcd |= $data << $cnt;
    $cnt  += $bs;


  } $self->ISA->full_encoding($idex,$args);


  # give (opcode,bytesize)
  return ($opcd,int_urdiv($cnt,8));

};

# ---   *   ---   *   ---
# encoding-less requests ;>

sub skip_encode($self,$type,$name,@args) {


  # get ctx
  my $main = $self->{main};
  my $mc   = $main->{mc};
  my $eng  = $main->{engine};
  my $seg  = $mc->{segtop};
  my $size = 0x00;


  # dumping raw bytes?
  if($name eq 'raw') {

    map {


      # cut nullterm
      my $bytes = $ARG;
      my $step  = (length $bytes)-1;

      $bytes=substr $bytes,0,$step;


      # ^overwrite and go next
      $seg->brkfit($step);
      $seg->store(cstr=>$bytes,$seg->{ptr});

      $seg->{ptr} += $step;
      $size       += $step;


    } @args;

    return 'raw',$size;


  # making segment?
  } elsif($name eq 'seg-decl') {
    return 'seg-decl',0x00;


  # dumping variables?
  } elsif($name eq 'data-decl') {

    map {


      # fetch dst/src
      my $sym=${$mc->valid_psearch(
        @{$ARG->{id}}

      )};


      my ($value)=$eng->value_flatten(
        $ARG->{data},

      );


      # modifying current segment?
      my $modit=$seg eq $sym->getseg();

      # ^reset write position?
      $sym->{addr}=$seg->{ptr}
      if $modit;


      # make the write...
      my $step=$sym->store($value,deref=>0);

      # ^adjust pointer?
      if($modit) {
        $seg->{ptr}  += $step;
        $size        += $step;

      };


    } @args;


    return 'data-decl',$size;

  };


  return;

};

# ---   *   ---   *   ---
# get opcode from descriptor

sub encode_opcode($self,$typesrc,$name,@args) {


  # deref!
  my ($isref,$type)=
    Chk::cderef $typesrc,1;


  # skip?
  my @skip=$self->skip_encode(
    $type,$name,@args

  );

  return @skip if @skip;


  # get instruction id
  my $idex=$self->insid(
    $type,$name,\@args

  );

  # ^give valid opcode or null
  return (length $idex)
    ? $self->packins($idex,\@args)
    : $idex
    ;

};

# ---   *   ---   *   ---
# ^bat

sub encode_program($self,$program) {

  map {

    my ($opcd,$size)=
      $self->encode_opcode(@$ARG);

    (length $opcd)
      ? [$opcd,$size]
      : return null
      ;


  } @$program;

};

# ---   *   ---   *   ---
# packs and pads encoded instruction

sub format_opcode($self,$ins) {

  return null if ! length $ins;

  my ($opcd,$size)=@$ins;

  my $have = join $NULLSTR,map {

    my $type  = typefet $ARG;
    my $bytes = pack $type->{packof},$opcd;

    $opcd >>= $type->{sizebs};
    $bytes;

  } typeof $size;


  return ($have,$size)

};

# ---   *   ---   *   ---
# descriptor array to bytecode

sub encode($self,$program) {


  # get ctx
  my $main = $self->{ipret};
  my $mc   = $main->{mc};
  my $mem  = $mc->{bk}->{mem};

  # fstate
  my $bytes = '';
  my $total = 0;
  my $end   = 0;


  # stirr [opcode,size] array
  map {

    my ($have,$size)=
      $self->format_opcode($ARG);

    $end    = $total;
    $bytes .= $have;
    $total += $size;


  } $self->encode_program($program);


  # align binary to ISA spec
  my $ISA     = $self->ISA;
  my $align_t = $ISA->align_t;

  # ^by null pad
  my $diff = $end % $align_t->{sizeof};

  $bytes .= pack "C[$diff]",(0) x $diff;
  $total += $diff;


  # give (bytecode,size)
  return ($bytes,$total);

};

# ---   *   ---   *   ---
# write opcode to current segment

sub exewrite($self,$opsz,$name,@args) {


  # get ctx
  my $main = $self->{main};
  my $mc   = $main->{mc};
  my $eng  = $main->{engine};

  # dereference non-static
  my @copy=map {

    (is_hashref $ARG)
      ? {%$ARG}
      : $ARG
      ;

  } @args;

  $eng->opera_static(\@copy,1)
  if ! ($name=~ $self->exewrite_noderef);


  # encode or die ;>
  my ($opcd,$size)=$self->encode_opcode(
    $opsz,$name,@copy

  );

  goto skip if $opcd=~ $self->exewrite_skip;


  # ^catch encoding fail
  $main->perr(
    "cannot encode instruction",
    lvl=>$AR_FATAL

  ) if ! length $opcd;


  # map int to bytes ;>
  ($opcd,$size)=
    $self->format_opcode([$opcd,$size]);

  # ^write!
  my $mem=$mc->{segtop};

  $mem->brkfit($size);
  $mem->store(cstr=>$opcd,$mem->{ptr});
  $mem->{ptr} += $size;


  skip:
  return $size;

};

# ---   *   ---   *   ---
# ^out of order
#
# this is when you want to
# solve instructions in multiple
# passes. what does that mean?
#
# the order in which the requests
# are sent is not necessarily the
# same in which they must be
# processed!
#
# for that reason, you must provide
# an idex for the request so that
# the instruction is written to
# the right address ;>

sub binreq($self,$branch,@req) {


  # get ctx
  my $main = $self->{main};
  my $mc   = $main->{mc};
  my $seg  = $mc->{segtop};

  my $proc = $mc->{hiertop}->{p3ptr};
  my $tab  = $proc->{vref}->{data};


  # validate and add request at idex
  my $Q   = $self->{Q}->{asm};
  my $uid = $branch->{-uid};

  $main->perr("node uid conflict!")
  if defined $Q->[$uid];


  $Q->[$uid]=[$branch,$seg,undef,\@req];

  $tab->timeline($uid=>$Q->[$uid])
  if defined $tab;


  return;

};

# ---   *   ---   *   ---
# ^processes requests and clears Q

sub exewrite_run($self) {


  # get ctx
  my $main  = $self->{main};
  my $mc    = $main->{mc};
  my $ISA   = $mc->{ISA};
  my $align = $ISA->align_t->{sizeof};

  # remember state of register/stack
  $mc->backup();


  # walk the sorted Q
  my $walked = {};
  my @out    = map {


  # have request?
  if(is_arrayref $ARG) {


    # unpack
    my ($seg,$route,$req)=@$ARG;


    # reset addr on first step
    if(! exists $walked->{$seg}) {
      $seg->clear();
      $walked->{$seg}=$seg;

    };

    # update reference
    if($route &&! exists $walked->{$route}) {
      $route->reset_view_addr();
      $walked->{$route}=$route;

    };


    # write to top ;>
    my $addr=$seg->{ptr};
    my $size=0;

    # make segment current and run F
    ($mc->{cas})=$seg->{root};
    $mc->setseg($seg);

    map {

      my ($opsz,$name,@args)=@$ARG;

      $size+=$self->exewrite(
        $opsz,$name,@args

      );

    } @$req;


    # adjust referenced buffer
    $route->update_view_buf($size)
    if $route;


    # give instruction loc && len
    { size => $size,
      addr => $addr,

    };


  # align segments and reset ptr on end!
  } elsif($ARG) {
    $ARG->{ptr} += $align;
    $ARG->tighten($align);

    $ARG->{ptr}=0;

    ();

  } else {()};


  # ^flatten the Q...
  } map {

    (is_arrayref $ARG)
      ? @$ARG
      : $ARG
      ;

  } @{$self->exewrite_sort()};


  # clear and give
  $mc->restore();

  return @out;

};

# ---   *   ---   *   ---
# sorts request by segment

sub exewrite_sort($self) {


  # filter undef from queue
  my $Q = $self->{Q}->{asm};
  my @Q = grep {defined $ARG} @$Q;


  # ^walk
  my $order = [[],0,[],0,[],0,[],0];

  map {


    # map segment type to idex
    my $seg  = $ARG->[0];
    my $idex = {

      non    => 0,

      rodata => 2,
      data   => 4,

      code   => 6,


    }->{$seg->flagkey};


    # give [requests=>segment]
    push @{$order->[$idex]},$ARG;
    $order->[$idex+1]=$seg;


  } @Q;


  return $order;

};

# ---   *   ---   *   ---
# operator to binary ;>

sub opera_encode($self,$program,$const) {


  # get ctx
  my $main = $self->{main};
  my $eng  = $main->{engine};
  my $mc   = $main->{mc};
  my $ISA  = $mc->{ISA};
  my $l1   = $main->{l1};


  # give plain value on const branch
  if($const) {


    # build binary
    my ($bytes,$size)=
      $self->encode($program);

    # execute and give result
    my @ret=$eng->strexe($bytes);
    return $l1->tag(NUM=>$ret[-1]);


  # ^make mini-executable for non-const!
  } else {

    # make new segment holding opcodes
    my $seg=$mc->{scratch}->new();
    my $old=$mc->{segtop};

    $seg->{executable} = 1;


    # ^swap and write!
    $mc->{segtop}=$seg;

    map {$self->exewrite(@$ARG)}
    @$program;

    $mc->{segtop}=$old;


    # ^give handle via id
    return $l1->tag(EXE=>$seg->{iced});

  };

};

# ---   *   ---   *   ---
# get binary format used to
# decode operand

sub operand_type($self,$operand) {


  # get ctx
  my $ISA   = $self->ISA;
  my $super = ref $ISA;

  my $enc_t = $ISA->enc_t;


  # get binary format for operand
  my $operand_t = $enc_t->operand_t($super);
  my ($type)    = grep {
    $operand eq $operand_t->{$ARG}

  } @{$enc_t->operand_types};

  my $fmat=Bitformat "$super.$type";


  return ($type,$fmat);

};

# ---   *   ---   *   ---
# read instruction bits
# from opcode

sub decode_instruction($self,$opcd) {


  # get ctx
  my $ISA  = $self->ISA;
  my $tab  = $ISA->opcode_table;

  my $mask = $tab->{id_bm};
  my $bits = $tab->{id_bs};


  # read instruction meta
  my $opid = $opcd & $mask;

  my $idex = ($opid << 1) + 1;
  my $ins  = $tab->{romtab}->[$idex]->{ROM};


  return ($ins,$bits);

};

# ---   *   ---   *   ---
# read next argument from opcode

sub decode_operand($self,$opcd,$operand,%O) {


  # get type/packing fmat
  my ($type,$fmat)=
    $self->operand_type($operand);

  # read opcode bits into hash
  my $mc   = $self->{main}->{mc};
  my %data = $fmat->from_value($opcd);


  # have memory operand?
  if(0 == index $type,'m',0) {
    my $fn=(! $O{xlate})
      ? 'decode'
      : 'xlate'
      ;

    $fn="${fn}_${type}_ptr";
    $mc->$fn(\%data);


  # have register?
  } elsif($type eq 'r') {

    %data=(! $O{xlate})

      ? (

        seg  => $mc->{anima}->{mem},
        addr => $data{reg} * $mc->{anima}->size(),

      ) : (

        type  => 'r',
        value => $data{reg},

      );


  # have immediate!
  } else {

    %data=(
      type  => 'i',
      value => $data{imm},

    ) if $O{xlate};

  };


  return (\%data,$fmat);

};

# ---   *   ---   *   ---
# ^bat

sub decode_operands($self,$ins,$opcd,%O) {


  # read operand types from ROM
  my $cnt      = $ins->{argcnt};
  my $operands = $ins->{operands};
  my $size     = 0;


  # read operand data from opcode
  my $enc_t      = $self->ISA->enc_t;
  my ($dst,$src) = map {


    # get next
    my $operand    = $operands & $enc_t->operand_bm;
       $operands >>= $enc_t->operand_bs;

    # ^decode
    my ($out,$fmat)=
      $self->decode_operand($opcd,$operand,%O);


    # go next and give
    $opcd >>= $fmat->{bitsize};
    $size  += $fmat->{bitsize};

    $out;


  } 0..$cnt-1;


  return ($dst,$src,$size);

};

# ---   *   ---   *   ---
# get descriptor from opcode

sub decode_opcode($self,$opcd,%O) {


  # read instruction
  my ($ins,$ins_sz)=
    $self->decode_instruction($opcd);

  $opcd >>= $ins_sz;


  # read operands
  my ($dst,$src,$opsz)=
    $self->decode_operands($ins,$opcd,%O);


  # give descriptor
  my $size=$ins_sz+$opsz;

  return {

    ins  => $ins,
    size => int_urdiv($size,8),

    dst  => $dst,
    src  => $src,

  };

};

# ---   *   ---   *   ---
# bytecode to descriptor array

sub decode($self,$program) {


  # get ctx
  my $ISA     = $self->ISA;
  my $align_t = $ISA->align_t;

  my $limit   = length $program;
  my $step    = $align_t->{sizeof};


  # consume buf
  my $ptr=0x00;
  my @out=();

  while($limit >= $ptr + $step) {


    # get next
    my $s    = substr $program,$ptr,$step;
    my $opcd = unpack $align_t->{packof},$s;

    last if ! $opcd;


    # ^consume bytes and give
    my $ins  = $self->decode_opcode($opcd);
       $ptr += $ins->{size};

    push @out,$ins;

  };


  return \@out;

};

# ---   *   ---   *   ---
# read next opcode from rip

sub exeread($self,%O) {


  # defaults
  $O{xlate} //= 0;


  # get ctx
  my $main  = $self->{main};
  my $mc    = $main->{mc};
  my $anima = $mc->{anima};
  my $rip   = $anima->{rip};

  # fetch instruction or stop
  my $opcd=$rip->load();
  return 0x00 if ! $opcd;

  # ^go next and give
  my $ins=$self->decode_opcode($opcd,%O);
  my $off=$rip->load(deref=>0);

  $rip->store($off+$ins->{size},deref=>0);

  return $ins;

};

# ---   *   ---   *   ---
1; # ret
