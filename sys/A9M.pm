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
  use Chk;
  use Type;
  use Bpack;
  use Warnme;
  use Icebox;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::Int;
  use Arstd::PM;
  use Arstd::IO;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.5;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $COMPONENTS => [qw(
    flags mem ptr alloc anima stack ISA

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
  $O{mainid}  //= 0;
  $O{maincls} //= null;


  # find components through methods
  my $bk={ map {
    my $fn="get_${ARG}_bk";
    $ARG=>$class->$fn();

  } @$COMPONENTS };


  # make ice
  my $self={

    cas      => undef,
    astab    => {},
    astab_i  => [],

    mainid   => $O{mainid},

    scratch  => undef,
    alloc    => undef,
    scope    => undef,
    anima    => undef,
    stack    => undef,
    ISA      => undef,

    segtop   => undef,
    blktop   => undef,
    rp       => [],

    bk       => $bk,

    path     => [],
    pathsep  => $O{pathsep},


  };


  # replace existing?
  if($O{repl}) {
    %{$O{repl}}=%$self;
    $self=$O{repl};

  # ^give new!
  } else {
    $self=bless $self,$class;

  };


  # kick and give
  $self->reset($O{memroot});
  return $self;

};

# ---   *   ---   *   ---
# fetch reference to controller

sub get_main($self) {

  my $id    = $self->{mainid};
  my $class = $self->{maincls};

  return (defined $self->{mainid})
    ? $class->ice($id)
    : null
    ;

};

# ---   *   ---   *   ---
# kick all components

sub reset($self,$name) {


  # add to box
  my $class = ref $self;
  my $bk    = $self->{bk};

  my $frame = $class->get_frame();
  my $id    = $frame->icemake($self);


  # nit user memory
  $self->astab_push($name);

  # ^nit scratch buffer for internal use
  $self->{scratch}=$bk->{mem}->mkroot(

    mcid  => $id,
    label => 'SCRATCH',

    size  => 0x00,

  );


  # kick components in need of kicking!
  map {

    $self->{$ARG}=
      $bk->{$ARG}->new(mcid=>$id);

  } qw(anima stack alloc ISA);

  $self->scope($name);
  $self->{ISA}->ready_or_build;


  return;

};

# ---   *   ---   *   ---
# make new addressing space
# or add sub-segment to existing

sub astab_push($self,$src) {


  # make segment tree?
  my $mem=$self->{bk}->{mem};
  my ($label,$root);

  if(! $mem->is_valid($src)) {

    $label = $src;
    $root  = $mem->mkroot(

      mcid  => $self->{iced},
      mccls => (ref $self),

      label => $src,
      size  => 0x00,

    );


  # ^nope, a tree was passed!
  } else {

    $label = $src->{value};
    $root  = $src;

  };


  # ^make current and add to table
  $self->{cas}=$root;

  $self->{astab}->{$label}=$root;
  push @{$self->{astab_i}},$label;

  $self->setseg($root);


  return $root;

};

# ---   *   ---   *   ---
# ^flatten location!

sub astab_loc($self,$idex) {

  my $addr=0x00;

  while($idex) {

    my $label = $self->{astab_i}->[--$idex];
    my $root  = $self->{astab}->{$label};

    $addr=$root->absloc();

  };

  return $addr;

};

# ---   *   ---   *   ---
# merge segment trees

sub memflat($self) {


  # get base
  my $label = $self->{astab_i};
  my $first = shift @$label;

  my $root  = $self->{astab}->{$first};


  # ^join all
  $root->merge(
    map {$self->{astab}->{$ARG}} @$label

  );

  # discard and give
  $self->{astab_i} = [$first];
  $self->{astab}   = {$first => $root};

  $self->{cas}     = $root;

  return $root;

};

# ---   *   ---   *   ---
# ^find code from absloc

sub flatjmp($self,$ptrv) {

  # get ctx
  my $frame = $self->{cas}->{frame};
  my $anima = $self->{anima};
  my $rip   = $anima->{rip};

  # substract base from total
  my $base  = $frame->ice($rip->{chan});
     $ptrv -= $base->absloc();

  return $ptrv;

};

# ---   *   ---   *   ---
# ^find [segment=>offset] from
# absolute position

sub flatptr($self,$ptrv) {


  # fstate
  my $base = 0x00;
  my $off  = 0x00;
  my $seg  = undef;

  # walk segments
  my @Q=$self->{cas}->{root};
  while(@Q && $base <= $ptrv) {

    $seg  = shift @Q;
    $base = $seg->absloc();

    $off  = $ptrv-$base;


    # address fits in this block?
    last if($off >= 0 && $off < $seg->{size});

    # ^nope, keep going!
    unshift @Q,@{$seg->{leaves}};

  };


  return ($seg,$off);

};

# ---   *   ---   *   ---
# take snapshot of current state

sub backup($self) {

  my $image={
    path=>[@{$self->{path}}],

  };


  push @{$self->{rp}},$image;
  $self->{anima}->backup();

  return;

};

# ---   *   ---   *   ---
# ^undo

sub restore($self) {

  my $image=shift @{$self->{rp}};

  $self->{path}=$image->{path};
  $self->{anima}->restore();

  return;

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
# shorthand: namespace lookup

sub lkup($self,@path) {


  # get ctx
  my $mem  = $self->{cas};
  my $tree = $mem->{inner};


  # switch addressing space?
  my $rept=0;
  rept:


  # path root explicit?
  my $have_root=(
     $path[0]
  && $path[0] eq $tree->{value}

  );

  # path root repeated?
  my $daut_root=(
     ($path[0] && $path[1])
  && ($path[0] eq $path[1])

  );


  my $root=shift @path
  if $have_root or $daut_root;

  # find root/path/to within tree
  my $out=$tree->haslv(@path);


  # ^first fail will attempt a
  # cross-addressing space lookup
  #
  # else it's an actual fail ;>

  if(! $out &&! $rept) {
    my $alt=$self->{astab}->{$path[0]};


    # root in addressing space table means
    # retry with that new root!
    if($alt) {

      $mem  = $alt;
      $tree = $alt->{inner};

      $rept =1;

      goto rept;

    };

  };


  unshift @path,$root
  if $root &&! $daut_root;


  return ($out,$mem,$tree,@path);

};

# ---   *   ---   *   ---
# set/get current namespace

sub scope($self,@path) {

  # set new?
  if(@path) {


    # segment passed?
    my $mem_t=$self->{bk}->{mem};

    @path=($mem_t->is_valid($path[0]))
      ? $path[0]->ances_list
      : @path
      ;


    # validate path
    my ($out,$mem,$tree,@loc)=
      $self->lkup(@path);

    return badfet('DIR',@path)
    if ! $out;


    # ^overwrite
    $self->{path}  = [@loc];
    $self->{scope} = $out;

  };


  # ^give node if defined
  my $out=$self->{scope};
  return (defined $out) ? $out : null ;

};

# ---   *   ---   *   ---
# get node and path

sub get_node($self,@path) {


  # name in path?
  my ($out,$mem,$tree,@loc)=
    $self->lkup(@path);

  # ^nope, get more specific...
  if(! $out) {

    my @alt=(

      [@{$self->{path}},@path],

      ($self->{segtop})
        ? [$self->{segtop}->ances_list,@path]
        : ()
        ,

    );

    # ^retry!
    for my $subpath(@alt) {

      ($out,$mem,$tree,@loc)=
        $self->lkup(@$subpath);

      last if $out;

    };

  };


  return ($out)
    ? ($out,@loc)
    : ()
    ;

};


# ---   *   ---   *   ---
# ^get symbol and path

sub ssearch_p($self,@path) {
  my ($have,@loc)=$self->get_node(@path);
  return ($have)
    ? ($have->{mem},@loc)
    : ()
    ;

};

# ---   *   ---   *   ---
# ^just the symbol ;>

sub ssearch($self,@path) {
  my ($sym)=$self->ssearch_p(@path);
  return (defined $sym) ? $sym : null ;

};

# ---   *   ---   *   ---
# ^plus errme!

sub valid_ssearch($self,@path) {

  my $out=$self->ssearch(@path);

  return (length $out)
    ? $out
    : badfet('DIR',@path)
    ;

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


  # match path against addressing space
  my $out=null;
  ($out,$mem,$tree,@path)=
    $self->lkup(@path);


  # make (path,to) from (path::to)
  # then look in namespace
  return $mem->search($name,@path);

};

# ---   *   ---   *   ---
# search and deref

sub search($self,$name,@path) {

  # get ctx/solve path
  my $mem  = $self->{cas};
     @path = $self->_search($name,@path);

  # give name if found
  return $mem->{'*fetch'};

};

# ---   *   ---   *   ---
# ^plus errme

sub valid_search($self,$name,@path) {

  my $out=$self->search($name,@path);

  return ($out)
    ? $out
    : badfet($name,@path)
    ;

};

# ---   *   ---   *   ---
# search but no deref!

sub psearch($self,$name,@path) {

  # get ctx/solve path
  my $mem  = $self->{cas};
     @path = $self->_search($name,@path);

  # get *ptr* to value!
  return $mem->{inner}->get(@path);

};

# ---   *   ---   *   ---
# ^plus errme

sub valid_psearch($self,$name,@path) {

  my $out=$self->psearch($name,@path);

  return ($out)
    ? $out
    : badfet($name,@path)
    ;

};

# ---   *   ---   *   ---
# get symbol name from packed vref

sub vrefid($self,$src,$ch='_') {


  # get ctx
  my $mem=$self->{bk}->{mem};

  # unpack
  my @path = @{$src->{id}};
  my $name = shift @path;


  # get [fullname => symbol]
  my $full=join $ch,grep {
      length $ARG
  &&! ($ARG=~ $mem->anon_re)

  } map {
    split $self->{pathsep},$ARG

  } @path,$name;


  return ($name,$full,@path);

};

# ---   *   ---   *   ---
# ^actually fetch the symbol

sub vrefsym($self,$src,$ch='_') {


  # get id
  my ($name,$full,@path)=
    $self->vrefid($src,$ch);

  # ^fetch symbol by id
  my $sym=${$self->valid_psearch(
    $name,@path

  )};


  return ($sym,$name,$full,@path);

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
  my $ptr_t=undef;

  if(Type->is_ptr($type)) {

    my $ptrcls = $self->{bk}->{ptr};
       $ptr_t  = $type;

    $type=($ptrcls->is_valid($value))
      ? $value->{type}
      : $Type::DEFAULT
      ;

  };


  # make ice and give
  $mem->decl($type,$name,$value,ptr_t=>$ptr_t);

};

# ---   *   ---   *   ---
# set segment as current

sub setseg($self,$mem) {

  $self->scope($mem->ances_list);
  $self->{segtop}=$mem;

  return;

};

# ---   *   ---   *   ---
# ^make new

sub mkseg($self,$type,$name) {

  my $seg=$self->{cas}->new(0x00,$name);

  $seg->{writeable}  = int($type=~ qr{^ram$});
  $seg->{executable} = int($type=~ qr{^exe$});

  $self->setseg($seg);


  return $seg;

};

# ---   *   ---   *   ---
# load segment pointed to
# by fetch register

sub deref_chan($self) {

  my $anima = $self->{anima};
  my $chan  = $anima->{chan};

  my $frame = $self->{cas}->{frame};
  my $ptrv  = $chan->load();

  my ($seg) = $self->flatptr($ptrv);

  return $seg;

};

# ---   *   ---   *   ---
# unpacks [seg:sb-imm]

sub decode_mstk_ptr($self,$data) {


  my $stack = $self->{stack};

  my $seg   = $self->{stack}->{mem};
  my $base  = $stack->{base};
  my $off   = $data->{imm};

  %$data=(
    seg  => $seg,
    addr => sub {$base->load()-$off},

  );

  return;

};

# ---   *   ---   *   ---
# ^for translation!

sub xlate_mstk_ptr($self,$data) {


  # get ctx
  my $main  = $self->get_main();
  my $anima = $self->{anima};
  my $l1    = $main->{l1};


  # pack pointer data
  my $addr=[

    1,

    $l1->tag(REG=>$anima->stack_base),
    $l1->tag(NUM=>-$data->{imm}),

  ];


  # overwrite and give
  %$data=(
    type  => 'm',
    value => $addr,

  );

  return;

};

# ---   *   ---   *   ---
# unpacks [seg:imm]

sub decode_mimm_ptr($self,$data) {

  %$data=(
    seg  => $self->deref_chan(),
    addr => $data->{imm},

  );


  return;

};

# ---   *   ---   *   ---
# ^for translation!

sub xlate_mimm_ptr($self,$data) {


  # get ctx
  my $main  = $self->get_main();
  my $l1    = $main->{l1};


  # pack pointer data
  my $base = $self->deref_chan();
  my $addr = [

    1,

    $l1->tag(NUM=>$base->absloc),
    $l1->tag(NUM=>$data->{imm}),

  ];


  # overwrite and give
  %$data=(
    type  => 'm',
    value => $addr,

  );

  return;

};

# ---   *   ---   *   ---
# unpacks [seg:rX+imm]

sub decode_msum_ptr($self,$data) {

  my $base = $self->{anima}->fetch($data->{reg});
  my $off  = $data->{imm};


  %$data=(
    seg  => $self->deref_chan(),
    addr => sub {$base->load()+$off},

  );


  return;

};

# ---   *   ---   *   ---
# ^for translation!

sub xlate_msum_ptr($self,$data) {


  # get ctx
  my $main  = $self->get_main();
  my $l1    = $main->{l1};


  # pack pointer data
  my $off  = $self->deref_chan();
     $off  = $data->{imm} + $off->absloc;

  my $addr = [

    1,

    $l1->tag(REG=>$data->{reg}),
    $l1->tag(NUM=>$off),

  ];


  # overwrite and give
  %$data=(
    type  => 'm',
    value => $addr,

  );

  return;

};

# ---   *   ---   *   ---
# unpacks [seg:rX+rY+imm*scale]

sub decode_mlea_ptr($self,$data) {


  # load register values
  my @r=map {
    $self->{anima}->fetch($ARG-1)

  } grep {$ARG} (
    $data->{rX},
    $data->{rY}

  );


  # load plain values
  my $scale = 1 << $data->{scale};
  my $imm   = $data->{imm};
  my $seg   = $self->deref_chan();
  my $base  = $seg->absloc;

  my $addr  = undef;


  # apply scale to immediate?
  if($imm) {

    $addr=sub {

      my $out=$imm * $scale;
      map {$out+=$ARG->load()} @r;

      return $out-$base;

    };

  # ^second register?
  } elsif($r[1]) {

    $addr=sub {

      return (

        $r[0]->load()
      + $r[1]->load()
      * $scale

      ) - $base;

    };


  # ^first register?
  } else {

    $addr=sub {

      return (

        $r[0]->load()
      * $scale

      ) - $base;

    };

  };


  # overwrite and give
  %$data=(
    seg  => $seg,
    addr => $addr,

  );

  return;

};

# ---   *   ---   *   ---
# ^for translation!

sub xlate_mlea_ptr($self,$data) {


  # get ctx
  my $main  = $self->get_main();
  my $l1    = $main->{l1};


  # get registers
  my @r=map {
    $ARG-1

  } grep {$ARG} (
    $data->{rX},
    $data->{rY}

  );


  # pack pointer data
  my $addr=[

    1 << $data->{scale},


    (map {
      $l1->tag(REG=>$ARG),

    } @r),


    ($data->{imm})
      ? $l1->tag(NUM=>$data->{imm})
      : ()
      ,

  ];


  # overwrite and give
  %$data=(
    type  => 'm',
    value => $addr,

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
# encode to binary

sub mint($self) {


  # get base attrs
  my @out=map {
    $ARG=>$self->{$ARG}

  } qw(pathsep);


  # indirection
  my $key=$self->{astab_i}->[0];
  push @out,root=>$self->{astab}->{$key};

  return @out;

};

# ---   *   ---   *   ---
# ^undo

sub unmint($class,$O) {
  return bless $O,$class;

};

# ---   *   ---   *   ---
# ^cleanup kick

sub REBORN($self) {

  my $class=ref $self;

  $class->new(

    memroot => $self->{root},
    pathsep => $self->{pathsep},

    repl    => $self,

  );


  $self->{cas}->layer_restore($self);

  return;

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {

  # defaults
  $O{depth} //= 0x24;
  $O{root}  //= 1;
  $O{loc}   //= 1;

  return $self->{cas}->prich(%O);

};

# ---   *   ---   *   ---
1; # ret
