#!/usr/bin/perl
# ---   *   ---   *   ---
# XS
# Uses Inline::C to make XS
# ... yep, we ain't writing it by hand ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Avt::XS;
  use v5.42.0;
  use strict;
  use warnings;

  use Carp qw(croak);
  use English;
  use XSLoader;
  use Cwd qw(getcwd);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

  use Arstd::Path qw(
    pkg_to_fname
    extcl extwap
    basef based parof

  );

  use Arstd::IO qw(orc owc);
  use Arstd::PM qw(cload);

  use lib $ENV{'ARPATH'}.'/lib/';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ^i write VERSION way *I* like

sub sane_version {
  state $re=qr{[^0-9]+$};
  $_[0]=~ s[$re][];

  return $_[0];

};


# ---   *   ---   *   ---
# compiles XS stuff

sub build($class,$name,$code,%O) {


  # get packages needed by build
  cload qw(
    Fmat
    Shb7::Path
    Avt::XS::Type
    Inline

  );

  # defaults
  $O{where} //= Shb7::Path::ctrash() . '/_Inline';
  $O{lib}   //= null;
  $O{-f}    //= 0,

  # make path if need
  reqdir $O{where};


  # mandatory
  no strict 'refs';
  my $version = sane_version ${"$name\::VERSION"};
  my $author  = ${"$name\::AUTHOR"};

  # where is module?
  my $modpath = pkg_to_fname $name;
  my $dir     = extcl        $modpath;
  my $blddir  = "$O{where}/build/$dir";


  # make the call
  Inline->bind(C => $code => (
    using     => 'ParseRegExp',

    name      => $name,
    directory => $O{where},

    libs      => $O{lib},

    typemaps  => Avt::XS::Type->table,
    enable    => 'autowrap',
    disable   => 'autoname',
    disable   => 'clean_after_build',

    ($O{-f}) ? (enable => 'force_build') : () ,

  ));


  # Inline doesn't want you to pass in VERSION
  # unless you're distributing
  #
  # overall, terrible design choice
  #
  # what follows is just a waltzaround for it

  my $mkfile="$blddir/Makefile.PL";

  # do we reaaaaally have to?
  goto lastchk if ! moo($modpath,$mkfile);

  # ^yep, we REALLY have to do this...
  my $body    = orc $mkfile;
  my $make_re = qr{
    %options \s* = \s* %\{ \s*
    (\{.+\}) \s* \};

  }xs;


  # there is NO reason to omit this data
  if($body=~ $make_re) {
    my $have=eval $1;

    $have->{VERSION} = $version;
    $have->{AUTHOR}  = $author;

    my $stir=  Fmat::fatdump \$have,mute=>1;
       $stir=~ s[;\s*$][];
       $stir=  "\%options=\%{$stir};";


    $body=~ s[$make_re][$stir];
    owc $mkfile,$body;


  # unless MakeMaker changes format,
  # we shouldn't see this
  } else {
    croak "Bad Makefile: '$mkfile'";

  };


  # the version is inside the binary
  #
  # we have to instruct XS to use the string,
  # else we get '0.00'

  my $fname  = basef  $modpath;
  my $xsname = extwap $fname,'xs';
  my $xspath = "$blddir/$xsname";

  croak "Can't find XS: '$xspath'"
  if ! -f $xspath;

  # ^insert magic line
  { my $body=orc $xspath;
    my $re  =qr{(?<have>
      PROTOTYPES: \s*
      (?:DISABLE|ENABLE) \n

    )}x;

    my $s="VERSIONCHECK: ENABLE\n";
    $body=~ s[$re][$+{have}$s];

    owc $xspath,$body;

  };


  # now we actually have to compile _again_!
  #
  # else we won't be able to load the compiled
  # shared object holding the XSUBS, because
  # XSLoader _will_ version-check that the
  # compiled *.so has the same version string
  # as the module!
  #
  # this wouldn't be necessary, if only Inline
  # allowed passing VERSION...

  lastchk:
  my $soname = extwap $fname,'so';
  my $out    = "$blddir/blib/arch/auto/$dir/$soname";

  if($O{-f} ||! -f $out || moo($out,$modpath)) {
    my $old=getcwd;

    chdir $blddir;
    `perl Makefile.PL && make`;

    chdir $old;

  };

  -f $out or croak "BUILD FAILED: '$fname'";


  # we copy the *.so to where XSLoader can find it
  #
  # this makes it so a module can work _without_
  # Inline ever being invoked...

  my $dst=Shb7::libdir(
    parof($modpath,i=>1,abs=>0)

  );


  rename $out,"$dst/$soname";
  return;

};


# ---   *   ---   *   ---
# ^fetches

sub load($name) {

  # get version
  no strict 'refs';
  my $version=sane_version ${"$name\::VERSION"};

  # get path to package
  my $fname = pkg_to_fname $name;
  my $dir   = based $fname;
  my $full  = "$ENV{ARPATH}/lib/$dir/";


#  # set include path?
#  my $inc=exists $INC{$fname};
#  if(! $inc) {
#    $INC{$fname}=$full;
#    unshift @INC,$full;
#
#  };


  # get *.so
  XSLoader::load($name,$version);

#  # clear include path?
#  if(! $inc) {
#    shift  @INC;
#    delete $INC{$fname};
#
#  };


  return;

};


# ---   *   ---   *   ---
# dirty monkeypatch

sub makelib($class,$pkg,$libref) {

  # get make deps
  cload qw(
    Shb7::Path
    Emit::Perl

  );

  cload $pkg;


  # read module
  my $modpath = pkg_to_fname $pkg;
  my $name    = extcl based  $modpath;
  my $body    = orc          $modpath;

  # ^now destroy it
  no strict 'refs';
  my $tmp=Emit::Perl->codewrap(
    author  => ${"$pkg\::AUTHOR"},
    version => ${"$pkg\::VERSION"},

    body    => [
      \&Emit::Perl::shwlbind => [
        [$pkg => $name => $libref]

      ],

    ],

  );

say {*STDERR} "$modpath => $name => (\n",
  "$body\n\n) => C\::q[",
  "$tmp\n\n];";

  # ^write the module and run it
  # ^yes
  my $tmpf=Shb7::Path::ctrash() . '_Inline/tmp.pm';

#  owc $tmpf,"$tmp\n1;";

#  my $catch=`perl $tmpf`;

  # ^all good?
#  croak "Build error: '$catch'"
#  if length $catch;

#  # ^then overwrite AGAIN
#  owc $modpath,$body;


  return;

};


# ---   *   ---   *   ---
1; # ret
