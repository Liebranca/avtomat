#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO GRAMMAR
# Recursive swan song
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Array;
  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;
  use Grammar;

  use Grammar::peso::std;
  use Grammar::peso::common;
  use Grammar::peso::meta;
  use Grammar::peso::hier;
  use Grammar::peso::cdef;
  use Grammar::peso::io;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.02.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # beqs
  $PE_STD->use_common();
  $PE_STD->use_eye();
  $PE_STD->use_switch();
  $PE_STD->use_re();
  $PE_STD->use_wed();
  $PE_STD->use_var();
  $PE_STD->use_file();

  # class attrs
  fvars('Grammar::peso::var');

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    %{$PE_COMMON->get_retab()},

  };

# ---   *   ---   *   ---
# ^generate parser tree

  our @CORE=qw(

    wed lis re

    ptr-decl blk-ice

    switch jmp rept file

    ellipses

  );

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
# crux

sub recurse($class,$branch,%O) {

  my $s=(Tree::Grammar->is_valid($branch))
    ? $branch->{value}
    : $branch
    ;


  # get parser ice
  my $ice=$class->new(%O);

  # strip metadata
  $s=$PE_META->recurse($s,mach=>$ice->{mach});


  # separate code in hierarchical blocks
  my $st=$PE_HIER->parse(

    $s,

    mach  => $ice->{mach},
    frame => $ice->{frame},

  );

  my $lv=\$st->{p3}->{leaves};


  # ^handle block inheritance
  map {$st->hier_beq($ARG)} @{$$lv};

  # ^expand macros
  map {
    $st->branch_recurse($ARG,'Grammar::peso::cdef');
    $st->branch_recurse($ARG,'Grammar::peso::io');

  } @{$$lv};


  # now parse each block individually
  map {
    $st->branch_parse($ARG,$ice);

  } @{$$lv};

  my @lv=$st->{p3}->pluck_all();
  $ice->{p3}->pushlv(@lv);

  return $ice;

};

# ---   *   ---   *   ---
# test

  my $src=$ARGV[0];
  $src//='lps/peso.rom';

  my $prog=($src=~qr{\.rom$})
    ? orc($src)
    : $src
    ;

  return if ! $src;

  $prog =~ m[([\S\s]+)\s*STOP]x;
  $prog = ${^CAPTURE[0]};

  my $ice=Grammar::peso->recurse($prog);

#  $ice->{p3}->prich();
#  $ice->{mach}->{scope}->prich();


  $ice->run(

    entry=>1,
    keepx=>1,

    input=>[

      'hey',

    ],

  );

# ---   *   ---   *   ---
1; # ret
