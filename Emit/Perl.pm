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
# lib,

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
  use Arstd::PM qw(cload);

  use Shb7::Path;
  use Shb7::Build;

  use Tree;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit::Std;

  use parent 'Emit';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.6';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# the stuff you paste up top

sub open_guards($class,$fname) {

  return join "\n",(
    "package $fname;",
    "  use v5.36.0;",
    "  use strict;",
    "  use warnings;",
    "  use English;",

    q[  use lib "$ENV{ARPATH}/lib/sys/";],
    q[  use lib "$ENV{ARPATH}/lib/";],

    "  use Style;",

  );

};


# ---   *   ---   *   ---
# ^on steroids

sub boiler_open($class,$fname,%O) {

  $O{def}//=[];

  my $note=Emit::Std::note($O{author},q[#]);

  return join "\n",(

    "#!/usr/bin/perl",

    $note,
    $class->open_guards($fname),

    (map {"  use lib $ARG;"} @{$O{lib}}),
    (map {"  use $ARG;"} @{$O{inc}}),

    $class->make_ROM($O{def}),
    "\n"

  );

};


# ---   *   ---   *   ---
# ^closer

sub boiler_close($class,$fname,%O) {

  return join "\n",(
    "\n# ---   *   ---   *   ---",
    "1; # ret\n",

  );

};


# ---   *   ---   *   ---
# pastes stuff into St::vconst

sub make_ROM($def=undef) {

  # early exit?
  $def //= [];
  return () if ! @$def;


  # good stuff
  my $defi = 0;
  my @defk = array_keys   $def;
  my @defv = array_values $def;

  return 'St::vconst {',(map {

    my $name  = $ARG;
    my $value = $defv[$defi++];

    "  $name=>$value;";


  } @defk),'};';

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
# use shwl to make XS module glue

sub shwlbind($class,$soname,$libs_ref) {

  my $symtab=Shb7::Build::soregen(
    $soname,$libs_ref

  );

  my $code=null;


  # make header for bindings
  my $hed=null;
  for my $file(keys %{$symtab->{object}}) {
    my $obj   = $symtab->{object}->{$file};
    my $funcs = $obj->{function};

    $hed .= (

      "\n\n"

    . "// ---   *   ---   *   ---\n"
    . "// $file\n\n"

    );


    # walk functions
    map {

      my $name  = $ARG;
      my $fn    = $funcs->{$name};

      my @ar    = array_values($fn->{args});

      my $args  = join ',',@ar;
      my $rtype = $fn->{rtype};

      $hed .= "$rtype $name($args);\n";


    } keys %$funcs;

  };


  # ^insert header into sneaky XS compilation ;>
  my $xsbit=join "\n",(
    '  use Avt::XS;',
    "  use $class;",

    '  Avt::XS->build(',
    "    $class => q[$hed],",
    "    libs   => " . $symtab->{bld}->libline,

    '  );',

  );


  return $xsbit;

};


# ---   *   ---   *   ---
1; # ret
