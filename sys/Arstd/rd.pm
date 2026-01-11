#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD RD
# here we go again...
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::rd;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null nop);
  use Chk qw(is_file is_null);
  use Arstd::String qw(strip gsplit);
  use Arstd::Bin qw(orc);
  use Arstd::strtok qw(strtok unstrtok);
  use Arstd::throw;

  use lib "$ENV{ARPATH}/lib/";
  use AR;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(rd);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# entry point

sub rd {
  my $s=$_[0];
  return null if ! strip($s);

  if(is_file($s)) {
    my $body=orc($s);
    return rd_impl($body);
  };
  return rd_impl($s);
};
sub rd_impl {
  my ($pproc,$class,@param)=fline_proc($_[0]);
  my @tree=$class->rd($_[0],@param);

  return $pproc->(@tree);
};


# ---   *   ---   *   ---
# processes first peso expression,
# which is simply a sigil and classname:
#
# * sigil identifies a preprocessor
# * class identifies a parser

sub fline_proc {
  my ($sigil,$class,@param)=fline_rd($_[0]);

  # get pproc (nothing for now)
  my $tab={
    '%'=>sub {return @_},
  };
  my $pproc=$tab->{$sigil}
  or throw "BADTYPE '$sigil'";

  # get package from class name...
  my $pkg=AR::pkgfind($class=>qw(
    Ftype::Text
    Ftype
  ));
  throw "\nrd: cannot find package for '$class'"
  if is_null($pkg);

  # ^load it and give
  @param=AR::reload($pkg,@param);
  return ($pproc,$pkg,@param);
};


# ---   *   ---   *   ---
# ^parse it ;>

sub fline_rd {
  my $re=qr{^\s*
    (?<sigil>[^[:alnum:]])
    (?<class>[^;]*?)
  ;\s*}x;

  throw "NO FLINE" if! ($_[0]=~ s[$re][]);
  return (
    $+{sigil},
    gsplit($+{class}),
  );
};


# ---   *   ---   *   ---
# RET
