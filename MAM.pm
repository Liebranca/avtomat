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
  use Chk qw(is_null is_file);
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

sub repv($self,$repl,$uid) {
  my $module = $self->{module};
  my $have   = $repl->{capt}->[$uid];
  my $beg    = "\n" . q[  use lib "$ENV{ARPATH}];

  my ($root,$path)=(
    $have->{root},
    $have->{path},

  );

  # do _not_ rept the module name ;>
  $path=~ s[/+$module/+][];


  # adding build directory?
  return "$beg/.trash/$module/$path\";"
  if $self->{rap};

  # ^nope, restore!
  return "$beg/lib/$path\";";

};


# ---   *   ---   *   ---
# cstruc

sub new {
  my ($class,@cmd)=@_;

  # make ice
  my $self=bless {},$class;

  # args xlate table
  my $tab={
    M => 'module',
    r => 'rap',
    f => 'fname',

  };

  # proc args
  my $sre  = qr{^\-(?<key>[^\-])(?<value>.*)$};
  my $kre  = qr{^\-\-(?<key>[^=]+)$};
  my $kvre = qr{^\-\-(?<key>[^=]+)=(?<value>.+)$};

  while(@cmd) {
    my $arg=shift @cmd;
    if($arg=~ s[$sre][]) {
      my ($key,$value)=($+{key},$+{value});
      $self->{$tab->{$key}}=$value;

    } elsif($arg=~ s[$kvre][]) {
      $self->{$+{key}}=$+{value};

    } elsif($arg=~ s[$kre][]) {
      $self->{$+{key}}=1;

    } else {
      throw "Invalid arg: '$arg'";

    };

  };


  # sanity checks
  throw "No module" if is_null $self->{module};
  throw "Invalid file: <null>"
  if is_null $self->{fname};

  throw "Invalid file: '$self->{fname}'"
  if ! is_file $self->{fname};

  # hail Mary!
  $self->{rap}//=0;

  # oh no here we go again...
  $self->{A9M}={
    -cproc=>null,

  };


  # make repl ice
  $self->{repl}=Arstd::Repl->new(
    pre  => "USE$class",
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
# ~~

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
# ~~

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
# file reader

sub run {
  my ($self)=@_;

  # read file into body
  my $body=orc $self->{fname};

  # ^run textual replacement
  $self->AR_step($body);
  $self->{repl}->proc(\$body);
  $self->{repl}->clear();
  $self->proc_step($body);

  # syntax check the filtered source ;>
  load 'Chk::Syntax',$self->{fname},$body;

  # give filtered
  return $body;

};


# ---   *   ---   *   ---
1; # ret
