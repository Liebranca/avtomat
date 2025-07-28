#!/usr/bin/perl
# ---   *   ---   *   ---
# XS TYPE
# Perl to C
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Avt::XS::Type;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use ExtUtils::Typemaps;

  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;
  use Type qw(sizeof derefof typetab);
  use Type::C;

  use Arstd::Path qw(reqdir parof);

  use parent 'St';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

St::vconst {
  TYPEMAP_FPATH =>
    "$ENV{ARPATH}/.cache/avtomat/typemap",

};


# ---   *   ---   *   ---
# open/close the type conversion table

sub open($class) {

  my $where = parof $class->TYPEMAP_FPATH,i=>1;
  reqdir $where;

  my $fpath = $class->TYPEMAP_FPATH;
  my $tab   = ExtUtils::Typemaps->new(file=>$fpath);

  return bless {tab=>$tab};

};

sub close($self) {
  my $fpath=$self->TYPEMAP_FPATH;
  $self->{tab}->write(file => $fpath);

  return;

};


# ---   *   ---   *   ---
# peso typenames use spaces lmao

sub altname {
  return join '_',split $NSPACE_RE,$_[0];

};


# ---   *   ---   *   ---
# there is no ptr conversion,
# a buf is just a buf;
#
# deal with it

sub enable_ptr_t($self) {

  $self->{tab}->add_inputmap(
    xstype  => 'A9M_PTR_T',
    replace => 1,

    code => q[$var=($type) SvPVbyte_nolen($arg)],

  );

  $self->{tab}->add_outputmap(
    xstype  => 'A9M_PTR_T',
    replace => 1,

    code => q[sv_setpv((SV*) $arg, (char*) $var))],

  );


  return;

};


# ---   *   ---   *   ---
# ^registers pointer type for it

sub add_ptr_t($self,$ptr_t) {

  $self->{tab}->add_typemap(
    ctype   => altname($ptr_t),
    xstype  => 'A9M_PTR_T',

    replace => 1,

  );


  return;

};


# ---   *   ---   *   ---
# entry point
#
# walks through the peso table
# and ensures there is a conversion
# for each of these

sub table($class) {

  my $self = $class->open();
  my $def  = typetab;
  my $cdef = Type::C->Table;

  $self->enable_ptr_t();

  map {

    my $name = $ARG;
    my $type = $def->{$name};

    if(Type->is_ptr($name)
    && $type->{sizeof} eq sizeof 'qword') {

      my $ptr_t=$type;

      if(! exists $cdef->{$name}) {
        $type=derefof $ptr_t;
        if($type) {
          $name=$type->{name};
          Type::C->add($name,$name);

        };

      };

      $self->add_ptr_t($name);
      $self->add_ptr_t(Type::xlate(C=>$name));


    } else {

    };


  } keys %$def;

  $self->close();


  return $self->TYPEMAP_FPATH;


};


# ---   *   ---   *   ---
1; # ret
