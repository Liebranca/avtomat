#!/usr/bin/perl
# ---   *   ---   *   ---
# MINT
# Makes coins ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mint;

  use v5.36.0;
  use strict;
  use warnings;

  use Storable qw(store retrieve file_magic);
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Cask;
  use Fmat;

  use Arstd::Array;

  use parent 'St';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(image mount);

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.3;#a
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  # expr for fetching *expandable* reference type
  ref_t   => qr{^[^=]* (?: \=? (HASH|ARRAY))}x,

  # expr for spotting frozen coderefs
  sub_re  => qr{^(\\&|\\X)},

  # sequence terminator dummy
  EOS => sub {St::cpkg . '-EOS'},

};

# ---   *   ---   *   ---
# get type of value passed

sub get_input($src) {

  return (

     is_filepath($src)
  && file_magic($src)

  ) ? (1,retrieve $src) : (0,$src) ;

};

# ---   *   ---   *   ---
# fetch or generate store F

sub set_storing($user_fn) {

  if(defined $user_fn) {

    return sub(@args) {

      $args[1]=defstore(@args[0..1]);
      $args[1]=$user_fn->(@args);

      return $args[1];

    };

  } else {
    return \&defstore;

  };

};

# ---   *   ---   *   ---
# ^same for load

sub set_loading($user_fn) {

  if(defined $user_fn) {

    return sub(@args) {

      $args[1]=$user_fn->(@args);
      $args[1]=defload(@args[0..1]);

      return $args[1];

    };

  } else {
    return \&defload;

  };

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$src,%O) {


  # defaults
  $O{fn}      //= [];
  $O{args}    //= [];


  # passed value is object or path?
  my ($mode,$obj)=get_input $src;

  # ^set F to use accordingly
  my $user_fn = $O{fn}->[$mode];
  my $fn      = ($mode)
    ? set_loading $user_fn
    : set_storing $user_fn
    ;


  # make ice
  my $self=bless {

    walked => {},
    Q      => [],

    fn     => $fn,
    args   => $O{args},

    obj    => $obj,
    mode   => ($mode) ? 'unmint' : 'mint' ,

    head   => undef,
    path   => [],
    out    => {},

    hist   => [],
    data   => undef,

    uid    => 0,

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# decide if value must be expanded

sub register($self,$key,$vref) {


  # get value present in cache
  my $data         = $self->{data};
  my ($have,$idex) = $data->cgive($vref);

  # add descriptor to history
  my $path=$self->{path};
  push @$path,$key;

  my $out={

    type => $self->get_type($vref),

    path => [@$path],
    idex => $idex,

    vref => $vref,

  };

  push @{$self->{hist}},$out;


  # inform caller if we have a new value!
  return (! $have) ? $out : undef ;

};

# ---   *   ---   *   ---
# consume value from Q

sub get_next($self) {

  # get ctx
  my $Q=$self->{Q};

  # consume until value found
  my ($vref,$key);

  ($key,$vref)=(shift @$Q,shift @$Q)
  while @$Q >= 2 &&! defined $vref;

  # give non-null if expansion required
  return $self->register($key=>$vref);

};

# ---   *   ---   *   ---
# obtain encoding data about
# this value

sub get_type($self,$vref) {


  # get ctx
  my $mode   = $self->{mode};
  my $refn   = ref $vref;

  my ($type) = $vref =~ $self->ref_t;


  # reference can encode itself?
  my $blessed = is_blessref $vref;
  my $novex   = (
      ($blessed && $refn->can($mode))
  ||! defined $type

  );


  # ^inform caller!
  return ($novex) ? $refn : $type ;

};

# ---   *   ---   *   ---
# inspect value
#
# if it contains other values,
# expand it and pass them through an F
#
# returns the processed values!

sub proc_elem($self) {


  # find or stop
  my $head=$self->get_next();
  return $self->EOS if ! defined $head;


  # get ctx
  my $mode = $self->{mode};
  my $type = $head->{type};

  $self->{head} = $head;


  # have minting method?
  my @have=(length $type && $type->can($mode))
    ? $head->{vref}->$mode($self)
    : $self->vex()
    ;


  # give recurse path plus end marker
  return @have,$self->EOS;

};

# ---   *   ---   *   ---
# apply F to each value
# then give result

sub vex($self) {


  # get ctx
  my $head = $self->{head};
  my $data = $self->{data};
  my $vref = $head->{vref};
  my $fn   = $self->{fn};
  my $args = $self->{args};

  # map array to hash?
  my $type = $head->{type};
  my $src  = ($type eq 'ARRAY')
    ? array_key_idex $vref,1
    : $vref
    ;


  # skip if value needs no expansion!
  return ()

  if (! is_hashref $src)
  && (defined $type && $type ne 'HASH');


  # walk struc and give
  my @have=map {


    # filter out null and repeats
    my $defd=defined $src->{$ARG};
    my $have=($defd)
      ? $data->view($src->{$ARG})
      : undef
      ;

    # apply F to new && non-null
    my $value=($defd &&! defined $have)
      ? $fn->($self,$src->{$ARG},@$args)
      : $have
      ;

    $ARG=>$value;

  } keys %$src;

  return @have;

};

# ---   *   ---   *   ---
# apply F to nested structure

sub proc($self) {


  # reset ctx
  $self->{Q}    = [null=>$self->{obj}];
  $self->{data} = Cask->new();

  $self->{path} = [];
  $self->{hist} = [];

  # ^shorthands
  my $Q    = $self->{Q};
  my $path = $self->{path};


  # walk
  while(@$Q) {


    # handle path change
    if($Q->[0] && $Q->[0] eq $self->EOS) {

      pop   @$path;
      shift @$Q;

      next;

    };


    # expand next element
    unshift @$Q,$self->proc_elem;

  };

  use Fmat;
  fatdump \$self->{hist};

  say 'STOP';
  exit;

  return $self->{obj};

};

# ---   *   ---   *   ---
# applies processing to object
# before storing it

sub image($path,$obj,%O) {

  my $class = St::cpkg;
  my $self  = $class->new($obj,%O);

  store  $self->proc(),$path;
  return $path;

};

# ---   *   ---   *   ---
# ^undo

sub mount($path,%O) {

  my $class = St::cpkg;
  my $self  = $class->new($path,%O);

  return $self->proc();

};

# ---   *   ---   *   ---
# default methods for load/store
#
# if you define your own methods,
# these will still be applied to
# ensure all values can be stored!

sub defstore($self,$vref) {

  return (is_coderef $vref)
    ? codefreeze($vref)
    : $vref
    ;

};

sub defload($self,$vref) {

  my $re=$self->sub_re;
  return (defined $vref && $vref=~ s[$re][])
    ? codethaw($vref,$1)
    : $vref
    ;

};

# ---   *   ---   *   ---
# freeze code references in
# object to store it
#
# * named coderef to name
# * anon to source

sub codefreeze($fn) {

  my $name='\&' . codename $fn,1;

  return ($name=~ qr{__ANON__$})

    ? '\X' . $name . '$;'
    . $St::Deparse->coderef2text($fn)

    : $name
    ;

};

# ---   *   ---   *   ---
# ^undo

sub codethaw($fn,$type) {

  if($type eq '\&') {
    return \&$fn;

  } else {

    my ($name,$body)=split '\$;',$fn;
    my $wf=eval "sub $body";

    if(! defined $wf) {

      say "BAD CODEREF\n\n","sub $name $body";
      exit -1;

    };

    return $wf;

  };

};

# ---   *   ---   *   ---
1; # ret
