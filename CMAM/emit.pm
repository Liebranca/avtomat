#!/usr/bin/perl
# ---   *   ---   *   ---
# CMAM EMIT
# code spitter
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
  use Chk qw(is_null is_arrayref);

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
    semipop
  );
  use CMAM::parse qw(
    blkparse_re
  );


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw();


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.8a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# makes C header from cmamout
#
# [0]: byte ptr ; source code string
# [1]: bool     ; destination is header
#
# [<]: byte ptr ; header (new string)
#
# [!]: overwrites input string
#
# [*]: replaces __PUBLIC_N__ in source accto
#      what a header file would need
#
# [*]: removes definitions from source
#      IF the destination is not a header

sub chead {
  # we cat to this output string
  my $out=null;

  # these keywords tell us that we want to
  # include the block in the resulting header!
  my $expose_re=qr{^(?:
    CX|IX|CIX|typedef|struct|union

  )\s+}x;

  # for every exported symbol...
  my $re=qr{\b__EXPORT_(\d+)__\s*;\s*}sm;
  my @captkey=qw(cmd type name args);
  while($_[0]=~ $re) {
    # get element
    my $sym    = cmamout()->{export}->[$1];
    my $export = null;

    # perform block capture...
    $sym="$sym;\n";
    $sym=~ blkparse_re();
    my $capt={%+};

    # avoid including entire block?
    if(! ($sym=~ $expose_re)) {
      # have preprocessor line?
      if(! exists $capt->{cmd}) {
        $export=$sym;
        semipop($export);

        $sym=null;

      # ^nope, make header line from expression
      } else {
        $export=join(' ',map {
          (is_arrayref($capt->{$ARG}))
            ? '(' . join(',',@{$capt->{$ARG}}) . ')'
            : $capt->{$ARG}
            ;

        } grep {
          exists $capt->{$ARG};

        } @captkey);
      };


    # ^nope, definition in header!
    } else {
      # expand shorthand specifiers
      my $cmd;
      if($capt->{cmd} eq 'CX') {
        $cmd='static const';

      } elsif($capt->{cmd} eq 'IX') {
        $cmd='static inline';

      } elsif($capt->{cmd} eq 'CIX') {
        $cmd='static inline const';

      } else {
        $cmd=$capt->{cmd};

      };

      # ^paste entire definition in header
      $export="$cmd $capt->{expr}";

      # erase definition from source
      $sym=null;
    };

    # cat line to header...
    if(! $_[1]) {
      $out .= "$export\n";

    # ... unless output *is* header!
    } else {
      $sym="$export\n" if $_[1];
    };

    $_[0]=~ s[$re][$sym];
  };

  # give header
  return $out;
};


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
      q[or throw "Invalid C macro: '$ARG']
    . q[ at package '$class'";],
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

      "$out;";

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
