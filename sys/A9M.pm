#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M
# The Arcane 9 Machine
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M;

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
  use Icebox;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::Int;
  use Arstd::PM;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.0;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {
  segtab_t => (typefet 'xword'),

};

  Readonly my $COMPONENTS => [qw(
    flags mem ptr alloc anima ISA

  )];

# ---   *   ---   *   ---
# GBL

St::vstatic {};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # defaults
  $O{memroot} //= 'non';
  $O{pathsep} //= $DCOLON_RE;


  # find components through methods
  my $bk={ map {
    my $fn="get_${ARG}_bk";
    $ARG=>$class->$fn();

  } @$COMPONENTS };


  # make ice
  my $self=bless {

    cas      => undef,
    scratch  => undef,
    alloc    => undef,
    scope    => undef,
    anima    => undef,
    ISA      => undef,


    segtab   => undef,
    segtab_i => 0x00,

    bk       => $bk,

    path     => [],
    pathsep  => $O{pathsep},


  },$class;


  # ^add to box
  my $frame = $class->get_frame();
  my $id    = $frame->icemake($self);

  $self->reset_segtab();


  # nit user memory
  $self->{cas}=$bk->{mem}->mkroot(
    mcid  => $id,
    label => $O{memroot},

  );

  # ^nit scratch buffer for internal use
  $self->{scratch}=$bk->{mem}->mkroot(

    mcid  => $id,
    label => 'SCRATCH',

    size  => 0x00,

  );


  # kick components in need of kicking!
  $self->{anima}=$bk->{anima}->new(mcid=>$id);
  $self->{alloc}=$bk->{alloc}->new(mcid=>$id);
  $self->scope($O{memroot});

  $self->{ISA}=$bk->{ISA}->new(mcid=>$id);
  $self->{ISA}->mkfmat();


  return $self;

};

# ---   *   ---   *   ---
# dump instructions to segment

sub exewrite($self,$seg,@program) {


#  # walk input
#  my $total=0;
#  map {
#
#
#
#
#
#    # grow buf if need
#    $seg->brkfit($size);
#    $total += $size;
#
#
#    # write opcode to buf
#    map {
#
#      # we do chunk by chunk to bytepack;
#      # no aligning to pow2 in-between opcodes!
#      my $type    = typefet $ARG;
#
#      my $chunk   = $opcd & $type->{sizebm};
#         $opcd  >>= $type->{sizebs};
#
#      # write chunk and go next
#      $seg->store($type,$chunk,$seg->{ptr});
#      $seg->{ptr} += $type->{sizeof};
#
#
#    } typeof $size;
#
#
#  } @program;
#
#
#  # apply alignment to segment accto
#  # ISA specs
#  my $align=$self->{ISA}->exeali();
#  $seg->align($align->{sizeof});
#
#
#  return $total;

};

# ---   *   ---   *   ---
# ^read instructions from segment

sub exeread($self,$seg) {


  # get ctx
  my $align = $self->{ISA}->exeali();

  my $limit  = $seg->{size};
  my $addr   = 0x00;


  # walk segment
  my @out=();

  while($addr + $align->{sizeof} < $limit) {

    my $bytes = $seg->load($align,$addr);
    my $ins   = $self->{ISA}->decode($bytes);

    $addr += $ins->{size};
    push @out,$ins;

  };


  return @out;

};

# ---   *   ---   *   ---
# interpret instruction array

sub ipret($self,@program) {


  # get ctx
  my @names = qw(dst src);

  my $ezy   = $Type::MAKE::LIST->{ezy};
  my $ret   = 0x00;


  # walk input
  map {


    # unpack
    my $data = $ARG;
    my $ins  = $data->{ins};
    my $size = typefet $ezy->[$ins->{opsize}];


    # proc operands
    my @values=map {

      my $o    = $data->{$ARG};
      my $imm  = exists $o->{imm};


      # memory deref?
      if($ins->{"load_$ARG"} &&! $imm) {

        $o->{seg}->load(
          $size,$o->{addr}

        );

      # ^immediate?
      } elsif($imm) {
        Bpack::layas($size,$o->{imm});

      # ^plain addr?
      } else {

        my $addr=
          $o->{seg}->absloc()+$o->{addr};

        Bpack::layas($size,$addr);

      };


    } @names[0..$ins->{argcnt}-1];


    # invoke
    my $out=$self->{ISA}->run(
      $size,$ins->{idx},@values

    );

    $ret=$out->[0];


    # ^save result?
    if($ins->{overwrite}) {

      my $dst=$data->{dst};

      $dst->{seg}->store(
        $size,$out,$dst->{addr}

      );

    };


  } @program;


  return $ret;

};

# ---   *   ---   *   ---
# ^fetch && run seg from id

sub exerun($self,$id) {


  # fetch executable segment
  my $mem   = $self->{cas};
  my $frame = $mem->{frame};

  my $seg   = $frame->ice($id);


  # read instructions and run
  my @program = $self->exeread($seg);
  my $ret     = $self->ipret(@program);

  return $ret;

};

# ---   *   ---   *   ---
# set/get current namespace

sub scope($self,@path) {


  # set new?
  if(@path) {

    # get ctx
    my $mem  = $self->{cas};
    my $tree = $mem->{inner};

    shift @path if $path[0] eq $tree->{value};


    # validate input
    my $out=$tree->haslv(@path)
    or return badfet('DIR',@path);


    # ^overwrite
    $self->{path}  = [$tree->{value},@path];
    $self->{scope} = $out;

  };


  # ^give node if defined
  my $out=$self->{scope};
  return (defined $out) ? $out : null ;

};

# ---   *   ---   *   ---
# template: wraps mem->search

sub _search($self,$name,@path) {


  # default to current path
  @path=@{$self->{path}}
  if ! @path;

  # get ctx
  my $mem  = $self->{cas};
  my $tree = $mem->{inner};

  shift @path if $path[0] eq $tree->{value};


  # make (path,to) from (path::to)
  # then look in namespace
  my @have = $mem->search($name,@path);


  return @have;

};

# ---   *   ---   *   ---
# ^deref

sub dsearch($self,$name,@path) {

  # get ctx/solve path
  my $mem  = $self->{cas};
     @path = $self->_search($name,@path);

  # give name if found
  return $mem->{'*fetch'};

};

# ---   *   ---   *   ---
# ^deref+errme

sub search($self,$name,@path) {

  # get ctx/solve path
  my $mem  = $self->{cas};
     @path = $self->_search($name,@path);

  # give name if found
  my $out = $mem->{'*fetch'}
  or return badfet($name,@path);


  return $out;

};

# ---   *   ---   *   ---
# ^no deref! (but yes errme ;>)

sub psearch($self,$name,@path) {

  # get ctx/solve path
  my $mem  = $self->{cas};
     @path = $self->_search($name,@path);

  # get *ptr* to value!
  my $out = $mem->{inner}->get(@path)
  or return badfet($name,@path);


  return $out;

};

# ---   *   ---   *   ---
# ^errme

sub badfet($name,@path) {

  Warnme::not_found 'symbol name',

  cont  => 'path',
  where => (join '::',@path),
  obj   => $name,

  give  => null;

};

# ---   *   ---   *   ---
# wraps value decl

sub decl($self,$type,$name,$value,@subseg) {

  my $scope = $self->{scope};
  my $mem   = $scope->{mem};


  # use sub path?
  if(@subseg) {

    my $subseg=$scope->haslv(@subseg)
    or return badfet('DIR',@subseg);

    $mem=$subseg->{mem};

  };


  # have ptr?
  my ($ptr_t) = Type->is_ptr($type);

  $ptr_t=(length $ptr_t)
    ? "$ptr_t"
    : undef
    ;


  # make ice and give
  $mem->decl($type,$name,$value,ptr_t=>$ptr_t);

};

# ---   *   ---   *   ---
# resets segment table state

sub reset_segtab($self) {

  my $type=$self->segtab_t();

  $self->{segtab}=[
    (null) x $type->{sizeof}

  ];

  $self->{segtab_i}=0x00;

};

# ---   *   ---   *   ---
# gets idex of segment in
# current configuration of
# segment table

sub segid($self,$seg) {

  # get ctx
  my $tab = $self->{segtab};
  my $top = \$self->{segtab_i};


  # have segment in table?
  my $idex=array_iof(
    $self->{segtab},$seg

  );

  # ^nope, can fit another?
  if(! defined $idex) {


    # ^yes, add new entry
    my $type=$self->segtab_t();

    if($$top < $type->{sizeof}) {
      $idex=$$top;
      $self->{segtab}->[$$top++]=$seg;


    # ^nope, give warning
    } else {
      return warn_full_segtab($self->{id});

    };

  };


  return $idex;

};

# ---   *   ---   *   ---
# ^errme

sub warn_full_segtab($id) {

  warnproc

    "segment table for machine ID "
  . "[num]:%u is full",

    args => [$id],
    give => null

  ;

};

# ---   *   ---   *   ---
# OR together segment:offset

sub encode_ptr($self,$seg,$off) {

  # validate segment
  my $segid=$self->segid($seg);
  return $segid if ! length $segid;

  # ^roll and give
  my $type = $self->segtab_t();
  my $bits = $type->{sizep2};

  my $ptrv = $segid | ($off << $bits);


  return $ptrv;

};

# ---   *   ---   *   ---
# ^undo

sub decode_ptr($self,$ptrv) {

  # unroll
  my $type  = $self->segtab_t();
  my $bits  = $type->{sizep2};

  my $mask  = (1 << $bits)-1;

  my $segid = $ptrv  & $mask;
  my $off   = $ptrv >> $bits;


  # ^validate and give
  my $seg=$self->{segtab}->[$segid];

  return (length $seg)
    ? ($seg,$off)
    : warn_decode($segid,$off)
    ;

};

# ---   *   ---   *   ---
# ^errme

sub warn_decode($segid,$off) {

  warnproc


    'pointer to address '
  . '$[num]:%X:[num]:%X '

  . 'could not be read',


  args => [$segid,$off],
  give => null;


};

# ---   *   ---   *   ---
# unpacks [seg:sb-imm]

sub decode_mstk_ptr($self,$o) {

  nyi('A9M::stack');

  my $seg  = $self->{stack}->{mem};
  my $base = $self->{anima}->fetch(0xC);
  my $off  = -$o->{imm};

  %$o=(
    seg  => $seg,
    addr => $base-$off,

  );


  return;

};

# ---   *   ---   *   ---
# unpacks [seg:imm]

sub decode_mimm_ptr($self,$o) {

  my $seg  = $self->{segtab}->[$o->{seg}];
  my $base = $o->{imm};

  %$o=(
    seg  => $seg,
    addr => $base,

  );


  return;

};

# ---   *   ---   *   ---
# unpacks [seg:rX+imm]

sub decode_msum_ptr($self,$o) {

  my $seg  = $self->{segtab}->[$o->{seg}];
  my $base = $self->{anima}->fetch($o->{rX});
  my $off  = $o->{imm};

  %$o=(
    seg  => $seg,
    addr => $base+$off,

  );


  return;

};

# ---   *   ---   *   ---
# unpacks [seg:rX+rY+imm*scale]

sub decode_mlea_ptr($self,$o) {


  # load register values
  my @r=map {

    if($ARG) {
      my $ptr=$self->{anima}->fetch($ARG-1);
      $ptr->load();

    } else {0};

  } ($o->{rX},$o->{rY});


  # load plain values
  my $scale = 1 << $o->{scale};
  my $imm   = $o->{imm};
  my $seg   = $self->{segtab}->[$o->{seg}];


  # apply scale to immediate?
  if($imm) {
    $imm *= $scale;

  # ^second register?
  } elsif($r[1]) {
    $r[1] *= $scale;

  # ^first register?
  } else {
    $r[0] *= $scale;

  };


  # collapse and give
  %$o=(
    seg  => $seg,
    addr => $r[0]+$r[1]+$imm

  );

  return;

};

# ---   *   ---   *   ---
# find implementation of
# an individual component

sub get_bk_class($class,$name) {

  my $pkg="A9M\::$name";

  cloadi $pkg;
  return $pkg;

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps(

  q[$class->get_bk_class] => q[$class],

  map {["get_${ARG}_bk" => "'$ARG'"]}
  @$COMPONENTS

);

# ---   *   ---   *   ---
# ^fetch component in use by instance

sub getbk($class,$idex,$name) {

  my $frame = $class->get_frame();
  my $ice   = $frame->ice($idex);

  my $bk    = $ice->{bk};

  return (exists $bk->{$name})
    ? $bk->{$name}
    : warn_nobk($name)
    ;

};

# ---   *   ---   *   ---
# ^errme

sub warn_nobk($name) {

  Warnme::invalid 'machine component',

  obj  => $name,
  give => null;

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {

  # defaults
  $O{depth} //= 0x24;

  return $self->{cas}->prich(%O);

};

# ---   *   ---   *   ---
1; # ret
