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

  use lib "$ENV{ARPATH}/lib/sys/";
  use Arstd::Re;
  use parent 'Ftype::Text';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v1.00.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# definitions

sub classattr {return {
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

    byte word dword qword
    xword yword zword

    real dreal
    ptr pptr addr
    ref rel deref relix drelix

    mem cask tree

    nihil stark signal

  )],

  specifier=>[qw(
    auto extern inline restrict
    const signed sign unsigned static

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
    macro package match use

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

  preproc=>Arstd::Re::eaf('#',lbeg=>0,opscape=>0),
  highlight=>[
    qr{^[^\s]+[^:]*:[^:]?} => 0x0D,
    qr{\s[^:]+:[^:]?}      => 0x07,
  ],
}};


# ---   *   ---   *   ---
# a generic pattern for grabbing symbols
#
# [<]: re ; new/cached pattern
#
# [!]: conventional wisdom is, of course,
#      you shouldn't parse using regexes.
#
#      and true to said wisdom: this is not perfect.
#      it will not account for strings, for instance
#
#      this is only used as a quick way to
#      process the code for the parser proper

sub blkparse_re {
  # basic rule for what is a valid symbol name
  my $name_re=Ftype::Text->name_re;

  # grabs things between `()` parens
  my $args_re=qr{\s*\((?<args>[^\)]*)\)\s*}s;

  # this one looks scary, but all it's doing is
  # grab `{}` scoped blocks recursively
  #
  # saves us from writing an actual parser
  # just for the bootstrap...
  my $blk_re=qr{(?<blk>(?<!\-\>)
    (?<rec> \{
      ([^\{\}]+
    | (?&rec))+

    \})+

  )}sx;

  # function is (re): type+ name args blk
  my $fn_re=qr{(?<expr>
    (?<type> [^\(=;]+)
    $args_re
    $blk_re
    ;

  )}sx;

  # ^call skips type ;>
  my $call_re=qr{(?<expr>$args_re)}sx;

  # struc or union is (re): name blk
  my $struc_re=qr{(?<expr>
    (?<name> [^\{=;]+)? \s*
    $blk_re
    [^;]*
    ;

  )}sx;

  # straight decl just takes everything until
  # it hits a semicolon
  my $value_re=qr{(?<expr>(?:[^;]|\\;)+;)}s;


  # asm rules; first valid name in expression
  # is assumed to be an instruction
  #
  # if it's not recognized as a CMAM macro
  # by later checks, then it's plain C and
  # we won't touch it
  return qr{
    # we catch C preprocessor lines so as
    # to restore them later; we won't touch em
    (?:(?<expr>\# ([^\n]|\\\n)+\n))

  | (?:(?<cmd> (?!REPL) $name_re) \s+
    (?:$fn_re|$struc_re|$value_re))

  | (?:(?<cmd> (?!REPL) $name_re) \s*
    (?:$call_re))

  }sx;
};


# ---   *   ---   *   ---
# utility method...

sub is_cpp {
  return int($_[0]=~ qr{\.[ch](?:pp|xx)$})
};


# ---   *   ---   *   ---
1; # ret
