#!/usr/bin/perl
# ---   *   ---   *   ---
# MAM
# Filtered source emitter
#
# do not use in scripts;
# call it like so:
#
# perl -MMAM=[opts]
#
# ---   *   ---   *   ---
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package MAM;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use Cwd qw(abs_path);

  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;
  use Cli;
  use Arstd::Repl;
  use Arstd::IO;

  use parent 'SourceFilter';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.2a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

St::vconst {

  OPTIONS=>[
    {id=>'module',short=>'-M',argc=>1},
    {id=>'no_comments',short=>'-nc'},
    {id=>'no_print',short=>'-np',},

    {id=>'rap'},
    {id=>'line_numbers',short=>'-ln'},

  ],

  USE_RE=>qr{

    \s* use \s+ lib \s+

    "? \$ENV\{

    [\s'"]* ARPATH
    [\s'"]* \}

    [\s'"\.]* /

    (?<root> lib|.trash)
    (?<path> [^;]+)

    ['"] \s* ;


  }x,

};


# ---   *   ---   *   ---
# global state

  my $O={};


# ---   *   ---   *   ---
# adds/removes build directory
#
# we do this so that a module can
# import the built version of others
# _during_ the build process...

sub repv($repl,$uid) {

  my $module = $O->{module};
  my $have   = $repl->{capt}->[$uid];
  my $beg    = "\n" . q[  use lib "$ENV{ARPATH}];

  my ($root,$path)=(
    $have->{root},
    $have->{path},

  );


  # adding build directory?
  if($O->{rap} ne null) {
    return (
      "$beg/$root/$path\";"
    . "$beg/.trash/$module/$path\";"

    );

  } elsif($root eq '.trash') {
    return null;

  };


  return "$beg/$root/$path\";";

};


# ---   *   ---   *   ---
# cstruc/entry

sub import {

  my ($class,@cmd)=@_;

  $O=Cli->new(@{$class->OPTIONS});
  $O->take(@cmd);

  $O->{module}='avtomat'
  if $O->{module} eq null;

  my ($pkg,$fname,$lineno)=(caller);
  my $self=$class->new($fname,$lineno);

  $self->{repl}=Arstd::Repl->new(
    inre => $class->USE_RE,
    pre  => "USE$class",
    repv => \&repv,

  );


  SourceFilter::filter_add($self);


  return;

};


# ---   *   ---   *   ---
# ^dstruc

sub unimport {
  filter_del();

};


# ---   *   ---   *   ---
# file reader

sub filter {

  my ($self)=@_;
  my ($pkg,$fname,$lineno)=(caller);


  # read file and run textual replacement
  my $body=orc $self->{fname};
  $self->{repl}->proc(\$body);
  $self->{repl}->clear();


  # give line numbers?
  if($O->{line_numbers} ne null) {
    my $x=1;
    $body=join null,map {
      sprintf "%4i %s\n",$x++,$ARG;

    } split $NEWLINE_RE,$body;

  };


  # print out?
  say $body if $O->{no_print} eq null;


  return 0;

};


# ---   *   ---   *   ---
1; # ret
