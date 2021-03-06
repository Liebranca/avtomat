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

  use Cwd qw(abs_path);

  use lib $ENV{'ARPATH'}.'/lib/hacks/';

  use parent 'lyfil';
  use shwl;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use style;
  use arstd;
  use cli;

  use Filter::Util::Call;

# ---   *   ---   *   ---
# ROM

  Readonly my $OPTIONS=>[

    {id=>'module',short=>'-M',argc=>1},
    {id=>'no_comments',short=>'-nc'},
    {id=>'no_print',short=>'-np',},

    {id=>'make_deps',short=>'-md'},

    {id=>'rap'},
    {id=>'line_numbers',short=>'-ln'},

  ];

# ---   *   ---   *   ---
# global state

  my $SETTINGS={};

# ---   *   ---   *   ---

sub import {

  my @opts=@_;

  $SETTINGS=cli::nit(@$OPTIONS);
  $SETTINGS->take(@opts);

  if($SETTINGS->{module} eq $NULL) {
    $SETTINGS->{module}='avtomat';

  };

  my ($pkg,$fname,$lineno)=(caller);
  my $self=lyfil::nit($fname,$lineno);

  filter_add($self);

};

# ---   *   ---   *   ---

sub unimport {
  filter_del();

};

# ---   *   ---   *   ---

sub filter {

  my ($self)=@_;

  my ($pkg,$fname,$lineno)=(caller);
  my $status=filter_read();

  $self->logline(\$_);

  if(!$status) {

    $self->propagate();
    shwl::stitch(\$self->{chain}->[0]->{raw});

# ---   *   ---   *   ---

    my $modname=$SETTINGS->{module};
    if($SETTINGS->{rap}!=$NULL) {


      $self->{raw}=~ s{

        \{'ARPATH'\}[.]'/lib

      } {\{'ARPATH'\}.'/.trash/$modname}sxg;

# ---   *   ---   *   ---

    } else {

      $self->{raw}=~ s{

        \{'ARPATH'\}

        [.]

        '/.trash/${modname}

      } {\{'ARPATH'\}.'/lib}sxg;

    };

# ---   *   ---   *   ---

    if($SETTINGS->{line_numbers}!=$NULL) {

      my $x=1;
      my $whole='';

      for my $line(split m/\n/,$self->{raw}) {
        $whole.=sprintf "%4i %s\n",$x++,$line;

      };

      $self->{raw}=$whole;

    };

# ---   *   ---   *   ---

    if($SETTINGS->{no_print}==$NULL) {
      $self->prich();

    };

# ---   *   ---   *   ---
# emit dependency files

    if($SETTINGS->{make_deps}!=$NULL) {

      my $deps=$shwl::DEPS_STR;
      my $re=abs_path(glob(q{~}));

      $re=qr{$re};
      $deps.="$self->{fname}\n";

      for my $path(values %INC) {
        if($path=~ $re) {

          my $alt=$path;
          $alt=~ s{/lib/} {/.trash/$modname/};

          if(-e $alt) {$path=$alt};
          $deps.=$path.q{ };

        };

      };

      $deps.=$shwl::DEPS_STR;
      print $deps;

    };

# ---   *   ---   *   ---

  };

  return $status;

};

# ---   *   ---   *   ---
1; # ret
