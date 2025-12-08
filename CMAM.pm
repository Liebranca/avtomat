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

package CMAM;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);
  use Cwd qw(getcwd);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file);
  use Arstd::String qw(gsplit to_char has_prefix);
  use Arstd::Array qw(dupop);
  use Arstd::Bin qw(ot moo orc owc);
  use Arstd::Path qw(dirof relto absto to_pkg);
  use Arstd::Re qw(eiths);
  use Arstd::throw;
  use Log;
  use Tree;
  use Tree::Dep;

  use lib "$ENV{ARPATH}/lib/";
  use CMAM::static;
  use CMAM::parse qw(blkparse);
  use CMAM::macro;
  use CMAM::sandbox;
  use CMAM::emit;


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
# entry point

sub run {
  # get dependencies required by *this* program
  my $deps=CMAM::static::exedeps();
  %$deps=map {to_pkg($ARG);$ARG=>1} keys %INC;

  # expand asterisks, dots and tildes to
  # get full file list
  my @have=map {
    (! has_prefix($ARG,'-'))
      ? (glob($ARG))
      : ($ARG)
      ;

  } @_;

  # now process all files
  return map {
    validate($ARG);
    restart();
    pproc($ARG);

  } @have;
};


# ---   *   ---   *   ---
# validate input
#
# [0]: byte pptr ; file list

sub validate {
  throw "CMAM: no files" if ! @_;
  for(@_) {
    throw "Invalid file: '$ARG'"
    if ! is_file $ARG;
  };
  return;
};


# ---   *   ---   *   ---
# sort list of files according to
# who depends on who

sub depsort {
  my $module=shift;

  # find which packages a file depends on
  my %dep  = map {depsort_file($ARG)} @_;
  my $tree = Tree::Dep->new("dep");

  # ^ if a file is mentioned by another,
  #   then expand it to also include
  #   the dependencies of the mentioned file
  my @lv=();
  for my $fname(keys %dep) {
    my $re=$fname;
    relto $re,getcwd . "/$module";

    my $nd=$tree->new($re);
    push @lv,$nd;

    $re=qr{$re$};
    my $need=$dep{$fname};

    for my $ar(values %dep) {
      push @$ar,@$need
      if int grep {$ARG=~ $re} @$ar;
    };
    my $ch=$nd->new(null);
    $ch->{value}=$need;
  };

  my $file_re=eiths(
    [$tree->branch_values()],
    opscape=>1,
  );

  for my $nd(@lv) {
    my ($ch) = $nd->pluck_all();
    my $ar   = $ch->{value};

    # exclude files not within this project
    # then clear duplicates JIC
    @$ar=grep {$ARG=~ $file_re} @$ar;
    dupop($ar);

    $nd->append($ARG) for @$ar;
  };

  my $out=$tree->track();
  absto($ARG,getcwd . "/$module") for @$out;

  return @$out;
};


# ---   *   ---   *   ---
# get dependencies for single file
#
# [0]: byte ptr  ; module name
# [<]: byte pptr ; dependency list (new array)

sub depsort_file {
  my $dcolon_re=qr{::};
  my $use_re=qr{^\s*(?:public\b\s+)?
    use \s+
    (?:(?:PM|pm|C|c)\s+)?
    ([[:alnum:]:_]+) [^;]*;
  }smx;

  my $body = orc $_[0];
  my @out  = ();

  while($body=~ s[$use_re][]) {
    my $have=  $1;
       $have=~ s[$dcolon_re][/]g;

    if($have=~ qr{^cmam$}) {
      $have="SWAN/cmacro";
    };
    push @out,"$have.c";
  };
  return $_[0] => \@out;
};


# ---   *   ---   *   ---
# ^ make it so updates to CMAM itself trigger
#   a recompilation of C files!

sub outdeps {
  my $fname = __FILE__;
  my $dir   = dirof($fname);
  return (
    $fname,
    glob("$dir/CMAM/*.pm"),
  );
};


# ---   *   ---   *   ---
# generates header, source and perl files
# from a single C source file
#
# [0]: byte ptr ; filename

sub pproc {
  my $rel=$_[0];
  relto($rel);

  # read file and pass through block parser
  my $body=orc $_[0];
  $body=blkparse($body);

  # last step is checking for exported symbols
  my $perl=CMAM::emit::pm();
  my $head=CMAM::emit::chead($rel,$body);

  # give arrayref with generated code
  return [$head,$body,$perl];
};


# ---   *   ---   *   ---
# triggers reset of global state,
# then sets symbol table to builtins only

sub restart {
  CMAM::static::restart();
  my $tab  = CMAM::static::cmamdef();
  my $spec = CMAM::macro::spec();

  $tab->{package}={
    fn  => \&CMAM::macro::setpkg,
    flg => $spec->{top},
  };
  $tab->{use}={
    fn  => \&CMAM::sandbox::usepkg,
    flg => $spec->{top},
  };
  $tab->{macro}={
    fn  => \&CMAM::macro::macro,
    flg => $spec->{top},
  };

  return;
};


# ---   *   ---   *   ---
1; # ret
