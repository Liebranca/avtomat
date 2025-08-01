#!/usr/bin/perl
# ---   *   ---   *   ---
# EMIT HTML
# Utils for printing
# html docs
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Emit::html;
  use v5.42.0;
  use strict;
  use warnings;

  use English;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;
  use Arstd::String qw(sqwrap);

  use lib "$ENV{ARPATH}/lib/";
  use Emit::Std;

  use parent 'St';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

my $DEFAULT=__PACKAGE__;
St::vconst {

  HEAD_BOILER=>q[
<meta charset="UTF-8">
<meta
  name    = "viewport"
  content = "width=device-width"
  content = "initial-scale=1.0"

>
<meta
  http-equiv = "X-UA-Compatible"
  content    = "ie=edge"

>],

  ICON  => './data/favicon.png',
  STYLE => './styles/default.css',

};


# ---   *   ---   *   ---
# the ONE thing I *actually* disike
# about html ;>

sub comment($ct) {return "<!--$ct-->"};


# ---   *   ---   *   ---
# wrap <name> and set <name attrs=value>

sub tag($name,%O) {
  $O{-cl}//=0;
  $O{-ct}//=null;

  my $cl=$O{-cl};
  my $ct=$O{-ct};

  delete $O{-cl};
  delete $O{-ct};

  my @props=map{
    "  $ARG=$O{$ARG}"

  } keys %O;


  my $props = join "\n",@props;
     $props = "\n$props\n" if @props;

  my @lines = map {
    "  $line";

  } split $NEWLINE_RE,$ct;


  $ct=join "\n",@lines;
  $ct="\n$ct\n\n" if length $ct;

  return (!$cl)
    ? "<$name$props>$ct\n\n"
    : "<$name$props>$ct</$name>\n\n"
    ;

};


# ---   *   ---   *   ---
# creates quick header with
# boiler from *.pm vars

sub header {
  my ($pkg,$file)=caller();

  # get version data from pkg
  no strict 'refs';
  my $version   = ${"$pkg\::VERSION"};
  my $author    = ${"$pkg\::AUTHOR"};
     $version //= 'v0.00.1a';
     $author  //= 'anon';

  use strict 'refs';

  # ^further data should be declared
  # ^through St::vconst
  my $icon=($pkg->can('ICON')
    ? $pkg->ICON
    : $DEFAULT->ICON
    ;

  my $style=($pkg->can('STYLE')
    ? $pkg->STYLE
    : $DEFAULT->STYLE
    ;


  # make header tags
  my $out=tag('meta',
    version => sqwrap($version),
    author  => sqwrap($author),

  );

  $out.=tag('title',
    -cl=>1,
    -ct=>nxbasef($file),

  );

  $out.=tag('link',
    rel  => "icon",
    type => "image/png",

    href => $icon,

  );

  $out.=tag('link',
    rel  => "stylesheet",
    href => $style,

  );

  $out=tag('head',
    -ct=>"$out$HEAD_BOILER",
    -cl=>1

  );

  return comment(Emit::Std::note(
    $author,null

  )) . "\n$out";

};


# ---   *   ---   *   ---
# makes bulletpoints

sub ulist(@ar) {
  my $ct=join "\n",map {
    tag('li',-ct=>$ARG,-cl=>1)

  } @ar;

  return tag('ul',
    -ct=>$ct,
    -cl=>1,

  );

};


# ---   *   ---   *   ---
1; # ret

