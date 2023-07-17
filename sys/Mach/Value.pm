#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH VALUE
# A thing stored somewhere
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach::Value;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::IO;

  use lib $ENV{'ARPATH'}.'/lib/';
  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $STR_ATTRS=>{

    ipol  => 0,
    len   => 0,

    width => 'byte',

  };

  Readonly our $FLG_ATTRS=>{

    q[flg-type] => 'bare',
    q[flg-name] => $NULLSTR,

    sigil       => '-',

  };

  Readonly our $RE_ATTRS=>{

    seal  => $NULLSTR,
    flags => {},

  };

  Readonly our $VOKE_ATTRS=>{
    depth=>0,

  };

  Readonly our $OPS_ATTRS=>{

    fn    => $NOOP,

    unary => 0,
    slurp => 0,
    ctx   => 0,

    prio  => 0,

    V     => [],

  };

  Readonly our $ITER_ATTRS=>{

    src  => undef,
    i    => 0,

  };

# ---   *   ---   *   ---
# GBL

  my $Attrs={

    str  => $STR_ATTRS,
    re   => $RE_ATTRS,

    voke => $VOKE_ATTRS,
    ops  => $OPS_ATTRS,
    iter => $ITER_ATTRS,

  };

# ---   *   ---   *   ---
# ^fetch

sub getattrs($class,$spec) {

  my %out=(exists $Attrs->{$spec})
    ? %{$Attrs->{$spec}}
    : ()
    ;

  return %out;

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$type,$id,%O) {

  # defaults
  $O{spec}  //= [];
  $O{raw}   //= $NULL;
  $O{const} //= 1;

  # pop args
  my $spec  = $O{spec};
  my $raw   = $O{raw};
  my $const = $O{const};

  delete $O{raw};
  delete $O{const};
  delete $O{spec};

  # unpack type
  my %attrs = map {
    $class->getattrs($ARG)

  } ($type,@$spec);

  # ^set attrs
  map {$attrs{$ARG}=$O{$ARG}} keys %O;

  # make ice
  my $self=bless {

    id    => $id,

    scope => undef,
    path  => undef,

    type  => $type,
    spec  => $spec,

    raw   => $raw,
    const => $const,

    %attrs,

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# remove type attrs

sub type_pop($self,@types) {

  # make pattern for removed types
  my $re=Lang::eiths(\@types,bwrap=>1);

  # mask non-popped types
  my @full = ($self->{type},@{$self->{spec}});
     @full = grep {! ($ARG=~ $re)} @full;

  my %rem  = map {$ARG=>1} @full;

  # ^get list of attrs to keep/remove
  my $class = ref $self;
  my %keep  = map {$class->getattrs($ARG)} @full;
  my %attrs = map {$class->getattrs($ARG)} @types;

  # ^filter
  my @keys=grep {
    ! exists $keep{$ARG}

  } keys %attrs;

  # ^remove non-keeped attrs
  map {delete $self->{$ARG}} @keys;

  # ^change type fields for filtered
  $self->{type}=pop @full;
  $self->{spec}=\@full;

};

# ---   *   ---   *   ---
# give copy of existing

sub dup($self,%attrs) {

  my $o     = {%$self,%attrs};
  my $class = ref $self;

  my $id    = $o->{id};
  my $type  = $o->{type};

  delete $o->{id};
  delete $o->{type};

  return $class->new($type,$id,%$o);

};

# ---   *   ---   *   ---
# ^save value to scope

sub bind($self,$scope,@path) {

  errout(

    q[Attempted binding of ]
  . q[annonymous value],

    lvl => $AR_FATAL

  ) if ! length $self->{id};

  @path=$scope->path() if ! @path;

  # remove previous, then set
  $self->unbind() if $self->{scope};
  my $ptr=$scope->decl($self,@path,$self->{id});

  $self->{scope} = $scope;
  $self->{path}  = [@path,$self->{id}];

  return $ptr;

};

# ---   *   ---   *   ---
# ^remove

sub unbind($self) {

  errout(

    q[Attempted unbind of ]
  . q[annonymous value],

    lvl => $AR_FATAL

  ) if ! length $self->{id};

  $self->{scope}->rm(@{$self->{path}});

  $self->{scope} = undef;
  $self->{path}  = [];

};

# ---   *   ---   *   ---
# recursive $self->{raw}

sub deref($self,$lvl=-1) {

  my $out   = undef;

  my $src   = $self;
  my $class = ref $src;

  while($lvl != 0 && $class->is_valid($src)) {
    $out=$src=$src->{raw};
    $lvl--;

  };

  return $out;

};

# ---   *   ---   *   ---
