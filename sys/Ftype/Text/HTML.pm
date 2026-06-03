#!/usr/bin/perl
# ---   *   ---   *   ---
# HTML
# is this programming?? :o
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text::HTML;
  use v5.42.0;
  use strict;
  use warnings;

  use lib "$ENV{ARPATH}/lib/sys/";
  use parent "Ftype::Text";

  use Ftype::Text::JS;
  use Ftype::Text::CSS;
  use Arstd::seq qw(seqnew);


# ---   *   ---   *   ---
# info

  our $VERSION = "v0.00.2a";
  our $AUTHOR  = "IBN-3DILA";


# ---   *   ---   *   ---
# make ice

sub mlcom_t {
  return seqnew(
    beg   => "<!--",
    end   => "-->",

    Arstd::seq::comattr(),
  );
};
sub classattr {return {
  name => "web",
  com  => "<!--|-->",
  ext  => "\.(?:wmd|html)\$",
  hed  => "\%web;",
  mag  => "DIGITAL MAGICK",

  highlightup=>[
    qr{<[^>[:space:]]+}    => 0x04,
    qr{\$:[^;>[:space:]]+} => 0x04,
    qr{^#.*}               => 0x03,
    qr{^(=+|-+)$}          => 0x03,
  ],
}};
sub strtok_syx {
  return [
    # comments
    mlcom_t(),

    # strings
    Arstd::seq::str()->{squote},
    Arstd::seq::str()->{dquote},

    # preprocessor /YES
    Arstd::seq::pproc()->{c},
  ];
};


# ---   *   ---   *   ---
# ~~

sub package_open {
  my ($class,$name)=@_;
  return (
    q[<script type="module">],
    Ftype::Text::JS->package_open($name),
  );
};

sub package_close {
  my ($class,$dst,$sref,$name,$flg)=@_;
  return (
    Ftype::Text::JS->package_close(
      $dst,
      $sref,
      $name,
      $flg
    ),
    q[</script>],
  );
};


# ---   *   ---   *   ---
1; # ret
