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
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);

  use Arstd::String qw(strip);
  use Arstd::Path qw(parof to_pkg);
  use Arstd::Array qw(nkeys nvalues);

  use Shb7::Path qw(relto_root);
  use Shb7::Build;

  use lib "$ENV{ARPATH}/lib/";
  use AR sys=>qw(
    use Arstd::Fmat::(tidyup);
  );

  use parent 'Emit::Std';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.7';
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

  my $note=$class->note($O{author},q[#]);

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
  my @defk = nkeys   $def;
  my @defv = nvalues $def;

  return 'St::vconst {',(map {
    my $name  = $ARG;
    my $value = $defv[$defi++];

    "  $name=>$value;";

  } @defk),'};';
};


# ---   *   ---   *   ---
# applies formatting to code

sub tidy($class,$sref) {
  return tidyup($sref);
};


# ---   *   ---   *   ---
# derive package name from
# name of file

sub get_pkg($class,$fname) {
  my $dir=parof($fname);
  relto_root($dir);
  return to_pkg($fname,$dir);
};


# ---   *   ---   *   ---
1; # ret
