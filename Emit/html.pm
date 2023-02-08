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
# lyeb,

# ---   *   ---   *   ---
# deps

package Emit::html;

  use v5.36.0;
  use strict;
  use warnings;

  use version;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Path;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Emit::Std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

  our $ICON    = "./data/favicon.png";

# ---   *   ---   *   ---

  Readonly my $HEAD_BOILER=>q[

<meta charset="UTF-8">

<meta
  name    = "viewport"
  content = "width=device-width"
  content = "initial-scale=1.0"

>

<meta
  http-equiv = "X-UA-Compatible"
  content    = "ie=edge"

>

];

# ---   *   ---   *   ---

sub comment($ct) {
  return "<!--$ct-->";

};

# ---   *   ---   *   ---

sub tag($name,%O) {

  $O{-cl}//=0;
  $O{-ct}//=$NULLSTR;

  my $cl=$O{-cl};
  my $ct=$O{-ct};

  delete $O{-cl};
  delete $O{-ct};

  my @props = ();
  for my $key(keys %O) {
    push @props,"  $key=$O{$key}";

  };

# ---   *   ---   *   ---

  my $props  = join "\n",@props;
  $props     = "\n$props\n" if @props;

  my @lines  = split $NEWLINE_RE,$ct;
  for my $line(@lines) {
    $line=q[  ].$line;

  };

# ---   *   ---   *   ---

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

sub header() {

  my ($pkg,$file)=caller();

  no strict 'refs';
    my $version = ${"$pkg\::VERSION"};
    my $author  = ${"$pkg\::AUTHOR"};
    my $icon    = ${"$pkg\::ICON"};
    my $style   = ${"$pkg\::STYLE"};

    $version  //= v0.00.1;
    $author   //= 'anon';
    $icon     //= $ICON;
    $style    //= './styles/default.css';

    $version    = version::->parse($version);

  use strict 'refs';

# ---   *   ---   *   ---

  my $out=tag('meta',
    version => $version,
    author  => "\"$author\"",

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
    $author,$NULLSTR

  ))."\n".$out;

};

# ---   *   ---   *   ---

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

