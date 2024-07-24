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

  our $VERSION = v0.00.5;#a
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

    my $point = $ARG;

    map {

      $self->chkins(

        $hier,
        $point,

        $ARG,
        $var,

        $i++,

      )

    } @{$point->{Q}};


  } @$hist;


  # sort vars
  $hier->set_scope();

  map {

    my $dst=$var->{$ARG};

    $dst->{ptr}=$mc->search($ARG)
    if $dst->{loaded} ne 'const';


  } $hier->varkeys(io=>'all');


  # ~~
  my $prev = undef;
     $i    = 0;

  map {


    # unpack
    my ($point,$opsz,$ins,$dst,$src)=@$ARG;
    $i=0 if $prev && $point ne $prev;

    my $Q   = $point->{Q};
    my $ref = $Q->[$i];


    # value required by op?
    if(! $dst->{loaded}) {


      # need intermediate assignment?
      if($point->{load_dst}->[$i]) {


        # generate instructions and add
        # them to the assembly queue
        my @have=$hier->load($dst);

        @$Q=(
          @{$Q}[0..$i-1],
          @have,
          @{$Q}[$i..@$Q-1],

        );


        # ^move to end of generated
        $i   += int @have;
        $ref  = $Q->[$i];


      # ^nope!
      } else {
        $hier->load($dst);

      };


    };


    # replace value in instruction operands
    my $j=0;

    map {

      if(defined $ARG && defined $ARG->{loc}) {

        $ref->[2+$j]={
          type => 'r',
          reg  => $ARG->{loc}

        };

        # overwrite operation size?
        if($ARG->{ptr}) {


          # compare sizes
          my $old  = $ref->[0];
          my $new  = $ARG->{ptr}->{type};

          my $sign = (
            $old->{sizeof}
          < $new->{sizeof}

          );


          # do IF dst is smaller
          #    OR src is bigger

          $ref->[0]=$new

          if (! $j &&! $sign)
          || (  $j &&  $sign);

        };

      };

      $j++;

    } $dst,$src;


    # go next
    $prev=$point;
    $i++;


  } @program;


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


  # get ctx
  my $mc   = $hier->getmc();
  my $ISA  = $mc->{ISA};

  my $meta = $ISA->_get_ins_meta($ins);


  # get operands
  my $dst=$self->get_dst(

    $hier,
    $point,
    $args[0],

    $i

  );

  my $src=$self->get_src(

    $hier,
    $meta,
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

sub get_src($self,$hier,$meta,$dst,$src,$i) {

  my $out = {name=>null};

  if($src && $meta->{overwrite}) {

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
