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
  use Fmat;

  use parent 'St';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(image mount);

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.2;#a
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  # expr for fetching reference type
  ref_t => qr{^

    [^=]* (?: \=?
      (HASH|ARRAY|CODE)

    )

  }x,

  # expr for spotting frozen coderefs
  sub_re => qr{^(\\&|\\X)},

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

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# consume value from Q

sub get_next($self) {


  # get ctx
  my $Q      = $self->{Q};
  my $walked = $self->{walked};

  return undef if ! int @$Q;


  # skip repeated
  rept: my $vref = shift @$Q;

  goto rept if ! defined $vref
            ||   exists  $walked->{$vref};


  # ^add first to table and give
  $walked->{$vref}=1;

  return $vref;

};

# ---   *   ---   *   ---
# ^inspect value
#
# if it contains other values,
# expand it and pass them through an F
#
# returns the processed values!

sub vex($self) {


  # find or stop
  my $vref=$self->get_next();
  return () if ! defined $vref;


  # get ctx
  my $walked = $self->{walked};
  my $fn     = $self->{fn};
  my $args   = $self->{args};


  # get reference type
  my @have   = ();
  my $refn   = ref $vref;

  my ($type) = $vref =~ $self->ref_t;

  return () if ! defined $type;


  # have hash?
  if($type eq 'HASH') {


    # apply F to each value
    # then give result
    @have=map  {

      $vref->{$ARG}=$fn->(
        $self,$vref->{$ARG},@$args

      );

      $vref->{$ARG};


    # ^filter out null and repeats
    } grep {
        defined $vref->{$ARG}
    &&! exists  $walked->{$vref->{$ARG}}

    } keys %$vref;


  # have array? same logic ;>
  } elsif($type eq 'ARRAY') {

    @have=map {

      $vref->[$ARG]=$fn->(
        $self,$vref->[$ARG],@$args

      );

      $vref->[$ARG];

    } grep {
        defined $vref->[$ARG]
    &&! exists  $walked->{$vref->[$ARG]}

    } 0..@$vref-1;

  };


  return grep {defined $ARG} @have;

};

# ---   *   ---   *   ---
# apply F to nested structure

sub proc($self) {

  # reset ctx
  $self->{Q}      = [$self->{obj}];
  $self->{walked} = {};

  # walk structure
  my $Q=$self->{Q};
  while(@$Q) {push @$Q,$self->vex};

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
