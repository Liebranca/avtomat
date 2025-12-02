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
  use Arstd::String qw(cat);
  use Arstd::Path qw(extwap);
  use Arstd::Fmat;
  use Arstd::fatdump;
  use Arstd::throw;

  use Ftype::Text::C;

  use lib "$ENV{ARPATH}/lib/";
  use AR sys=>qw(
    lis Arstd::IO::(procin procout);
  );
  use Arstd::Token qw(
    tokenpop
    tokenshift
    tokentidy
  );
  use CMAM::static qw(
    cpackage
    cmamout
    ctree
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
# [0]: byte ptr ; filename
# [1]: byte ptr ; source code string
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

  # for every exported symbol...
  my $re=qr{\b__EXPORT_(\d+)__\s*;\s*}sm;
  while($_[1]=~ $re) {
    # fetch the referenced element and process it
    my $ref    = $1;
    my @export = (
      # each 'public' statement expands an
      # expression, which may in turn result
      # in multiple expressions being output!
      #
      # as such, we need to apply symbol
      # processing to the entire array
      map {chead_proc_sym($ARG)}
      @{cmamout()->{export}->[$ref]}
    );

    my $to_hed=join "\n",map {$ARG->[0]} @export;
    my $to_src=join "\n",map {$ARG->[1]} @export;

    # cat line to header
    $out .= "$to_hed\n";
    $_[1]=~ s[$re][$to_src];
  };

  # nothing to give!
  return null if is_null($out);

  # give header with guards
  my $guard=guardof($_[0]);
  return join("\n",
    "#ifndef $guard",
    "#define $guard",

    "#ifdef __cplusplus",
    "extern \"C\" {",
    "#endif",

    $out,

    "#ifdef __cplusplus",
    "}",
    "#endif",

    "#endif // $guard"
  );
};


# ---   *   ---   *   ---
# ^processes individual symbol
#
# [0]: mem  ptr ; expression hashref
# [<]: byte ptr ; C code (new string)

sub chead_proc_sym {
  my ($nd)=@_;

  # these keywords tell us that we want to
  # include the block in the resulting header!
  my $expose_re=qr{\b(?:
    CX|IX|CIX|typedef|struct|union

  )\b}x;

  # ^each writ to it's respective var ;>
  my $to_hed=null;
  my $to_src=null;

  # exported native C preprocessor line?
  if($nd->{cmd} eq '#') {
    my $cmd    = tokenshift($nd);
    my $opr_re = qr{ *([^[:alnum:]]) *};

    $nd->{expr}=~ s[$opr_re][$1]g
    if $cmd eq 'include';

    $nd->{cmd} .= $cmd;

  # exported inline?
  } elsif($nd->{cmd}=~ $expose_re) {
      # replace specifier shorthands
      my $cmd=$nd->{cmd};
      my $tab={
        CX  => 'static const',
        IX  => 'static inline',
        CIX => 'static inline const',
      };

      $nd->{cmd}=$tab->{$cmd}
      if exists $tab->{$cmd};

  # exporting *only* the symbol decl!
  } elsif(int @{$nd->{blk}}) {
    # save the full definition on the source only
    $to_src=ctree()->expr_to_code($nd);

    # ^ eliminating the block from the header
    #   then makes it so only the declaration
    #   is exported!
    $nd->{blk}=[];
  };

  $to_hed=ctree()->expr_to_code($nd);
  return [$to_hed=>$to_src];
};


# ---   *   ---   *   ---
# get guard name for file
#
# [0]: byte ptr ; filename
# [<]: byte ptr ; guard name (new string)

sub guardof {
  my $re  = qr{[\./]};
  my $out = "$_[0]";
  extwap $out,'h';

  $out=uc $out;
  $out=~ s[$re][_]smg;

  return "__${out}__";
};


# ---   *   ---   *   ---
# makes perl module from cmamout

sub pm {
  my $s=_pm(mute=>1);
  return Arstd::Fmat::tidyup(\$s,filter=>0);
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
    'if(! ${loaded()}) {',
  );

  # get types defined by user
  my @have=map {
    # get copy of values
    my ($keyw,$name,$expr)=@$ARG;

    # add typedef to import sub
    if($keyw=~ qr{type(?:def|rev)}) {
      push @$out,(
        "Type\::MAKE\::typedef("
      . "q[$name]=>q[$expr]);"
      );

    } else {
      # stringify object
      my $s  =  fatdump \$expr,mute=>1;
      my $re =  qr{(?:^\[)|(?:\]\n?$)};
         $s  =~ s[$re][]g;

      push @$out,(
        "Type\::MAKE\::strucmake("
      . "q[$keyw]=>q[$name]=>($s));\n"
      );
    };

    # give type name
    $name;

  } utypes_pm();


  # add symbol export
  push @$out,join "\n",(
    '};',
    q[for(@_) {],
      q[my $fn=Chk::getsub($class,$ARG)],
      q[or throw "C macro '$ARG' ]
    . q[not defined by package '$class'";],
      q[macroload($ARG=>$fn);],
    "};\n",
  );


  # close import subroutine;
  # add full unimport sub
  push @$out,join "\n",(
    'if(! ${loaded()}) {',
    'set_loaded();',
    'AR::load($ARG) for pkgdeps();',
    '};',
    'return;',
    '};',
    'sub unimport {',
    'if(${loaded()}) {',
    'unset_loaded();',
    (map {"Type\::rm(q[$ARG]);"} reverse @have),
    'AR::unload($ARG) for pkgdeps();',
    '};',
    'return;',
    '};',
    null,
  );

  push @$out,join "\n",(
    'sub pkgdeps {return qw(',
    (map {$ARG->[0]} @{cmamout()->{dep}->{pm}}),
    ')};',
  );

  push @$out,q[
    sub loaded {
      state $out=0;
      return \$out;
    };
    sub set_loaded {
      ${loaded()}=1;
      return;
    };
    sub unset_loaded {
      ${loaded()}=0;
      return;
    };
  ];

  # add macros as perl subroutines!
  for(@{cmamout()->{def}}) {
    push @$out,"$ARG\n";
  };

  push @$out,"\n1; # ret";

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
    'package ' . cpackage() . ';',
    'use v5.42.0;',
    'use strict;',
    'use warnings;',
    'use English qw($ARG);',
    'use lib "$ENV{ARPATH}/lib/sys/";',
    'use Arstd::Token qw(' . join(' ',qw(
      tokenpop
      tokenshift
      tokensplit
      tokentidy
    )) . ');',
    'use Arstd::throw;',
    'use lib "$ENV{ARPATH}/lib/";',
    'use AR;',
    'use CMAM::macro qw(' . join(' ',qw(
      macroload
    )) . ');',
    'use CMAM::sandbox qw(' . join(' ',qw(
      strnd
      clnd
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
  my $re=qr{(union|struct?)\s+};
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
    # reconstruct definition from params
    my $nd={
      cmd  => $ARG->[0],
      expr => "$ARG->[1] $ARG->[2]",
    };

    if($nd->{cmd} eq 'typerev') {
      $nd->{expr} = "$ARG->[2] $ARG->[1]";
      $nd->{cmd}  = 'typedef';

    } elsif($nd->{cmd} ne 'typedef') {
      $nd->{expr} = "$nd->{cmd} $ARG->[1]";
      $nd->{cmd}  = 'typedef';
    };

    # ^ get whether this definition was
    #   marked for export
    int grep {grep {
       $ARG->{cmd}  eq $nd->{cmd}
    && $ARG->{expr} eq $nd->{expr};

    } @$ARG} @{cmamout()->{export}};

  } @{cmamout()->{type}};
};


# ---   *   ---   *   ---
1; # ret
