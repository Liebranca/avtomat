#!/usr/bin/perl
# ---   *   ---   *   ---
# AVT XCAV
# Divorces symscan from
# mainline Avt
#
# ie, this file exists solely
# to avoid a dependency cycle
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Avt::Xcav;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Storable;
  use Carp;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::IO;

  use Shb7;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;

  use Lang;
  use Lang::C;
  use Lang::Perl;
  use Lang::Peso;

  use Emit::C;
  use Emit::Perl;

  use Peso::Rd;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# looks at a single file for symbols

sub file_sbl($f) {

  my $found='';
  my $langname=Lang::file_ext($f);

  if(!defined $langname) {

    errout(

      q{Can't determine language for file '%s'},
      args=>[$f],
      lvl=>$AR_FATAL,

    );

  };

# ---   *   ---   *   ---

  my $object={

    utypes=>{},

    functions=>{},
    variables=>{},
    constants=>{},

  };

# ---   *   ---   *   ---
# read source file

  my $lang=Lang->$langname;

  my $rd=Peso::Rd::parse(
    $lang,$f

  );

  my $block=$rd->select_block(-ROOT);
  my $tree=$block->{tree};

  $rd->recurse($tree);
  $lang->hier_sort($rd);

# ---   *   ---   *   ---
# mine the tree

  $rd->fn_search(

    $tree,
    $object->{functions},

  );

  $rd->utype_search(

    $tree,
    $object->{utypes},

  );

  return $object;

};

# ---   *   ---   *   ---
# in:modname,[files]
# write symbol typedata (return,args) to shadow lib

sub symscan($mod,$dst,$deps,@fnames) {

  Shb7::push_includes(
    Shb7::dir($mod)

  );

  my @files=();

# ---   *   ---   *   ---
# iter filelist

  { for my $fname(@fnames) {

      if( ($fname=~ m/\%/) ) {
        push @files,@{ Shb7::wfind($fname) };

      } else {
        push @files,Shb7::ffind($fname);

      };

    };

  };

# ---   *   ---   *   ---

  my $shwl={

    deps=>$deps,
    objects=>{},

  };

# ---   *   ---   *   ---
# iter through files

  for my $f(@files) {

    next if !$f;

    my $o=Shb7::obj_from_src($f);
    $o=Shb7::shpath($o);

    $shwl->{objects}->{$o}=file_sbl($f);

  };

  store($shwl,$dst) or croak strerr($dst);

};

# ---   *   ---   *   ---
1; # ret
