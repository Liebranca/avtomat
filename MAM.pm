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

  use Carp qw(croak);
  use English qw($ARG $ERRNO);

  use lib "$ENV{ARPATH}/lib/";
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file);
  use Arstd::Repl;
  use SyntaxCheck;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5a';
  our $AUTHOR  = 'IBN-3DILA';


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
      croak "Invalid arg: '$arg'";

    };

  };


  # sanity checks
  croak "No module" if is_null $self->{module};
  croak "Invalid file: <null>"
  if is_null $self->{fname};

  croak "Invalid file: '$self->{fname}'"
  if ! is_file $self->{fname};

  # hail Mary!
  $self->{rap}//=0;


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
# your hands in the air!

sub throw {
  $_[0] //= '<null>';
  croak "$ERRNO: '$_[0]'";

};


# ---   *   ---   *   ---
# open,read,close

sub orc {
  open  my $fh,'<',$_[0] or throw $_[0];
  read  $fh,my $body,-s $fh;
  close $fh or throw $_[0];

  return $body;

};


# ---   *   ---   *   ---
# cleaning

sub strip {
  return 0 if is_null $_[0];
  my $re=qr{(?:^\s+)|(?:\s+$)};

  $_[0]=~ s[$re][]smg;
  return ! is_null $_[0];

};

sub gstrip {
  return grep {strip $ARG} split qr{\s+},$_[0];

};


# ---   *   ---   *   ---
# ~~

sub AR_step {
  my $re=qr{
    \n AR \s+ (?<lib> [^\s\{\=]+)
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

  my    @lines=();
  push  @lines,{%+}
  while $body=~ s[$expr_re][]sm;


  # ^now reformat each expression!
  $body=null;
  for(@lines) {
    $ARG->{flag} //= null;

    my @flag = gstrip $ARG->{flag};
    my @sym  = gstrip $ARG->{sym};
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
# file reader

sub run {
  state $uid=0;
  my ($self)=@_;

  # read file into body
  my $body=orc $self->{fname};

  # ^run textual replacement
  $self->AR_step($body);
  $self->{repl}->proc(\$body);
  $self->{repl}->clear();


  # syntax check the filtered source ;>
  my $beg  =  "\npackage";
  my $re   =  qr{$beg\s+([^;]+);};
     $body =~ s[$re][$beg ${1}_MAMOUT$uid;]smg;

  SyntaxCheck::run($self->{fname},$body);

  $re   =  qr{$beg\s+([^;]+)_MAMOUT\d+;};
  $body =~ s[$re][$beg $1;]smg;

  ++$uid;


  # give filtered
  return $body;

};


# ---   *   ---   *   ---
1; # ret
