#!/usr/bin/perl
# ---   *   ---   *   ---
# SPIDER
# webspinner :D
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::spider;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);
  use Type qw(typefet is_signed);

  use Arstd::String qw(
    cat
    strip
    gstrip
    gsplit
    cjag
  );
  use Arstd::Path qw(extwap);
  use Arstd::Bin qw(
    moo
    orc
    owc
    borc64
    bash
    shank64
  );
  use Ftype::Text::JS;
  use Ftype::Text::CSS;
  use Ftype::Text::HTML;

  use lib "$ENV{ARPATH}/lib/";
  use AR;


# ---   *   ---   *   ---
# info

  my $VERSION = "v0.00.4a";
  my $AUTHOR  = "IBN-3DILA";


# ---   *   ---   *   ---
# entry point

sub crux {
  # recompile *.c if necessary
  my $src=shift;
  my $wat=$src;
  extwap($wat,"wat");
  owc($wat,AR::run(
    "avto::spider::compile",
    $src

  )) if moo($wat,$src);

  # recompile *.wat file if necessary
  my $obj=$src;
  extwap($obj,"wasm");

  bash wat2wasm=>$wat,-o=>$obj
  if moo($obj,$src);

  # generate *.js glue
  my $dst=$src;
  extwap($dst,"js");

  my $exe  = borc64($obj);
  my $glue = qq[
async function wasmd(raw) {
  const exe  = atob(raw);
  const exeb = new Uint8Array(exe.length);
  for(let i=0;i < exe.length;++i) {
    exeb[i]=exe.charCodeAt(i);
  };
  return WebAssembly.instantiate(exeb.buffer);
};
window.test=await wasmd("$exe");
];

  # ^ make CSP hash for the glue code, so that
  #   we can run this as an inline (it's easier...)
  my $hash=csphash($glue);
  $glue .= "#spacecat CSP_HASH '$hash'\n";

  owc($dst,$glue);

  # write output to test environ; we'll remove
  # this later once the compiler-writing phase
  # is complete...
  my $nbuild = "avto\::nbuild";
  my $html   = "./test/scratch.html";
  my $out    = "$ENV{ARPATH}/YES/out.html";
  AR::run($nbuild=>$html=>-b=>$out);

  return;
};
sub csphash {"sha256-" . shank64($_[0])};


# ---   *   ---   *   ---
# ret

($0 eq __FILE__) ? crux @ARGV : 1 ;
