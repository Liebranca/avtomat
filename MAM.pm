#!/usr/bin/perl
# ---   *   ---   *   ---
# MAM
# Mother of imports
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

  use English qw($ARG $ERRNO);
  use Module::Load;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file is_dir);
  use Arstd::String qw(strip gsplit);
  use Arstd::Bin qw(orc);
  use Arstd::throw;
  use Arstd::Repl;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.6a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# adds/removes build directory
#
# we do this so that a module can
# import the built version of others
# _during_ the build process...
#
# [0]: mem ptr ; self
# [1]: mem ptr ; repl ice
# [2]: word    ; string uid
#
# [<]: byte ptr ; string to replace placeholder by

sub repv {
  my $module = \$_[0]->{module};
  my $have   =  $_[1]->{capt}->[$_[2]];
  my $beg    = "\n" . q[  use lib "$ENV{ARPATH}];
  my $path   = \$have->{path};

  # do _not_ rept the module name ;>
  $$path=~ s[/+$$module/+][];


  # adding build directory?
  return "$beg/.trash/$$module/$$path\";"
  if $_[0]->{rap};

  # ^nope, restore!
  return "$beg/lib/$$path\";";

};


# ---   *   ---   *   ---
# cstruc
#
# [0]: byte ptr  ; class
# [<]: mem ptr   ; new instance

sub new {

  # make ice
  my $self=bless {},$_[0];

  # oh no here we go again...
  $self->{A9M}={
    -cproc=>null,

  };


  # make repl ice
  $self->{repl}=Arstd::Repl->new(
    pre  => "USE$_[0]",
    repv => sub {
      my $re  =  qr{/+};
      my $out =  repv($self,@_);
         $out =~ s[$re][/]g;

      return $out;

    },

    inre => qr{
      \s* use \s+ lib \s+

      "? \$ENV\{

      [\s'"]* ARPATH
      [\s'"]* \}

      [\s'"\.]* /

      (?<root> lib|.trash)
      (?<path> [^;]+)

      ['"] \s* ;

    }x,

  );


  return $self;

};


# ---   *   ---   *   ---
# sets module name
#
# [0]: mem ptr  ; self
# [1]: byte ptr ; module name
#
# [*]: module must be a valid directory

sub set_module {

  # validate
  throw "Invalid module: <null>"
  if is_null $_[1];

  throw "Invalid module: '$_[1]'"
  if ! is_dir "$ENV{MAMROOT}/$_[1]";


  # set and give
  $_[0]->{module}=$_[1];
  return;

};


# ---   *   ---   *   ---
# 'rap' determines whether the
# preprocessor is writing to the
# build directory or the lib directory
#
# this matters as it controls which
# paths will be used to pull packages from
#
# [0]: mem ptr ; self
# [1]: bool    ; rap true or false

sub set_rap {
  $_[0]->{rap}=$_[1];
  return;

};


# ---   *   ---   *   ---
# preprocessor: imports
#
# [0]: mem ptr  ; self
# [1]: byte ptr ; file contents
#
# [<]: word ; number of blocks processed
#
# TODO: move this to it's own file

sub AR_step {
  my $re=qr{
    \n \x{20}*

    AR \s+ (?<lib> [^\s\{\=]+)
    \s* =?>? \s* \{ \s*

    (?<body> [^\}]+)
    \s* \} ;?

  }x;


  # ^look for block until exhausted
  # ^gives number of blocks found!
  my $i=0;

  top:
  return $i if ! ($_[1]=~ $re);

  my $lib   = $+{lib};
  my $body  = $+{body};


  # cleanup commas and whitespace
  my $rmcomma=qr{\s*,+\s*};
  $body=~ s[$rmcomma][ ]smg;

  strip $body;


  # get expressions from body!
  my $expr_re=qr{
    (?<flag> (?:(?:use|lis|imp|re) \s+)*)
    (?<pkg> [^\s\(]+)
    \s* \(? \s*

    (?<sym> [^\(;\)]+)

    \s* \)? \s* ;

  }x;

  my    @line=();
  push  @line,{%+}
  while $body=~ s[$expr_re][]sm;


  # ^now reformat each expression!
  $body=null;
  for(@line) {
    $ARG->{flag} //= null;

    my @flag = gsplit $ARG->{flag};
    my @sym  = gsplit $ARG->{sym};
    my $pkg  = $ARG->{pkg};

    $body .= join null,(
      "\n  ",
      join(' ',@flag),
      " $pkg\::(",
      join(' ',@sym),

      ');',

    );

  };


  # just for completeness, we add the lib
  # to @INC the first time around
  #
  # this is to ensure the AR package can
  # _always_ be located ;>
  my $arlib=($_[0]->{rap})
    ? "\$ENV{ARPATH}/.trash/$_[0]->{module}/"
    : "\$ENV{ARPATH}/lib/"
    ;

  $body="use AR $lib=>qw($body\n);";
  $body="\nuse lib \"$arlib\";\n$body" if ! $i++;

  $_[1]=~ s[$re][$body]sm;
  goto top;

};


# ---   *   ---   *   ---
# ~~

sub pein {
  my $self = shift;
  my $dst  = $self->{A9M}->{-cproc};
  my $flag = qr{(?:cpy)};
  my $name = qr{^(?:[\$\%\&\@])};

  my $need  = {
    name => undef,
    type => undef,
    flag => [],
    defv => null,

  };

  for(@_) {
    if(! defined $need->{name} && $ARG=~ $name) {
      $need->{name}=$ARG;

    } elsif($ARG=~ $flag) {
      push @{$need->{flag}},$ARG;

    } elsif(! defined $need->{name}) {
      $need->{type}=$ARG;

    } elsif(is_null $need->{defv}) {
      $need->{defv}=$ARG;

    };

  };

  throw "Invalid arguments for 'in'"
  if int grep {! defined $ARG} values %$need;

  my $i=(
    int(keys %{$dst->{args}})
  + ($dst->{method}) ? 1 : 0

  );

  $dst->{args}->{$need->{name}}={
    idex=>$i,
    flag=>$need->{flag},
    type=>$need->{type},
    defv=>$need->{defv},

  };

  return null;

};


# ---   *   ---   *   ---
# ~~

sub peret {
  shift;
  return (int @_)
    ? "return " . (join ' ',@_)
    : "return"
    ;

};


# ---   *   ---   *   ---
# ~~

my $Proctab={
  in  => \&pein,
  ret => \&peret,

};


# ---   *   ---   *   ---
# preprocessor: subroutines
#
# [0]: mem ptr  ; self
# [1]: byte ptr ; file contents
#
# [<]: word ; number of blocks processed

sub proc_step {
  my $self=shift;
  my $re=qr{
    \n \x{20}*
    proc \s+

    (?<name> [^\s;]+) \s* ;
    (?<body> (?:[^;]*\s* ;)+) \s*

    (?<retl> ret(\s+[^;]*)?) \s* ;

  }x;


  # ^look for block until exhausted
  # ^gives number of blocks found!
  my $i=0;

  top:
  return $i if ! ($_[0]=~ $re);

  my $name=$+{name};
  my $body=$+{body} . "$+{retl};";

  throw "Redefinition of proc '$name'"
  if exists $self->{A9M}->{$name};

  $self->{A9M}->{$name}={
    method => 0,
    args   => {},

  };

  $self->{A9M}->{-cproc}=
    $self->{A9M}->{$name};


  # get expressions from body!
  my $expr_re=qr{((?:[^;]*|\;)*);+\s*}x;

  my    @line=();
  push  @line,$1
  while $body=~ s[$expr_re][]sm;


  $body=null;
  for(grep {strip $ARG} @line) {
    my ($ins,@args)=gsplit $ARG;
    my $have=(exists $Proctab->{$ins})
      ? $Proctab->{$ins}->($self,@args)
      : join ' ',$ins,@args
      ;

    $body .= "  $have;\n" if ! is_null $have;

  };

  my $procargs=$self->{A9M}->{-cproc}->{args};
  my $arg_re=join '|',map {
    quotemeta $ARG;

  } sort {
    length($b)<=>length($a);

  } keys %$procargs;

  $arg_re=qr{($arg_re)};
  while($body=~ $arg_re) {
    my $argidex=$procargs->{$1}->{idex};
    $body=~ s[$arg_re][\$_\[$argidex\]];

  };

  say "sub $name {\n$body\n};";
  exit;

};


# ---   *   ---   *   ---
# file reader;
#
# applies preprocessing steps to
# perl source file
#
# [0]: mem ptr  ; self
# [1]: byte ptr ; filepath
#
# [<]: byte ptr ; processed file (new string)

sub run {

  # validate path
  throw "Invalid file: <null>"
  if is_null $_[1];

  throw "Invalid file: '$_[1]'"
  if ! is_file $_[1];


  # read file into body
  my $body=orc $_[1];

  # ^run textual replacement
  $_[0]->AR_step($body);
  $_[0]->{repl}->proc($body);
  $_[0]->{repl}->clear();
  $_[0]->proc_step($body);

  # syntax check the filtered source ;>
  load 'Chk::Syntax',$_[1],$body;

  # give filtered
  return $body;

};


# ---   *   ---   *   ---
1; # ret
