#!/usr/bin/perl
# ---   *   ---   *   ---
# INLINING
# See inline
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package inlining;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Carp;

  use attributes;
  use Attribute::Handlers;

  use File::Spec;
  use B::Deparse;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.1.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# global state

  my $DEPARSE=B::Deparse->new();
  my $STRINGS={};

  my $SBL={};

# ---   *   ---   *   ---
# ROM

  use constant {

    CUT_FMAT=>':__%s_CUT_%i__:',
    CUT_RE=>':__\w+_CUT_(\d+)__:',
    END_RE=>qr[(};|;|\})],

  };

# ---   *   ---   *   ---
# save table to file

sub dumpsbl($src) {

  my $dst=$src;

  $dst=~ s/[.].*$//;
  $dst=~ s/\/([_\w][_\w\d]*)$/\/.$1/;

  if( (-e $dst)
  &&  ((-M $dst) < (-M $src))

  ) {goto TAIL};

# ---   *   ---   *   ---

  my %files=();
  for my $key(keys %$SBL) {

    my $symbol=$SBL->{$key};
    my $f=$symbol->{file};

    # ensure we have an array
    if(!(exists $files{$f})) {
      $files{$f}=[];

    };

# ---   *   ---   *   ---

    my $elem=q{};
    $elem.="$symbol->{pkg}::$key\n";

    my @mem=();
    for my $n(keys %{$symbol->{mem}}) {
      push @mem,"$n*=>$symbol->{mem}->{$n}";

    };

    my @args=();
    for my $n(keys %{$symbol->{args}}) {
      push @args,"$n*=>$symbol->{args}->{$n}";

    };

# ---   *   ---   *   ---

    while($symbol->{code}=~ m/(${\CUT_RE})/) {
      my $key=${^CAPTURE[0]};
      my $value=$STRINGS->{$key};

      $symbol->{code}=~ s/${key}/$value/;

    };

# ---   *   ---   *   ---

    $elem.=(join ',',@mem)."\n";
    $elem.=(join ',',@args)."\n";
    $elem.=$symbol->{code}."\n";

    push @{$files{$f}},$elem;

  };

# ---   *   ---   *   ---

  open my $FH,'>',$dst or croak $ERRNO;

  for my $f(keys %files) {
    print $FH ''.(join q{},@{$files{$f}})."\n";

  };

  close $FH;

# ---   *   ---   *   ---

TAIL:
  $SBL={};
  return;

};

# ---   *   ---   *   ---

sub hashpat(@keys) {

  @keys=sort {
    (length $a)<=(length $b);

  } @keys;

  my $out='('.(join '|',@keys).')';

  return qr{$out};

};

# ---   *   ---   *   ---
# utility funcs

sub mcut($string,$name,$beg,$end=undef) {

  # defaults
  $end//=$beg;

  $beg=qr{$beg};
  $end=qr{$end};

# ---   *   ---   *   ---
# replace pattern with placeholder

  while($string=~ m/$beg/) {

    $string=~ s/($beg(.*?)$end)/#:cut;>/;

    my $v=${^CAPTURE[0]};
    my $token=q{};

# ---   *   ---   *   ---
# construct a peso-style :__token__:

    # repeats aren't saved twice
    if(exists $STRINGS->{$v}) {
      $token=$STRINGS->{$v};

    # hash->{data}=token
    # hash->{token}=data
    } else {
      $token=sprintf CUT_FMAT,
        $name,int(keys %$STRINGS);

      $STRINGS->{$v}=$token;
      $STRINGS->{$token}=$v;

    };

# ---   *   ---   *   ---
# put the token in place of placeholder

    $string=~ s/#:cut;>/$token/;

  };

  return $string;

};

# ---   *   ---   *   ---

sub clean($string) {

  state $cslist=qr{(\s+,)|(,\s+)|(\s+,\s+)};
  $string=~ s/$cslist/,/sg;

  $string=mcut($string,'STR',q{"});
  $string=mcut($string,'CHR',q{'});

  return $string;

};

# ---   *   ---   *   ---

sub tokenize($string) {

  my $tokens=[];
  for my $tok(split /\s+/,$string) {
    $tok=~ s/\s+//;
    push @$tokens,$tok;

  };

  return $tokens;

};

# ---   *   ---   *   ---
# ROM 2

  use constant {

    STAGE_BEG=>0x00,
    STAGE_END=>0x01,

  };

# ---   *   ---   *   ---

sub read_decls($tokens) {

  my $stage=0;

  my $name=q{};
  my $value=q{};

# ---   *   ---   *   ---
# walk until end of expression

  while($tokens) {
    my $tok=shift @$tokens;
    hdepth($tok);

    my $end=$tok=~ s/${\END_RE}//;

# ---   *   ---   *   ---
# non blank

    if(length $tok) {

      # skip the operator
      if($tok=~ m/=/) {
        $stage=STAGE_END;

      # 'var' = 'something'
      } elsif ($stage==STAGE_BEG)
      {$name.=$tok} else {$value.=$tok};

# ---   *   ---   *   ---
# terminate on blank or end

    };

    if($end) {last};

  };

  return ($name,$value);

};

# ---   *   ---   *   ---
# save decls to symbol mem

sub def_state($tokens) {
  my ($name,$value)=read_decls($tokens);
  $SBL->{-CURRENT}->{mem}->{$name}=$value;

};

# ---   *   ---   *   ---
# ^ same thing for args

sub def_my($tokens) {
  my ($name,$value)=read_decls($tokens);
  $SBL->{-CURRENT}->{args}->{$name}=$value;

};

# ---   *   ---   *   ---

sub BUILD_CALLTAB {

  state @KEYWORDS=qw(
    my state

  );

  my %tab=();
  for my $kw(@KEYWORDS) {
    $tab{$kw}=eval(q{\&}.'def_'.$kw);

  };

  return %tab;

};

my %CALLTAB=BUILD_CALLTAB;
my $KEYWORD_RE=hashpat(keys %CALLTAB);

# ---   *   ---   *   ---

sub hdepth($tok) {

  use constant {

    INC_DEPTH=>qr[^\{],
    DEC_DEPTH=>qr[\};?$],

  };

# ---   *   ---   *   ---

  my $h=$SBL->{-CURRENT};
  if($tok=~ INC_DEPTH) {
    $h->{depth}++;

# ---   *   ---   *   ---

  } elsif ($tok=~ DEC_DEPTH) {
    $h->{depth}--;

    if($h->{in_init} && $h->{depth}) {
      $h->{in_init}=0;

    };

  };

};

# ---   *   ---   *   ---

sub defit($tokens) {

  my $h=$SBL->{-CURRENT};

  while(@$tokens) {

    my $tok=shift @$tokens;
    if(!$h->{in_init} && $tok=~ m/do/) {
      $h->{in_init}=1;

    };

# ---   *   ---   *   ---

    hdepth($tok);

    if($tok=~ $KEYWORD_RE) {
      $CALLTAB{$tok}->($tokens);

    } elsif(!$h->{in_init}) {
      my $end=($tok=~ m/(END_RE)/) ? $1 : q{ };
      $SBL->{-CURRENT}->{code}.=$tok.$end;

    };

  };
};

# ---   *   ---   *   ---
# NOTE: lyeb@IBN-3DILA 06/29/22 06:04:19 PM
#
#   CODE package attribute inlined...
#   "may conflict with future reserved keyword"
#
#   yeah, right.
#
#   there's topics about inlining subs
#   dating as far back to at least 2002, a full
#   twenty years since the time of writting.
#
#   i'm pretty sure you'll never do it, so
#   i'll just mute your intrusive errme.
#
#   warm regards,
#   the one who mallocs.
#
# ---   *   ---   *   ---

my $shutup;
BEGIN {

  $shutup=readlink "/proc/self/fd/2";

  open STDERR,'>',
  File::Spec->devnull() or die $ERRNO;

};

# ---   *   ---   *   ---

sub inlined : ATTR(CODE) {

  my (

    $pkg,
    $symbol,
    $referent,

    $attr,
    $data,
    $phase,

    $filename,
    $linenum

  ) = @_;

  my $name=*{$symbol}{NAME};

  my $code=q{};
  my $rawcode=
    $DEPARSE->coderef2text(*{$symbol}{CODE});

# ---   *   ---   *   ---

  $SBL->{-CURRENT}

  =

  $SBL->{$name}

  =

  {
    init=>q{},

    pkg=>$pkg,
    file=>$filename,

    code=>q{},
    args=>{},

    # temporal
    depth=>0,
    in_init=>0,

  };

# ---   *   ---   *   ---

  $rawcode=clean($rawcode);
  my $tokens=tokenize($rawcode);

  defit($tokens);

# ---   *   ---   *   ---
# cleanup

  my $h=$SBL->{-CURRENT};

  delete $h->{depth};
  delete $h->{in_init};

  delete $SBL->{-CURRENT};

};

# ---   *   ---   *   ---

END {

  open STDERR,'>',
  $shutup or croak $ERRNO;

};

# ---   *   ---   *   ---
1; # ret
