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
  use Fmat;

  use Arstd::Path;
  use Arstd::Array;

  use Shb7::Path;
  use Shb7::Build;

  use Tree;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit::Std;

  use parent 'Emit';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# the stuff you paste up top

sub open_guards($class,$fname) {

  return join "\n",

    "package $fname;",
    "  use v5.36.0;",
    "  use strict;",
    "  use warnings;",

    "  use English qw(-no_match_vars);",

    "  use lib \$ENV{'ARPATH'}.'/lib/sys/';",
    "  use lib \$ENV{'ARPATH'}.'/lib/';",

    "  use Style;",
    "  use Arstd::Path;",

    "\n"

  ;

};

# ---   *   ---   *   ---
# ^on steroids

sub boiler_open($class,$fname,%O) {

  $O{def}//=[];

  my $note = Emit::Std::note($O{author},q[#]);

  my $defi = 0;
  my @defk = array_keys($O{def});
  my @defv = array_values($O{def});


  return join "\n",


    "#!/usr/bin/perl",

    $note,
    $class->open_guards($fname),


    (join "\n",map {
      "  use lib $ARG;"

    } @{$O{lib}}),

    (join "\n",map {
      "  use $ARG;"

    } @{$O{inc}}),


    (join "\n",map {

      my $name  = $ARG;
      my $value = $defv[$defi++];

      "Readonly $name=>$value;";

    } @defk),

    "\n"

  ;

};

# ---   *   ---   *   ---
# ^closer

sub boiler_close($class,$fname,%O) {

  return join "\n",

    "\n# ---   *   ---   *   ---",
    "1; # ret",

    "\n"

  ;

};

# ---   *   ---   *   ---
# applies formatting to code

sub tidy($class,$sref) {
  return Fmat::tidyup($sref);

};

# ---   *   ---   *   ---
# derive package name from
# name of file

sub get_pkg($class,$fname) {
  my $dir=parof($fname);
  return fname_to_pkg($fname,shpath($dir));

};

# ---   *   ---   *   ---
# generates shadowlib

sub shwlbind($soname,$libs_ref) {

  my %symtab=%{
    Shb7::Build::soregen($soname,$libs_ref)

  };

  my $code=<<"EOF"

  our \$FFI_Instance=undef;
  our \$Initialized=0;

sub import {

  if(\$Initialized) {return};

  my \$libfold=dirof(__FILE__);
  \$FFI_Instance=Avt::FFI->get_instance(0);

  \$FFI_Instance->lib(
    "\$libfold/lib$soname.so"

  );

EOF
;


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

      my @ar=array_values($fn->{args});
      for my $s(@ar) {
        $s="'$s'";

      };


      my $arg_types='['.( join(
        ',',@ar

      )).']';

      my $rtype=$fn->{rtype};

      $tab.=''.
        "my \$$fn_name=\'$fn_name\';\n".

        '$FFI_Instance->attach('."\n".
        "  \$$fn_name,".
        "  $arg_types,".

        "  '$rtype'\n);\n\n";


    };

  };

  $code.=$tab."\n\$Initialized=1;\n\n};\n";
  return $code;

};

# ---   *   ---   *   ---
1; # ret
