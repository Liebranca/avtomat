#!/usr/bin/perl
# ---   *   ---   *   ---
# RING
# Module chains!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Ring;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;
  use Chk;

  use Arstd::PM;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  locals => 'ring',

  layers  => sub {$_[0]->locals . '_layers'},
  cstruc  => sub {$_[0]->locals . '_cstruc'},

  cstruc_layers => 'cstruc_layers',

};

# ---   *   ---   *   ---
# importer injections

St::imping {

  '*vconst' => sub ($dst,$O) {

    # get ctx
    my $class = St::cpkg;
    my $src   = $O->{$class->layers};

    my $layer = (is_coderef $src)
      ? $src->($dst)
      : $src
      ;


    # array to hash
    if(is_arrayref $layer) {

      $layer={ map {

        # deref subs
        $ARG=$ARG->()
        if is_coderef $ARG;

        # ! alias
        $ARG=>$ARG;


      } @$layer };

    };


    # import packages if need
    # and manually update class cache
    my $cache=St::classcache $dst,'vconst';

    $cache->{$class->layers}={ map {

      my $lis = $ARG;
      my $pkg = $layer->{$lis};

      cloadi $pkg;


      $lis=>$pkg;

    } keys %$layer };


    # give constructor methods
    Arstd::PM::add_symbol(

      "$dst\::"
    . $class->cstruc,

      "$class\::_cstruc"

    );

    Arstd::PM::add_symbol(

      "$dst\::"
    . $class->cstruc_layers,

      "$class\::_cstruc_layers"

    );


    return;


  },

};

# ---   *   ---   *   ---
# call cstruc for layers

sub _cstruc($from,%O) {


  my $layer=$from->ring_layers;

  map {


    # fetch alias,arguments,package
    my $lis  = $ARG;

    my $args = $O{$lis};
    my $pkg  = $layer->{$lis};

say $lis;
exit if ! defined $pkg;

say"\\-->$pkg\n";


    # ^typeswitch
    if(is_arrayref $args) {
      $lis => $pkg->new(@$args);

    } elsif(is_hashref $args) {
      $lis => $pkg->new(%$args);

    } elsif(defined $args) {
      $lis => $pkg->new($args);

    } else {
      $lis => $pkg->new();

    };


  } keys %O;

};

# ---   *   ---   *   ---
# ^from ice

sub _cstruc_layers($self,%O) {


  # get parent and child classes
  my $cpkg   = St::cpkg;
  my $class  = ref $self;

  my $cstruc = $cpkg->cstruc;


  # call constructor on uninitialized
  %O=$class->$cstruc(

    map  {$ARG=>$O{$ARG}}
    grep {! defined $self->{$ARG}}

    keys %O

  );

  # ^replace
  map  {$self->{$ARG}=$O{$ARG}}
  keys %O;


  return;

};

# ---   *   ---   *   ---
1; # ret
