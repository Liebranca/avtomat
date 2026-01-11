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
  use AR sys=>q[
    use Style qw(null);
    use Chk qw(is_null);
    lis Arstd::Re qw(eiths);
  ];

  use Arstd::PM qw(rcaller);
  use Arstd::throw;
  use parent 'St';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.02.4';
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
      $default,
      $combo,
    )=(
      $ref->{id},
      $ref->{short},
      $ref->{long},
      $ref->{argc},
      $ref->{default},
      $ref->{combo},
    );

    # save id and make arg instance
    push @order,$id;
    my $arg=Cli::Arg->new(
      $id,
      short_form => $short_form,
      long_form  => $long_form,
      argc       => $argc,
      default    => $default,
      combo      => $combo,
    );
    $optab{$id}=$arg;

    # make aliases
    $alias{$arg->{short_form}} = $id;
    $alias{$arg->{long_form}}  = $id;
  };

  # make new instance
  my $cli=bless {
    -name  => rcaller($class),
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
# get option object from alias

sub getopt {
  my ($self,$lis)=@_;
  my $id  = $self->{-alias}->{$lis};
  my $opt = $self->{-optab}->{$id};

  return ($id,$opt);
};


# ---   *   ---   *   ---
# --option <value>? || -o <value>?

sub short_or_long($self,$arg) {
  my $value=null;

  # read value of arg
  if($arg=~ s[$self->{-re}][]) {
    my $post = $POSTMATCH;
    my $pre  = $MATCH;

    $value = $post if ! is_null $post;
    $arg   = $pre;
  };

  $self->handle_input($arg,$value);
  return;
};


# ---   *   ---   *   ---
# --option=value

sub long_equal($self,$arg) {
  my $value=null;
  ($arg,$value)=split qr{=},$arg;
  $self->handle_input($arg,$value);

  return;
};


# ---   *   ---   *   ---
# grabs input and assigns it to field

sub handle_input {
  my ($self,$arg,$value,%O)=@_;
  $O{csume} //= 0;
  $self->catch_invalid_arg($arg);

  # arguments are only allowed to
  # consume the next entry in the input
  # array as value when an '=' equals sign
  # is not used, so catch that here
  my ($id,$opt)=$self->getopt($arg);
  if(! $O{csume}
  &&   $opt->{argc}
  &&   $value eq null
  ) {
    $value=$self->next_arg();
  };

  # validate the input first, and *then* handle
  # boolean switches
  $self->catch_invalid_value($opt,$value);
  $value=1 if ! $opt->{argc} && is_null($value);

  # destination is either a string or an array
  if($opt->{argc} eq 'array') {
    push @{$self->{$id}},$value;

  } else {
    $self->{$id}=$value;
  };

  # set multiple switches from a single one?
  $self->handle_combo($id,$opt);
  return;
};


# ---   *   ---   *   ---
# input handler errmes

sub catch_invalid_arg {
  my ($self,$arg)=@_;

  return if exists $self->{-alias}->{$arg};
  throw sprintf(
    "%s: invalid switch '%s'",
    $self->{-name},
    $arg,
  );
};

sub catch_invalid_value {
  my ($self,$opt,$value)=@_;

  # no value passed, and no default!
  if( is_null($value) && $opt->{argc}
  &&! defined($opt->{default})) {
    throw sprintf(
      "%s: switch '%s' requires a value",
      $self->{-name},
      $opt->{long_form},
    );

  # value passed, but none should be!
  } elsif(! is_null($value) &&! $opt->{argc}) {
    throw sprintf(
      "%s: switch '%s' doesn't take a value",
      $self->{-name},
      $opt->{long_form},
    );
  };
  return;
};


# ---   *   ---   *   ---
# sets value of multiple switches
# from a single one

sub handle_combo {
  my ($self,$id,$opt)=@_;
  return if ! $self->{$id};

  my $re=qr{^(?<x>[\-\+])};
  for my $subid(@{$opt->{combo}}) {
    $subid=~ s[$re][];

    # '+<id>' means turn this option on
    # '-<id>' thus turns it off
    my $x=($+{x} && $+{x} eq '-')
      ? 0
      : 1
      ;

    # setting a bool?
    my $subopt=$self->{-optab}->{$subid};
    if(! $subopt->{argc}) {
      $self->{$subid}=$x;

    # ^ nope, make both switches share the
    #   same value
    } else {
      $self->{$subid}=$self->{$id};
    };
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
  $attrs{combo}      //= [];

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
  use AR sys=>q[
    use Style qw(null);
    lis Arstd::Path qw(expand);
  ];

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
