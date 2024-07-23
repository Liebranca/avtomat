#!/usr/bin/perl
# ---   *   ---   *   ---
# IPRET:BINDER
# Oh, the blood that binds us...
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::binder;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::PM;
  use Arstd::WLog;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  subpkg=>[qw(
    ipret::binder::asm

  )],

  hier=>[CMD=>'proc'],

};

# ---   *   ---   *   ---
# imports sub-packages

sub new($class) {
  cloadi @{$class->subpkg};
  my $self=bless {},$class;

  return $self;

};

# ---   *   ---   *   ---
# ^retrive method

sub fetch($self,$name) {


  # result cached?
  return $self->{$name}
  if exists $self->{$name};


  # if F is found with this path,
  # then use that as-is
  my $class = ref $self;
  my $fn    = \&$name;

  # ^else lookup sub-packages!
  if(! defined &$fn) {

    for my $pkg($class,@{$self->subpkg}) {

      $fn="$pkg\::$name";
      $fn=\&$fn;

      last if defined &$fn;

    };

  };


  # ^validate
  $WLog->err(

    "could not find method [errtag]:%s",

    args => [$name],

    from => $class,
    lvl  => $AR_FATAL,

  ) if ! defined &$fn;


  # cache and give
  $self->{$name}=$fn;
  return $fn;

};

# ---   *   ---   *   ---
# applies common checks to block

sub inspect($self,$hier,$recalc=0) {


  # get ctx
  my $mc   = $hier->getmc();
  my $hist = $hier->sort_hist($recalc);


  # walk block elements
  my $i       = 0;
  my $var     = {};

  my @program = map {


    # unpack
    my $point=$ARG;

    my ($branch,$seg,$route,@req)=@{
      $point->{'asm-Q'}

    };


    # analyze instructions
    map {

      $self->chkins(

        $hier,
        $point,

        $ARG,
        $var,

        $i++,

      )

    } @req;


  } @$hist;


  # sort vars
  $hier->endtime($i-1);
  $hier->set_scope();

  map {

    my $dst=$var->{$ARG};

    $dst->{ptr}=$mc->search($ARG)
    if $dst->{loaded} ne 'const';


  } $hier->varkeys(io=>'all');


  # ~~
  map {

    my ($point,$opsz,$ins,$dst,$src)=@$ARG;


    # value required by op?
    if(
        $point->{load_dst}
    &&! $dst->{loaded}

    ) {

      $hier->load($dst);

    };


    say "$ins ",join ',',
      map  {$ARG->{name}}
      grep {defined $ARG} $dst,$src;


  } @program;


  use Fmat;
  fatdump \$var;
  exit;
  return;

};

# ---   *   ---   *   ---
# analyze point in timeline
# from instructions executed

sub chkins($self,$hier,$point,$data,$var,$i) {


  # instructions without arguments
  # are all special cased
  my ($opsz,$ins,@args)=@$data;
  return $self->on_argless(

    $hier,
    $point,
    $ins,

    $i


  ) if ! @args;


  # get operands
  my $dst=$self->get_dst(

    $hier,
    $point,
    $args[0],

    $i

  );

  my $src=$self->get_src(

    $hier,
    $point,
    $dst,
    $args[1],

    $i

  );


  # write back to caller
  my $argcnt=length $src->{name};

  $var->{$dst->{name}}=$dst;
  $var->{$src->{name}}=$src if $argcnt;


  # give synthesis
  return [

    $point,

    $opsz,
    $ins,

    ($argcnt)
      ? ($dst,$src)
      : ($dst)
      ,

  ];

};

# ---   *   ---   *   ---
# TODO: handle argless instructions

sub on_argless($self,$hier,$point,$ins,$i) {};

# ---   *   ---   *   ---
# fetch/make note of destination operand

sub get_dst($self,$hier,$point,$dst,$i) {

  my $var  = $point->{var};
  my $name = $hier->vname($dst);

  push @$var,$name;
  return $hier->chkvar($name,$i);

};

# ---   *   ---   *   ---
# ^source operand

sub get_src($self,$hier,$point,$dst,$src,$i) {

  my $out={name=>null};

  if($src && $point->{overwrite}) {

    my $name = $hier->vname($src);
       $out  = $hier->depvar($dst,$name,$i);

  };


  return $out;

};

# ---   *   ---   *   ---
# edge case: linux syscalls!

sub linux_syscall($self,$hier,$branch,$i) {

  my $pass = $branch->{vref}->{data};
  my $j    = @$pass-1;

  map {

    $hier->depvar(
      $hier->vname(0x00),
      $hier->vname($ARG),

      $i-$j--,

    );

  } @$pass;


  return;

};

# ---   *   ---   *   ---
1; # ret
