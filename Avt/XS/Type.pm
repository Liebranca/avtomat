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
  use Arstd::Path qw(reqdir parof);

  use parent 'St';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.2';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub typemap_fpath {
  return "$ENV{ARPATH}/.cache/avtomat/typemap";
};


# ---   *   ---   *   ---
# open/close the type conversion table

sub open($class) {
  my $where=parof($class->typemap_fpath(),i=>1);
  reqdir($where);

  my $fpath = $class->typemap_fpath();
  my $tab   = ExtUtils::Typemaps->new(file=>$fpath);

  return bless {tab=>$tab};
};

sub close($self) {
  my $fpath=$self->typemap_fpath();
  $self->{tab}->write(file => $fpath);

  return;
};


# ---   *   ---   *   ---
# peso typenames use spaces lmao

sub altname {
  return join '_',split qr{ +},$_[0];
};


# ---   *   ---   *   ---
# easier to just generate this from
# scratch every time, than even try
# to maintain it...

sub mkiomap($self) {
  # more or less a simplified version
  # of the standard typemap from ExtUtils
  #
  # it only deals with raw peso types, so
  # no weird perl stuff needed here
  my $have={
    A9M_INT_T=>{
      in  => q[$var=($type)SvIV($arg)],
      out => q[sv_setiv($arg,(IV)$var)],
    },
    A9M_UINT_T=>{
      in  => q[$var=($type)SvUV($arg)],
      out => q[sv_setiv($arg,(UV)$var)],
    },
    A9M_REAL_T=>{
      in  => q[$var=(float)SvNV($arg)],
      out => q[sv_setnv($arg,(double)$var)],
    },
    A9M_DREAL_T=>{
      in  => q[$var=(double)SvNV($arg)],
      out => q[sv_setnv($arg,(double)$var)],
    },
    A9M_PTR_T=>{
      in  => q[$var=($type)SvPVbyte_nolen($arg)],
      out => q[sv_setpv((SV*) $arg,(char*)$var))],
    },
    A9M_REL_T=>{
      in  => q[$var=(unsigned int)SvUV($arg)],
      out => q[sv_setiv($arg,(UV)$var)],
    },
    A9M_STRUC_T=>{
      in  => q[$var=*(($type*)SvPVbyte($arg,sizeof($type)))],
      out => q[sv_setpv((SV*) $arg,(char*)&$var))],
    },
  };

  # ^add them all
  for my $name(keys %$have) {
    $self->{tab}->add_inputmap(
      xstype  => $name,
      replace => 1,
      code    => $have->{$name}->{in},
    );
    $self->{tab}->add_outputmap(
      xstype  => $name,
      replace => 1,
      code    => $have->{$name}->{out},
    );
  };
  return;
};


# ---   *   ---   *   ---
# mark a given type for a specific conversion

sub typecon($self,$peso,$xs) {
  $self->{tab}->add_typemap(
    ctype   => $peso,
    xstype  => $xs,
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
  my $def  = typetab();

  $self->mkiomap();

  for(keys %$def) {
    my $name = $ARG;
    my $type = $def->{$name};

    # raw pointers
    if(Type->is_ptr($name)) {
      $self->typecon($name=>'A9M_PTR_T');

    # relative pointers
    } elsif($name eq 'rel') {
      $self->typecon($name=>'A9M_REL_T');

    # floats and doubles
    } elsif($name=~ qr{^d?real$}) {
      my $t=uc $name;
      $self->typecon($name=>"A9M_${t}_T");

    # structures
    } elsif(@{$type->{struc_t}}) {
      $self->typecon($name=>'A9M_STRUC_T');

    # integers
    } else {
      my $t=(Type::MAKE::is_signed($type))
        ? 'INT'
        : 'UINT'
        ;
      $self->typecon($name=>"A9M_${t}_T");
    };
  };

  $self->close();
  return $self->typemap_fpath();
};


# ---   *   ---   *   ---
1; # ret
