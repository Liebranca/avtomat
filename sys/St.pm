#!/usr/bin/perl
# ---   *   ---   *   ---
# ST
# Fundamental structures
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package St;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use Readonly;
  use English qw(-no_match_vars);

  use Scalar::Util qw(blessed reftype);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Frame;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.02.6;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {{}};

# ---   *   ---   *   ---
# GBL

  our $Frames  = {};
  our $Classes = {};

# ---   *   ---   *   ---
# is obj instance of class

sub is_valid($kind,$obj) {

  return
     defined blessed($obj)
  && int $obj->isa($kind)

  ;

};

# ---   *   ---   *   ---
# ^same, but in the strict sense!
#
# obj must be *exactly*
# an ice of type -- derived
# classes won' pass this test

sub is_iceof($kind,$obj) {

  return
     $kind->is_valid($obj)
  && $kind eq ref $obj
  ;

};

# ---   *   ---   *   ---
# what clas obj is an instance of

sub get_class($obj) {return ref $obj};

# ---   *   ---   *   ---
# initialize struct elements
# to default values

sub defnit($class,$href) {

  no strict 'refs';

    my $defs=${"$class\::DEFAULTS"};

    for my $key(keys %$defs) {
      $href->{$key} //= $defs->{$key};

    };

  use strict 'refs';

};

# ---   *   ---   *   ---
# fetch class attribute
# mostly for internal use!

sub classattr($class,$name) {

  my $A    = \$Classes->{$class};
     $$A //= {};

  my $B    = \$$A->{$name};
     $$B //= [];


  return $$B;

};

# ---   *   ---   *   ---
# allows other packages to
# inject their own kicks and nits
# into St methods

sub inject($name,$fn,@dst) {

  # who's calling?
  my $src=caller;
  my $dst=$dst[0];

  # who's getting called? ;>
  $name=~ s[^\*][St::];
  $name=~ s[^\~][$dst\::];


  # ^add F to class->name
  my $attr=classattr $dst,$name;
  push @$attr,$fn;


  return;

};

# ---   *   ---   *   ---
# ^does the deed!

sub injector($class,@args) {

  my $here = (caller(1))[3];
  my $attr = classattr $class,$here;

  map {$ARG->($class,@args)} @$attr;

};

# ---   *   ---   *   ---
# define/overwrite virtual constants

sub vconst($data) {


  # whomever calls, store here
  state $ROMTAB = {};
  my    $class  = caller;


  # walk input
  map {

    # array as hash
    my $key   = $ARG;
    my $value = $data->{$key};


    # save to table/make method
    no strict 'refs';

    *{"$class\::$key"}=sub ($cls) {

      # get ref to table
      $ROMTAB->{$cls} //= {};
      my $tab=$ROMTAB->{$cls};

      # have cached?
      return $tab->{$key}
      if exists $tab->{$key};


      # ^else rebuild and give
      $tab->{$key}=(is_coderef($value))
        ? $value->($cls)
        : $value
        ;

      $tab->{$key};

    };


  } keys %$data;


  return;

};

# ---   *   ---   *   ---
# ^decls frame vars
# pure sugar

sub vstatic($O={}) {

  # defaults
  $O->{-autoload} //= [];

  # get ctx
  my $class = caller;
  my $name  = 'Frame_Vars';


  # run injected methods
  injector $class,$O;

  # write method fetching hash
  no strict 'refs';
  *{"$class\::$name"}=sub ($class) {$O};


  return;

};

# ---   *   ---   *   ---
# return default frame
# for class or instance
#
# always assumed to be at the top
# of the global state hierarchy

sub get_gframe($class) {

  if(length ref $class) {
    my $self = $class;
    $class   = $self->get_class();

  };

  return $class->get_frame(0);

};

# ---   *   ---   *   ---
# make instance container

sub new_frame($class,%O) {

  # general defaults
  $O{-owner_kls}  //= (caller)[0];
  $O{-force_idex} //= 0;
  $O{-prev_owners}  = [];

  # ^fetch class-specific defaults!
  my $vars=$class->Frame_Vars();
  map {$O{$ARG}//=$vars->{$ARG}} keys %$vars;

  # ^assign owner class
  $O{-class}=$class;

  # ensure we have an icebox ;>
  $Frames->{$class}//=[];
  my $icebox=$Frames->{$class};


  # remember requested idex
  my $idex=$O{-force_idex};
  delete $O{-force_idex};

  # ^make ice
  my $frame=Frame->_new(%O);

  # no idex asked for?
  if($idex) {

    my $i    = 0;
       $idex = undef;

    # get first undefined slot
    map {
      $idex //= $i
      if ! $icebox->[$i++]

    } @$icebox;

    # ^top of array if none avail!
    $idex //= $i;

  };


  # save ice and give
  $Frames->{$class}->[$idex]=$frame;

  return $frame;

};

# ---   *   ---   *   ---
# ^get existing or make new

sub get_frame($class,$i=0) {

  my $out;

  if(! exists $Frames->{$class}) {

    $out=$class->new_frame(
      -owner_kls=>(caller)[0]

    );

  } else {
    $out=$Frames->{$class}->[$i];

  };

  return $out;

};

# ---   *   ---   *   ---
# ^get idex of existing

sub iof_frame($class,$frame) {

  my $ar=$Frames->{$class}
  or croak "No frames avail for $class";

  my ($idex)=grep {
    $ar->[$ARG] eq $frame

  } 0..int(@$ar)-1;

  return $idex;

};

# ---   *   ---   *   ---
# ^get list of existing

sub get_frame_list($class) {
  return @{$Frames->{$class}};

};

# ---   *   ---   *   ---
# get attrs that don't begin
# with a dash

sub nattrs($self) {
  map  {  $ARG  => $self->{$ARG}}
  grep {! ($ARG =~ qr{^\-})} keys %$self;

};

# ---   *   ---   *   ---
# overwrite this method for
# a more specific dstruc

sub DESTROY($self) {

  my $class=ref $self;
  injector $class,$self;


  return;

};

# ---   *   ---   *   ---
# overwrite this method to
# get a string repr for dbout!

sub prich($self,%O) {return "$self"};

# ---   *   ---   *   ---
1; # ret
