#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO STD
# Boilerpaste galore
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::std;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use lib $ENV{'ARPATH'}.'/lib/';

  use Style;
  use Arstd::PM;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PE_STD);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Shared_FVars($self) { return {
    %{Grammar::peso::eye::Shared_FVars($self)},

  }};

  Readonly our $PE_STD=>
    'Grammar::peso::std';

# ---   *   ---   *   ---
# beqs for peso::common

sub use_common($class) {

  my $dst=caller;
  my $pkg='Grammar::peso::common';

  cload($pkg);


  $dst->dext_rules($pkg,qw(
    lcom nterm opt-nterm term

  ));

};

# ---   *   ---   *   ---
# beqs for peso::value

sub use_value($class) {

  my $dst=caller;
  my $pkg='Grammar::peso::value';

  cload($pkg);


  $dst->dext_rules($pkg,qw(
    value num str flg bare seal sigil

  ));

};

# ---   *   ---   *   ---
# beqs for peso::eye

sub use_eye($class) {

  my $dst=caller;


  # packages used
  state @deps=qw(
    Grammar::peso::common
    Grammar::peso::value
    Grammar::peso::ops

  );

  state @pkg=qw(
    Grammar::peso::eye

  );

  # ^load in
  cload(@deps,@pkg);


  # manual selective inheritance
  submerge(

    \@deps,

    xdeps => 1,
    subex => qr{^throw_},

    main  => $dst,

  );

  submerge(

    \@pkg,

    xdeps => 1,
    subok => qr{(?: rd_\w+_nterm|rd_nterm)}x,

    main  => $dst,

  );


  Arstd::PM::add_symbol(

    "$dst\::Shared_FVars",
    "$PE_STD\::Shared_FVars",

  );


  $dst->dext_rules($deps[-1],qw(expr));

};

# ---   *   ---   *   ---
1; # ret
