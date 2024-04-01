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

  our $VERSION = v0.01.1;#a
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
    segtop   => undef,
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
  $self->{ISA}->ready_or_build;

  return $self;

};

# ---   *   ---   *   ---
# get current path without root

sub path($self) {

  my $mem  = $self->{cas};
  my $tree = $mem->{inner};
  my $path = $self->{path};

  shift @$path
  if $path->[0] eq $tree->{value};


  return $path;

};

# ---   *   ---   *   ---
# set/get current namespace

sub scope($self,@path) {


  # set new?
  if(@path) {

    # get ctx
    my $mem  = $self->{cas};
    my $tree = $mem->{inner};

    shift @path
    if $path[0] && $path[0] eq $tree->{value};


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
# find segment

sub ssearch($self,@path) {

  # get ctx
  my $mem  = $self->{cas};
  my $tree = $mem->{inner};

  shift @path if $path[0] eq $tree->{value};


  # validate input
  my $out=$tree->haslv(@path)
  or return badfet('DIR',@path);


  return $out->{mem};

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

  shift @path if $path[0]
  && $path[0] eq $tree->{value};


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

  if($ptr_t) {

    my $ptrcls=$self->{bk}->{ptr};

    $type=($ptrcls->is_valid($value))
      ? $value->{type}
      : $Type::DEFAULT
      ;

  } else {
    $ptr_t=undef;

  };


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
# set segment as current

sub setseg($self,$mem) {

  $self->segid($mem);
  $self->scope($mem->ances_list);

  $self->{segtop}=$mem;

  return;

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
  my $base = $self->{anima}->fetch(0xB);
  my $off  = $o->{imm};

  %$o=(
    seg  => $seg,
    addr => sub {$base->load-$off},

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
  my $base = $self->{anima}->fetch($o->{reg});

  my $off  = $o->{imm};


  %$o=(
    seg  => $seg,
    addr => sub {$base->load+$off},

  );


  return;

};

# ---   *   ---   *   ---
# unpacks [seg:rX+rY+imm*scale]

sub decode_mlea_ptr($self,$o) {


  # load register values
  my @r=map {
    $self->{anima}->fetch($ARG-1)

  } grep {$ARG} ($o->{rX},$o->{rY});


  # load plain values
  my $scale = 1 << $o->{scale};
  my $imm   = $o->{imm};
  my $seg   = $self->{segtab}->[$o->{seg}];

  my $addr  = undef;

  # apply scale to immediate?
  if($imm) {

    $addr=sub {
      my $out=$imm * $scale;
      map {$out+=$ARG->load} @r;

    };

  # ^second register?
  } elsif($r[1]) {

    $addr=sub {
        $r[0]->load
      + $r[1]->load
      * $scale

    };

  # ^first register?
  } else {
    $addr=sub {$r[0]->load * $scale};

  };


  # collapse and give
  %$o=(
    seg  => $seg,
    addr => $addr,

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
