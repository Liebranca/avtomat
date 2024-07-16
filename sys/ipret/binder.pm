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

  use Arstd::PM;
  use Arstd::WLog;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
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


  # walk block elements
  my $hist = $hier->sort_hist($recalc);
  my $i    = 0;

  map {


    # unpack
    my $point=$ARG;

    my ($branch,$seg,$route,@req)=@{
      $point->{'asm-Q'}

    };


    # analyze instructions
    map {

      my ($opsz,$ins,@args)=@$ARG;

      if($ins eq 'int') {

        my $pass = $branch->{vref}->{data};
        my $j    = @$pass-1;

        map {

          $hier->depvar(
            $hier->vname(0x00),
            $hier->vname($ARG),

            $i-$j--,

          );

        } @$pass;

      } elsif(@args && $args[0]->{type} eq 'r') {

        my $dst  = $args[0];
        my $var  = $point->{var};

        my $name = $hier->vname($dst->{reg});


        # remember this value...
        push @$var,$name;
        $hier->chkvar($name,$i);


        # are we modifying?
        if(

           $point->{overwrite}
        && $args[1]

        ) {

          # non-const source?
          if($args[1]->{type} eq 'r') {

            my $dep=$hier->vname(
              $args[1]->{reg}

            );

            $hier->depvar($name,$dep,$i);

          };

        };

      };

    } @req;

    $i++;

  } @$hist;


  # ~~
  $hier->endtime($i-1);
#  map {
#
#    use Fmat;
#    fatdump \$hier->{var}->{$ARG};
#
#    my $e=$hier->redvar($ARG);
#
#  } $hier->varkeys;


  $hier->{node}->prich();
#  exit;
  return;

};

# ---   *   ---   *   ---
1; # ret
