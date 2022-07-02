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

  use lib $ENV{'ARPATH'}.'/lib/';
  use style;
  use arstd;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';
  use shwl;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.1.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# global state

  my $DEPARSE=B::Deparse->new();
  my $SBL={};

# ---   *   ---   *   ---
# ROM

  use constant {
    END_RE=>qr[(};|;|\})],

  };

# ---   *   ---   *   ---
# save table to file

sub dumpsbl() {

  my $shadow={};

# ---   *   ---   *   ---

  my %files=();
  for my $key(keys %$SBL) {

    my $symbol=$SBL->{$key};

    my $src=$symbol->{file};
    my $dst=$src;

# ---   *   ---   *   ---

    my $need_update=0;
    if(!exists $shadow->{$src}) {
      $dst=shwl::darkside_of($src);

      $need_update=(-e $dst)
        ? ((-M $dst) > (-M $src))
        : 1
        ;

      ;

# ---   *   ---   *   ---
# notify file update

      if($need_update) {

        my @ar=split m/\//,$dst;
        my $base_name=join '/.',$ar[-1];

        printf {*STDOUT}
          arstd::pretty_tag('AR').
          " updated ".
          "\e[32;1m%s\e[0m\n",

          $base_name;

      };

# ---   *   ---   *   ---

      $shadow->{$src}=$dst;
      $shadow->{$dst}=$need_update;

# ---   *   ---   *   ---

    } else {
      $dst=$shadow->{$src};
      $need_update=$shadow->{$dst};

    };

    if(!$need_update) {next};

# ---   *   ---   *   ---

    # ensure we have an array
    if(!(exists $files{$dst})) {
      $files{$dst}=[];

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
# do token replacements and append

    shwl::stitch(\$symbol->{code});

    $elem.=(join ',',@mem)."\n";
    $elem.=(join ',',@args)."\n";
    $elem.=$symbol->{code}."\n";

    push @{$files{$dst}},$elem;

  };

# ---   *   ---   *   ---

  for my $dst(keys %files) {
    open my $FH,'>',$dst or croak STRERR;
    print $FH ''.(join q{},@{$files{$dst}})."\n";

    close $FH;

  };

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

sub clean($string) {

  state $cslist=qr{(\s+,)|(,\s+)|(\s+,\s+)};
  $string=~ s/$cslist/,/sg;

  shwl::cut(\$string,'STR',shwl::STR_RE);
  shwl::cut(\$string,'CHR',shwl::CHR_RE);

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

BEGIN {
  $SIG{__WARN__}=sub {
    my $warn=shift;
    return if $warn=~
      m/may clash with future reserved/;

    warn $warn;

  };
}

# ---   *   ---   *   ---

sub UNIVERSAL::inlined:ATTR(CODE) {

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

# ---   *   ---   *   ---

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

INIT {

  dumpsbl();

};

# ---   *   ---   *   ---
1; # ret
