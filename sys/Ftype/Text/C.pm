#!/usr/bin/perl
# ---   *   ---   *   ---
# C
# Don't cast the RET of malloc!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text::C;
  use v5.42.0;
  use strict;
  use warnings;

  use English;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;
  use Arstd::Re qw(re_eaf);
  use Ftype::Text;


# ---   *   ---   *   ---
# make ice

BEGIN { Ftype::Text->new(

  name => 'C',

  ext  => '\.([ch](pp|xx)?|C|cc|c\+\+|cu|H|hh|ii?)$',
  mag  => '^(C|C\+\+) (source|program)',

  com  => '//',
  lcom => '//',

  type => [qw(
    bool char short int long
    float double void

    ([A-Za-z][A-Za-z0-9]+_t)

    FILE

    nihil stark signal

  )],

  specifier=>[qw(
    auto extern inline restrict
    const signed unsigned static

    explicit friend mutable
    namespace override private
    protected public register

    template using virtual volatile
    noreturn _Atomic complex imaginary
    thread_local operator

  )],

  intrinsic=>[qw(
    sizeof offsetof typeof alignof
    typename alignas

    static_assert cassert
    _Generic __attribute__

    new delete

  )],

  directive=>[qw(
    class struct union typedef enum
    errchk err endchk

  )],

  fctl=>[qw(
    if else for while do
    switch case default
    try throw catch break
    continue goto return

  )],

  resname=>[qw(
    this true false

  )],

  preproc=>re_eaf('#',lbeg=>0,opscape=>0),


)};


# ---   *   ---   *   ---
# utility method...

sub is_cpp {return $_[0]=~ qr{\.[ch](?:pp|xx)$}};


# ---   *   ---   *   ---
1; # ret
