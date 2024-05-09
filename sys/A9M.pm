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
  use Arstd::IO;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.3;#a
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


  # find components through methods
  my $bk={ map {
    my $fn="get_${ARG}_bk";
    $ARG=>$class->$fn();

  } @$COMPONENTS };


  # make ice
  my $self=bless {

    cas      => undef,
    astab    => {},

    scratch  => undef,
    alloc    => undef,
    scope    => undef,
    anima    => undef,
    stack    => undef,
    ISA      => undef,

    segtop   => undef,

    bk       => $bk,

    path     => [],
    pathsep  => $O{pathsep},


  },$class;


  # ^add to box
  my $frame = $class->get_frame();
  my $id    = $frame->icemake($self);


  # nit user memory
  $self->{cas}=$bk->{mem}->mkroot(
    mcid  => $id,
    label => $O{memroot},

  );

  $self->{astab}->{$O{memroot}}=
    $self->{cas};


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

  $self->scope($O{memroot});
  $self->{ISA}->ready_or_build;


  return $self;

};

# ---   *   ---   *   ---
# take snapshot of current state

sub backup($self) {

  $self->{anima}->backup();
  return;

};

# ---   *   ---   *   ---
# ^undo

sub restore($self) {

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


  # path root implicit
  shift @path
  if $path[0] && $path[0] eq $tree->{value};

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


  return ($out,$mem,$tree,@path);

};

# ---   *   ---   *   ---
# set/get current namespace

sub scope($self,@path) {


  # set new?
  if(@path) {


    # validate path
    my ($out,$mem,$tree)=
      $self->lkup(@path);

    return badfet('DIR',@path)
    if ! $out;


    # ^overwrite
    $self->{path}  = [$tree->{value},@path];
    $self->{scope} = $out;

  };


  # ^give node if defined
  my $out=$self->{scope};
  return (defined $out) ? $out : null ;

};

# ---   *   ---   *   ---
# find symbol

sub ssearch($self,@path) {


  # name in path?
  my ($out,$mem,$tree)=
    $self->lkup(@path);


  # ^nope, get more specific...
  if(! $out) {

    my @alt=(

      [@{$self->{path}},@path],

      ($self->{segtop})
        ? [$self->{segtop}->ances_list(),@path]
        : ()
        ,

    );

    # ^retry!
    for my $subpath(@alt) {

      ($out,$mem,$tree)=
        $self->lkup(@$subpath);

      last if $out;

    };

  };

  return ($out) ? $out->{mem} : null ;

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
  my $seg   = $frame->ice($chan->load());

  return $seg;

};

# ---   *   ---   *   ---
# unpacks [seg:sb-imm]

sub decode_mstk_ptr($self,$o) {


  my $stack = $self->{stack};

  my $seg   = $self->{stack}->{mem};
  my $base  = $stack->{base};
  my $off   = $o->{imm};

  %$o=(
    seg  => $seg,
    addr => sub {$base->load()-$off},

  );

  return;

};

# ---   *   ---   *   ---
# unpacks [seg:imm]

sub decode_mimm_ptr($self,$o) {

  %$o=(
    seg  => $self->deref_chan(),
    addr => $o->{imm},

  );


  return;

};

# ---   *   ---   *   ---
# unpacks [seg:rX+imm]

sub decode_msum_ptr($self,$o) {

  my $base = $self->{anima}->fetch($o->{reg});
  my $off  = $o->{imm};


  %$o=(
    seg  => $self->deref_chan(),
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
  my $seg   = $self->deref_chan();

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
