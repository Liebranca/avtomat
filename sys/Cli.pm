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

package Cli;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Re;
  use Arstd::IO;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.2.1;
  our $AUTHOR='IBN-3DILA';

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
      : $NULL
      ;

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
# get form used by arg

sub short_or_long($self,$arg) {

  my $value=$NULL;


  # catch invalid
  if($arg=~ s/$self->{-re}//) {

    $value = (defined $' && length $')
      ? $'
      : $NULL
      ;

    $arg   = $&;

  };


  if(! exists $self->{-alias}->{$arg}) {

    errout(
      "%s: invalid option '%s'\n",

      args => [$self->{-name},$arg],
      lvl  => $AR_FATAL,

    );

  };

  my $id     = $self->{-alias}->{$arg};
  my $option = $self->{-optab}->{$id};


  if($option->{argc} && $value eq $NULL) {
    $value=$self->next_arg;

  } elsif(! $option->{argc} && $value eq $NULL) {
    $value=1;

  };

  # TODO: validate this input

  $self->{$id}=$value;
  return;

};

# ---   *   ---   *   ---
# --option=value

sub long_equal($self,$arg) {

  my $value=$NULL;
  ($arg,$value)=split m/=/,$arg;


  # catch invalid
  if(! exists $self->{-alias}->{$arg}) {

    errout(
      "%s: invalid option '%s'\n",

      args => [$self->{-name},$arg],
      lvl  => $AR_FATAL,

    );

  };


  my $id     = $self->{-alias}->{$arg};
  my $option = $self->{-optab}->{$id};


  if(! $option->{argc}) {

    errout(

      "Argument '%s' for program '%s' ".
      "doesn't take a value",

      args=>[$id,$self->{-name}],

    );

    $self->{$id}=1;


  } else {
    $self->{$id}=$value;

  };

  return;

};

# ---   *   ---   *   ---
# ROM

  Readonly my $PATTERN=>[

    qr{--[_\w][_\w\d]*=} => \&long_equal,

    qr{--[_\w][_\w\d]*}  => \&short_or_long,
    qr{-[_\w][_\w\d]*}   => \&short_or_long,

  ];

# ---   *   ---   *   ---
# reads input

sub take($self,@args) {

  $self->{-argv}=\@args;

  my @values=();;

  while(@{$self->{-argv}}) {

    my $arg = shift @{$self->{-argv}};
    my $fn  = undef;


    my $x=0;
    while($x < @$PATTERN-1) {

      my $pat=$PATTERN->[$x];

      if($arg=~ m/${pat}/) {
        $fn=$PATTERN->[$x+1];
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

  use v5.36.0;
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

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Path;

# ---   *   ---   *   ---
# ROM

  Readonly our $ATTRS=>[

    {id=>'recursive'},
    {id=>'symbol',argc=>1},
    {id=>'no_escaping',short=>'-ne'},
    {id=>'regex',short=>'-R'},
    {id=>'extension',short=>'-xt',argc=>1},

  ];

# ---   *   ---   *   ---
# whenever you're looking for things
# across a (possible) multitude of files

sub proto_search($m,@cmd) {

  # default to commandline args
  @cmd=@ARGV if ! @cmd;

  # ^parse options
  my @files=$m->take(@cmd);


  # dig into the folders?
  if($m->{recursive} ne $NULL) {

    my @ar=@files;
    @files=();

    expand_path(\@ar,\@files);

  };


  # enable/disable auto-backslashing
  if($m->{no_escaping}==$NULL) {
    $m->{symbol}="\Q$m->{symbol}";

  } else {
    $m->{symbol}=~ s/\$/\\\$/sg;

  };


  # enable/disable symbol as regex
  if($m->{regex}==$NULL) {
    $m->{symbol}=qr{$m->{symbol}(?:\b|$|"|')};

  } else {
    $m->{symbol}=qr{$m->{symbol}}x;

  };


  # set extension filter?
  if($m->{extension} eq $NULL) {
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
      expand_path($f,\@files);
      next;

    };

    next if ! ($f=~ $m->{ext_re});
    push @out,$f;

  };

  return @out;

};

# ---   *   ---   *   ---
