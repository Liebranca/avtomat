#!/usr/bin/perl
# ---   *   ---   *   ---
# C GRAMMAR
# Don't cast the RET of malloc!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::C;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/avtomat/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Array;
  use Arstd::IO;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/avtomat/hacks/';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/avtomat/';

  use Lang;
  use Grammar;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  Readonly our $REGEX=>{

    term  => Lang::nonscap(q[;]),
    nterm => Lang::nonscap(

      q[;],

      iv     => 1,
      mod    => '+',
      sigws  => 1,

    ),

    clist => Lang::nonscap(q[,]),

# ---   *   ---   *   ---

    prim=>Lang::eiths(

      [qw(

        bool char short int long
        float double void

        int8_t int16_t int32_t int64_t
        uint8_t uint16_t uint32_t uint64_t

        wchar_t size_t
        intptr_t uintptr_t

        FILE

        nihil stark signal

      )],

      bwrap=>1,

    ),

# ---   *   ---   *   ---

    spec=>Lang::eiths(

      [qw(

        auto extern inline restrict
        const signed unsigned static

        explicit friend mutable
        namespace override private
        protected public register

        template using virtual volatile
        noreturn _Atomic complex imaginary
        thread_local operator

      )],

      bwrap=>1,

    ),

    name=>qr{[_\w][_\w\d]*},

  };

# ---   *   ---   *   ---

  rule('~<term>');

  rule('*~<spec>');
  rule('~<prim>');
  rule('~<name>');
  rule('?~<clist> &rew');

  rule('$<decl> spec prim name');
  rule('$<decl-list> &decl_list decl clist');

# ---   *   ---   *   ---
# ^post-parse

sub decl($self,$branch) {

  my $st=$branch->bhash();
  $st->{spec}//='$NULLSTR';

  $branch->clear();
  $branch->{value}=$st;

};

sub decl_list($self,$branch) {

  my @ar=$branch->branch_values();
  pop @ar if $ar[-1] eq 'clist';

  $branch->{value}=\@ar;
  $branch->clear();

};

# ---   *   ---   *   ---

  rule('%<beg_parens=\(>');
  rule('%<end_parens=\)>');

  rule(q[

    $<args>
    &args_rd

    beg_parens
    decl-list
    end_parens

  ]);

# ---   *   ---   *   ---
# ^post-parse

sub args_rd($self,$branch) {

  my $lv=$branch->{leaves};
  my $ar=$lv->[1]->{value};

  $branch->{value}=$ar;
  $branch->clear();

};

# ---   *   ---   *   ---
# ^combo

  rule('$<fn-decl> &fn_decl decl args');

# ---   *   ---   *   ---
# ^post-parse

sub fn_decl($self,$branch) {

  my @ar=$branch->branch_values();

  my $st={

    name  => $ar[0]->{name},

    spec  => $ar[0]->{spec},
    rtype => $ar[0]->{prim},

    args  => $ar[1],

  };

  $branch->clear();
  $branch->init($st);

};

# ---   *   ---   *   ---

  rule(q[
    |<needs-term-list>
    &clip

    fn-decl

  ]);

  rule(q[

    <needs-term>
    &clip

    needs-term-list
    term

  ]);

  our @CORE=qw(needs-term);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
# test

  my $prog = q[static int holy(int y,int z);];
  my $ice  = Grammar::C->parse($prog);

  $ice->{p3}->prich();

# ---   *   ---   *   ---
1; # ret
