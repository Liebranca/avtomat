#!/usr/bin/perl
# ---   *   ---   *   ---
# FF
# File format
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package FF;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_words);

  use Scalar::Util qw(blessed);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;

  use FStruc;

  use Arstd::Array;
  use Arstd::String;
  use Arstd::IO;
  use Arstd::PM;

  use parent 'St';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(FF);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# GBL

 our $Table={};

# ---   *   ---   *   ---
# wraps FStruc::new
#
# * makes a new instance if
#   source is provided
#
# * else it tries to fetch
#   an existing one

sub FF($name,$src=undef) {


  # ever lookup something
  # then realize you're holding it?
  return $name
  if FStruc->is_valid($name);

  # fetch existing?
  return (exists $Table->{$name})
    ? $Table->{$name}
    : throw_invalid($name)

  if ! defined $src;


  # forbid redefinition
  return throw_redefn($name)
  if exists $Table->{$name};

  # ^forbid usage of base type names
  return Type::throw_redefn($name)
  if exists $Type::MAKE::Table->{$name};


  # parse input
  my @field=PESTRUC $src;

  # ^array as hash
  my $fi=0;
  my @fk=array_keys(\@field);
  my @fv=array_values(\@field);


  # ^walk
  my @cmd=map {

    # get descriptor
    my $name = $ARG;
    my $desc = $fv[$fi++];

    # ^unpack
    my $type = $desc->{type};
    my @cnt  = ($desc->{cnt} ne 1)
      ? $desc->{cnt}
      : ()
      ;


    # is type itself a file format?
    $type=$Table->{$type}
    if exists $Table->{$type};

    # make args for FStruc
    $name => [$type=>@cnt];


  } @fk;


  # ^save to table and give
  my $struc=FStruc->new(@cmd);

  $Table->{$name}  = $struc;
  $Table->{$struc} = $name;


  return $Table->{$name};

};

# ---   *   ---   *   ---
# ^errmes

sub throw_invalid($name) {

  errout q[invalid ff: '%s'],

  args => [$name],

  back => 0,
  lvl  => $AR_WARNING;


  return 0;

};

sub throw_redefn($name) {

  errout q[redefinition of ff '%s'],

  args => [$name],

  back => 0,
  lvl  => $AR_WARNING;


  return 0;

};

# ---   *   ---   *   ---
# cstruc

sub new($name,$args=undef) {


  # fetch format
  my $struc   = FF $name;
     $args  //= [];

  # make ice
  my $out=bless {
    -struc  => $struc,
    -labels => [],

  },__PACKAGE__;


  # ^fillout and give
  $out->set(@$args);
  return $out;

};

# ---   *   ---   *   ---
# assigns values to struc ice

sub asg($self,$mode,@args) {

  my $struc = $self->{-struc};

  my $name  = undef;
  my $elem  = undef;

  map {

    # end of currrent
    if($ARG eq null) {
      $name=undef;

    # ^beg of new
    } elsif(! defined $name) {

      $name    = $ARG;
      $elem    = \$self->{$name};

      $$elem //= [];
      $$elem   = [] if $mode eq 'set';

    # ^add values to current
    } else {

      # recurse for sub-struc?
      if(exists $struc->{substruc}->{$name}) {

        my $subs = $struc->{substruc}->{$name};
           $subs = $Table->{$subs};

        my $ice  = FF::new $subs=>$ARG;

        push @{$$elem},{$ice->nattrs()};


      # ^nope, plain array
      } else {
        push @{$$elem},$ARG;

      };

    };


  } grep {defined $ARG} @args;

  # fill out undefined/incomplete
  $self->{-struc}->complete($self);
  return;

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps(

  q[$self->asg]=>q[$self,@args],

  map {[$ARG=>"'$ARG',\@args"]}
  qw  (set cat)

);

# ---   *   ---   *   ---
# wraps for ice packing

sub pack($name,%O) {

  # defaults
  $O{at}   //= 0;
  $O{buf}  //= undef;
  $O{data} //= [];

  # have/need ice?
  my $self=(! blessed $name)
    ? new $name=>$O{data}
    : $name
    ;


  # get F to call
  my $fn   = (defined $O{buf})
    ? 'to_strm'
    : 'to_bytes'
    ;

  my @args = ($fn eq 'to_strm')
    ? ($O{buf},$O{at},%$self)
    : (%$self)
    ;


  # return peso pack
  return $self->{-struc}->$fn(@args);

};

# ---   *   ---   *   ---
# ^undo

sub unpack($name,$sref,%O) {

  # defaults
  $O{csume} //= 0;
  $O{label} //= 0;
  $O{at}    //= 0;

  # have/need ice?
  my $self=(! blessed $name)
    ? new $name=>[]
    : $name
    ;


  # make copy of source?
  my $src=$sref;

  if($O{csume}) {
    my $cpy = $$sref;
       $src = $cpy;

  };


  # get F to call
  my $fn=($O{csume} || $O{at})
    ? 'from_strm'
    : 'from_bytes'
    ;

  my @args=($fn eq 'from_strm')
    ? ($sref,$O{at})
    : ($src)
    ;


  # peso unpack
  my $struc = $self->{-struc};
  my $b     = $struc->$fn(@args);


  # make labels array?
  $self->{-labels}=[$struc->labels($b)]
  if $O{label};

  # copy results to ice
  my $data  = $struc->flatten($b);

  map  {$self->{$ARG}=$data->{$ARG}}
  keys %$data;


  return $self;


};

# ---   *   ---   *   ---
# TODO:
#
# * file R/W

# ---   *   ---   *   ---
1; # ret

