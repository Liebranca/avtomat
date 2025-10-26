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
# lib,

# ---   *   ---   *   ---
# deps

package Cli;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG $POSTMATCH $MATCH);

  use lib "$ENV{ARPATH}/lib/";
  use AR sys=>qw(
    use Style::(null);
    use Chk::(is_null);
    lis Arstd::Re::(eiths);
  );

  use Arstd::throw;
  use parent 'St';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.02.3';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# getters

sub order($self) {return @{$self->{-order}}};
sub next_arg($self) {
  return shift @{$self->{-argv}};

};


# ---   *   ---   *   ---
# frame constructor
#
# TODO: reserve -bat,--batch_file
# TODO: ^handle this special case

sub new($class,@args) {

  my @order=();
  my %optab=();
  my %alias=();

  # unpack
  for my $ref(@args) {

    my (

      $id,
      $short_form,
      $long_form,
      $argc,
      $default

    )=(

      $ref->{id},
      $ref->{short},
      $ref->{long},
      $ref->{argc},
      $ref->{default},

    );


    # save id and make arg instance
    push @order,$id;
    my $arg=Cli::Arg->new(
      $id,

      short_form => $short_form,
      long_form  => $long_form,
      argc       => $argc,
      default    => $default,

    );

    $optab{$id}=$arg;


    # make aliases
    $alias{$arg->{short_form}} = $id;
    $alias{$arg->{long_form}}  = $id;

  };


  # make new instance
  my $cli=bless {
    -name  => (caller)[1],
    -order => \@order,
    -optab => \%optab,
    -alias => \%alias,
    -re    => re_eiths([keys %alias]),
    -argv  => [],

  },$class;


  # fill out status vars
  for my $id($cli->order) {
    my $default=$cli->{-optab}->{$id}->{default};
    $cli->{$id}=(defined $default)
      ? $default
      : null
      ;

  };


  return $cli;

};


# ---   *   ---   *   ---
# debug print

sub prich($self) {
  for my $id($self->order) {
    my $value=$self->{$id};
    printf {*STDOUT} (
      "%-21s %-21s\n",
      $id,$value

    );

  };


  return;

};


# ---   *   ---   *   ---
# get form used by arg

sub short_or_long($self,$arg) {
  my $value=null;

  # catch invalid
  if($arg=~ s/$self->{-re}//) {
    my $post = $POSTMATCH;
    my $pre  = $MATCH;

    $value = $post if ! is_null $post;
    $arg   = $pre;

  };


  # catch invalid
  throw sprintf(
    "%s: invalid option '%s'\n",
    $self->{-name},
    $arg,

  ) if ! exists $self->{-alias}->{$arg};


  # take input
  my $id     = $self->{-alias}->{$arg};
  my $option = $self->{-optab}->{$id};

  if($option->{argc} && $value eq null) {
    $value=$self->next_arg;

  } elsif(! $option->{argc} && $value eq null) {
    $value=1;

  };

  # TODO: validate input
  if($option->{argc} eq 'array') {
    push @{$self->{$id}},$value;

  } else {
    $self->{$id}=$value;

  };


  return;

};


# ---   *   ---   *   ---
# --option=value

sub long_equal($self,$arg) {
  my $value=null;
  ($arg,$value)=split m/=/,$arg;

  # catch invalid
  throw sprintf(
    "%s: invalid option '%s'\n",
    $self->{-name},
    $arg,

  ) if ! exists $self->{-alias}->{$arg};


  # take input
  my $id     = $self->{-alias}->{$arg};
  my $option = $self->{-optab}->{$id};

  if(! $option->{argc}) {
    throw sprintf(
      "Argument '%s' for program '%s' "
    . "doesn't take a value",

      $id,
      $self->{-name},

    );

    $self->{$id}=1;


  } else {
    $self->{$id}=$value;

  };

  return;

};


# ---   *   ---   *   ---
# ROM

St::vconst {
  PATTERN=>[
    qr{--[_\w][_\w\d]*=} => \&long_equal,
    qr{--[_\w][_\w\d]*}  => \&short_or_long,
    qr{-[_\w].*}         => \&short_or_long,

  ],

};


# ---   *   ---   *   ---
# reads input

sub take($self,@args) {
  $self->{-argv}=\@args;

  my @values = ();
  my $arg_re = $self->PATTERN;

  while(@{$self->{-argv}}) {
    my $arg = shift @{$self->{-argv}};
    my $fn  = undef;
    my $x   = 0;

    while($x < @$arg_re-1) {

      my $pat=$arg_re->[$x];

      if($arg=~ m/^${pat}$/) {
        $fn=$arg_re->[$x+1];
        last;

      };

      $x+=2;

    };


    if(defined $fn) {
      $fn->($self,$arg);

    } else {
      push @values,$arg;

    };


  };


  return @values;

};


# ---   *   ---   *   ---
1; # ret


# ---   *   ---   *   ---
# utility class: commandline arguments

package Cli::Arg;
  use v5.42.0;
  use strict;
  use warnings;


# ---   *   ---   *   ---
# cstruc

sub new($class,$id,%attrs) {

  # set defaults
  $attrs{short_form} //= q{-}.substr $id,0,1;
  $attrs{long_form}  //= q{--}.$id;
  $attrs{argc}       //= 0;
  $attrs{default}    //= undef;

  # make ice
  my $arg=bless {id=>$id,%attrs},$class;

  return $arg;

};


# ---   *   ---   *   ---
# utility class: common file walking

package Cli::Fstruct;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/";
  use AR sys=>qw(
    use Style::(null);
    lis Arstd::Path::(expand);

  );

  use parent 'St';


# ---   *   ---   *   ---
# ROM

St::vconst {
  ATTRS=>[
    {id=>'recursive'},
    {id=>'symbol',argc=>1},
    {id=>'no_escaping',short=>'-ne'},
    {id=>'regex',short=>'-R'},
    {id=>'extension',short=>'-xt',argc=>1},

  ],

};


# ---   *   ---   *   ---
# whenever you're looking for things
# across a (possible) multitude of files

sub proto_search($m,@cmd) {

  # default to commandline args
  @cmd=@ARGV if ! @cmd;

  # ^parse options
  my @files=$m->take(@cmd);


  # dig into the folders?
  @files=map {path_expand $ARG,-r=>1} @cmd
  if $m->{recursive} ne null;


  # enable/disable auto-backslashing
  if($m->{no_escaping} eq null) {
    $m->{symbol}="\Q$m->{symbol}";

  } else {
    $m->{symbol}=~ s/\$/\\\$/sg;

  };


  # enable/disable symbol as regex
  if($m->{regex} eq null) {
    $m->{symbol}=qr{$m->{symbol}(?:\b|$|"|')};

  } else {
    $m->{symbol}=qr{$m->{symbol}}x;

  };


  # set extension filter?
  if($m->{extension} eq null) {
    $m->{ext_re}=qr{\..*$}x;

  } else {
    $m->{ext_re}=qr{\.(?:$m->{extension})$}x;

  };


  return @files;

};


# ---   *   ---   *   ---
# ^expands filepaths

sub proto_search_ex($m,@cmd) {
  my @out   = ();
  my @files = Cli::Fstruct::proto_search($m,@cmd);

  while(@files) {
    my $f=shift @files;

    if(-d $f) {
      path_expand($f,\@files);
      next;

    };

    next if ! ($f=~ $m->{ext_re});
    push @out,$f;

  };

  return @out;

};


# ---   *   ---   *   ---
1; # ret
