#!/usr/bin/perl
# ---   *   ---   *   ---
# EMIT PERL
# Tools for outputting Perl code
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Emit::Perl;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;
  use Shb7;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit::Std;
  use Peso::Ipret;

  use parent 'Emit';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM


  Readonly my $OPEN_GUARDS=>

q[#!/usr/bin/perl
$:note;>

#deps
package $:fname;>
  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use lib $ENV{'ARPATH'}.'/lib/';

  use Style;
  use Arstd;

# ---   *   ---   *   ---

];


# ---   *   ---   *   ---


  Readonly my $CLOSE_GUARDS=>q[

# ---   *   ---   *   ---
1; # ret
];


# ---   *   ---   *   ---

sub boiler_open($class,$fname,%O) {

  my $s=$OPEN_GUARDS;
  $O{define}//=[];

  $s.=q[$:iter (path=>$O{include})
  q{  }."use $path;\n"

;>

# ---   *   ---   *   ---
# ROM

$:iter (

  name=>$O{define_keys},
  value=>$O{define_values},

) q{  }."Readonly $name=>$value;\n"

;>

# ---   *   ---   *   ---

];

  my $define_keys=
    Arstd::array_keys($O{define});

  my $define_values=
    Arstd::array_values($O{define});

# ---   *   ---   *   ---

  return Peso::Ipret::pesc(

    $s,

    fname=>$fname,
    note=>Emit::Std::note($O{author},q[#]),

    include=>$O{include},

    define_keys=>$define_keys,
    define_values=>$define_values,

  );

};

sub boiler_close($class,$fname,%O) {
  return $CLOSE_GUARDS;

};

# ---   *   ---   *   ---

sub shwlbind($fname,$soname,$libs_ref) {

  my %symtab=%{
    Shb7::soregen($soname,$libs_ref)

  };

  my $code=<<"EOF"

  our \$FFI_Instance=undef;
  our \$Initialized=0;

sub import {

  if(\$Initialized) {return};

  my \$libfold=Arstd::dirof(__FILE__);
  my \$FFI_Instance=Avt::FFI->get_instance(0);

  \$FFI_Instance->lib(
    "\$libfold/lib$soname.so"

  );

EOF
;

# ---   *   ---   *   ---
# attach symbols from table

  my $tab=$NULLSTR;

  for my $o(keys %{$symtab{objects}}) {

    my $obj=$symtab{objects}->{$o};
    my $funcs=$obj->{functions};
    $tab.="\n\n".

    '# ---   *   ---   *   ---'."\n".
    "# $o\n\n";

    for my $fn_name(keys %$funcs) {

      my $fn=$funcs->{$fn_name};

      my @ar=values %{$fn->{args}};
      for my $s(@ar) {
        $s=q"'$s'";

      };

# ---   *   ---   *   ---

      my $arg_types='['.( join(
        ',',@ar

      )).']';

      my $rtype=$fn->{type};

      $tab.=''.
        "my \$$fn_name=\'$fn_name\';\n".

        '$FFI_Instance->attach('."\n".
        "  \$$fn_name,".
        "  $arg_types,".

        "  '$rtype'\n);\n\n";

# ---   *   ---   *   ---

    };

  };

  $code.=$tab."\n\$Initialized=1;\n\n};\n";
  return $code;

};

# ---   *   ---   *   ---
1; # ret
