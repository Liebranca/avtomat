#!/usr/bin/perl
# ---   *   ---   *   ---
# CLI
# Command line utils
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package cli;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/';
  use style;
  use arstd;
  use lang;

# ---   *   ---   *   ---
# getters

sub order($self) {return @{$self->{order}}};

sub next_arg($self) {
  return shift @{$self->{argv}};

};

# ---   *   ---   *   ---
# frame constructor
# TODO: reserve -bat,--batch_file
# TODO: ^handle this special case

sub nit(@args) {

  my @order=();
  my %optab=();
  my %alias=();

# ---   *   ---   *   ---
# unpack

  for my $ref(@args) {
    my (

      $id,
      $short_form,
      $long_form,
      $argc,

    )=(

      $ref->{id},
      $ref->{short},
      $ref->{long},
      $ref->{argc},

    );

# ---   *   ---   *   ---
# save id and create arg instance

    push @order,$id;
    my $arg=cli::arg::nit(

      $id,

      short_form=>$short_form,
      long_form=>$long_form,
      argc=>$argc,

    );

    $optab{$id}=$arg;

# ---   *   ---   *   ---
# create aliases

    $alias{$arg->{short_form}}=$id;
    $alias{$arg->{long_form}}=$id;

  };

# ---   *   ---   *   ---
# create new instance

  my $cli=bless {

    name=>(caller)[1],

    order=>\@order,
    optab=>\%optab,
    alias=>\%alias,

    re=>lang::hashpat(\%alias,1,1),

    argv=>[],

  },'cli';

# ---   *   ---   *   ---
# fill out status vars

  for my $id($cli->order) {
    $cli->{$id}=$NULL;

  };

  return $cli;

};

# ---   *   ---   *   ---
# debug print

sub prich($self) {

  for my $id($self->order) {
    my $value=$self->{$id};

    printf {*STDOUT}

      "%-21s %-21s\n",
      $id,$value

    ;

  };

};

# ---   *   ---   *   ---

sub short_or_long($self,$arg) {

  my $value=$NULL;

# ---   *   ---   *   ---
# catch invalid

  if($arg=~ s/$self->{re}//) {

    $value=(defined $' && length $') ? $' : $NULL;
    $arg=$&;

  };if(!exists $self->{alias}->{$arg}) {

    arstd::errout(
      "%s: invalid option '%s'\n",

      args=>[$self->{name},$arg],
      lvl=>$FATAL,

    );

  };

# ---   *   ---   *   ---

  my $id=$self->{alias}->{$arg};
  my $option=$self->{optab}->{$id};

# ---   *   ---   *   ---

  if($option->{argc} && $value eq $NULL) {
    $value=$self->next_arg;

  } elsif(!$option->{argc} && $value eq $NULL) {
    $value=1;

  };

  $self->{$id}=$value;
  return;

};

# ---   *   ---   *   ---

sub long_equal($self,$arg) {

  my $value=$NULL;
  ($arg,$value)=split m/=/,$arg;

# ---   *   ---   *   ---
# catch invalid

  if(!exists $self->{alias}->{$arg}) {

    arstd::errout(
      "%s: invalid option '%s'\n",

      args=>[$self->{name},$arg],
      lvl=>$FATAL,

    );

  };

# ---   *   ---   *   ---

  my $id=$self->{alias}->{$arg};
  my $option=$self->{optab}->{$id};

# ---   *   ---   *   ---

  if(!$option->{argc}) {

    arstd::errout(
      "Argument '%s' for program '%s' ".
      "doesn't take a value",

      args=>[$id,$self->{name}],
      lvl=>$WARNING,

    );

    $self->{$id}=1;

# ---   *   ---   *   ---

  } else {
    $self->{$id}=$value;

  };

  return;

};

# ---   *   ---   *   ---
# ROM

  Readonly my $PATTERN=>[
    qr{--[_\w][_\w\d]*=}=>\&long_equal,
    qr{--[_\w][_\w\d]*}=>\&short_or_long,
    qr{-[_\w][_\w\d]*}=>\&short_or_long,

  ];

# ---   *   ---   *   ---

sub take($self,@args) {

  $self->{argv}=\@args;

  my @values=();;

  while(@{$self->{argv}}) {

    my $arg=shift @{$self->{argv}};
    my $fn=undef;

# ---   *   ---   *   ---

    my $x=0;
    while($x<@$PATTERN-1) {

      my $pat=$PATTERN->[$x];

      if($arg=~ m/${pat}/) {
        $fn=$PATTERN->[$x+1];
        last;

      };$x+=2;
    };

# ---   *   ---   *   ---

    if(defined $fn) {
      $fn->($self,$arg);

    } else {
      push @values,$arg;

    };

# ---   *   ---   *   ---

  };

  return @values;

};

# ---   *   ---   *   ---
1; # ret

# ---   *   ---   *   ---
# utility class: commandline arguments

package cli::arg;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# constructor

sub nit($id,%attrs) {

  # set defaults
  $attrs{short_form}//=q{-}.substr $id,0,1;
  $attrs{long_form}//=q{--}.$id;
  $attrs{argc}//=0;

  # create new instance
  my $arg=bless {id=>$id,%attrs},'cli::arg';

  return $arg;

};

# ---   *   ---   *   ---
