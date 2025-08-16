#!/usr/bin/perl
# ---   *   ---   *   ---
# CMAM
# whatever MAM does...
# but better ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package CMAM::emit;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);

  use Arstd::Array qw(iof);
  use Arstd::Fmat;
  use Arstd::throw;

  use lib "$ENV{ARPATH}/lib/";
  use AR sys=>qw(
    lis Arstd::IO::(procin procout);
  );
  use CMAM::static qw(
    cpackage
    cmamout
  );
  use CMAM::token qw(
    tokenpop
    tokenshift
    tokentidy
  );


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw();


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.7a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# makes perl module from cmamout

sub pm {
  my $s=_pm(mute=>1);
  say Arstd::Fmat::tidyup(\$s,filter=>0);
  return;
};


# ---   *   ---   *   ---
# ^guts

sub _pm {
  my %O   = @_;
  my $out = io_procin(\%O);

  # add perl dependencies and
  # begin import method
  push @$out,join("\n",
    deps_pm(),
    'sub import {',
      'my $class=shift;',
    null,
  );

  # get types defined by user
  my @have=map {
    # get copy of values
    my ($name,$expr)=@$ARG;

    # make struct or alias?
    my $keyw=utype_is_struct($name);

    # TODO: unions!
    throw "NYI -- unions"
    if $keyw eq 'union';

    # remove `{}` curlies for structs
    if($keyw ne 'typedef') {
      tokenpop($expr);
      tokenshift($expr);
      tokentidy($expr);
    };

    # add typedef to import sub
    push @$out,(
      "Type\::$keyw(q[$name]=>q[$expr]);\n"
    );

    # give type name
    $name;

  } utypes_pm();


  # add symbol export
  push @$out,join "\n",(
    q[for(@_) {],
      q[my $fn=Chk::getsub($class,$ARG)],
      q[or throw "Invalid macro: '$ARG'";],
      q[macroload($ARG=>$fn);],
    "};\n",
  );


  # close import subroutine;
  # add full unimport sub
  push @$out,join "\n",(
    'return;',
    '};',
    'sub unimport {',
    (map {"Type\::rm(q[$ARG]);"} reverse @have),
    'return;',
    '};',
    null,
  );

  # add macros as perl subroutines!
  for(@{cmamout()->{def}}) {
    push @$out,"$ARG\n";
  };

  # give result
  return io_procout(\%O);
};


# ---   *   ---   *   ---
# get list of _perl_ dependencies
# needed by a cmacro module
#
# [*]: assumes current package is
#      correct (see: setpkg)
#
# [<]: byte pptr ; array of 'use' lines

sub deps_pm {
  return (
    # standard dependencies for all C macros
    'package ' . cpackage(),
    'use v5.42.0;',
    'use strict;',
    'use warnings;',
    'use English qw($ARG);',
    'use lib "$ENV{ARPATH}/lib/";',
    'use CMAM::macro qw(' . join(' ',qw(
      macroguard
      macroin
      macrofoot
      macroload
    )) . ');',
    'use CMAM::token qw(' . join(' ',qw(
      tokenpop
      tokenshift
      tokensplit
      tokentidy
    )) . ');',

    # ^dependencies added by user
    (map {
      my ($name,@req)=@$ARG;
      my $out="use $name";

      $out .= ' qw(' . join("\n",@req) . ')'
      if @req;

      $out;

    } @{cmamout()->{dep}->{pm}}),
  );
};


# ---   *   ---   *   ---
# is this usertype a struct?
#
# [0]: byte ptr ; typedef line
# [<]: byte ptr ; has union or struct keyword
#                 (new string)
#
# [!]: overwrites input string

sub utype_is_struct {
  my $re=qr{(union|struct)\s+};
  return ($_[0]=~ s[$re][])
    ? $1
    : 'typedef'
    ;
};


# ---   *   ---   *   ---
# get list of public typedefs
#
# [<]: byte pptr ; new [name=>definition] array
#
# [*]: these should be included in the
#      perl module for a file, as that
#      enables CMAM to know the types
#      used by the C code

sub utypes_pm {
  return grep {
    my $name="$ARG->[0]";
    my $keyw=utype_is_struct($name);
    my $line=($keyw ne 'typedef')
      ? "typedef $keyw $ARG->[1] $name"
      : "typedef $name $ARG->[1]"
      ;

    tokentidy($line) &&! is_null(
      iof(cmamout()->{export},$line)
    );

  } @{cmamout()->{type}};
};


# ---   *   ---   *   ---
1; # ret
