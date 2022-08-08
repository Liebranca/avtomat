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
# lyeb,
# ---   *   ---   *   ---

package MAM;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use English qw(-no_match_vars);
  use Cwd qw(abs_path);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;
  use Cli;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';

  use Shwl;
  use parent 'Lyfil';

# ---   *   ---   *   ---
# ROM

  Readonly my $OPTIONS=>[

    {id=>'module',short=>'-M',argc=>1},
    {id=>'no_comments',short=>'-nc'},
    {id=>'no_print',short=>'-np',},

    {id=>'rap'},
    {id=>'line_numbers',short=>'-ln'},

  ];

# ---   *   ---   *   ---
# global state

  my $SETTINGS={};

# ---   *   ---   *   ---

sub import {

  my @opts=@_;

  $SETTINGS=Cli->nit(@$OPTIONS);
  $SETTINGS->take(@opts);

  if($SETTINGS->{module} eq $NULL) {
    $SETTINGS->{module}='avtomat';

  };

  my ($pkg,$fname,$lineno)=(caller);
  my $self=MAM->nit($fname,$lineno);

  $self->filter_add($self);

};

# ---   *   ---   *   ---

sub unimport {
  filter_del();

};

# ---   *   ---   *   ---

sub filter {

  my ($self)=@_;
  my ($pkg,$fname,$lineno)=(caller);

  my $body=Arstd::orc($self->{fname});

  my $modname=$SETTINGS->{module};
  if($SETTINGS->{rap}!=$NULL) {

    $body=~ s{(

      \{'ARPATH'\}[.]'/lib([^;]+)

    )} {$1;
  use lib \$ENV\{'ARPATH'\}.'/.trash/$modname$2}sxg;

# ---   *   ---   *   ---

  } else {

    $body=~ s{

      use \s+ lib \s+ \$ENV

      \{'ARPATH'\}

      [.]

      '/.trash/${modname}[^;]+;

    } {}sxg;

  };

# ---   *   ---   *   ---

  if($SETTINGS->{line_numbers}!=$NULL) {

    my $x=1;
    my $whole='';

    for my $line(split m/\n/,$body) {
      $whole.=sprintf "%4i %s\n",$x++,$line;

    };

    $body=$whole;

  };

# ---   *   ---   *   ---

  if($SETTINGS->{no_print}==$NULL) {
    say $body;

  };

  return 0;

};

# ---   *   ---   *   ---
1; # ret
