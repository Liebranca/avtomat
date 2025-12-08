#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD FATDUMP
# Also known as fatdumpo
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::fatdump;
  use v5.42.0;
  use strict;
  use warnings;

  use Scalar::Util qw(looks_like_number);
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/";
  use AR sys=>qw(
    use Style::(null);
    use Chk::(
      is_hashref
      is_arrayref
      is_coderef
      is_qreref
      is_blessref
      is_nref
      is_null
    );

    lis Arstd::Array::(nmap);
    use Arstd::Fmat::(tidyup);
    lis Arstd::IO::(procin procout);
    use Arstd::PM::(codename);
  );


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(fatdump);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.2';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# RAM

  my $Cache={walked=>{}};


# ---   *   ---   *   ---
# padding for nested strucs

sub lvl {
  state $lvl=0;
  return \$lvl;
};

sub pad {
  my ($x)   = @_;
     $x   //= 0;

  my $out   = '  ' x (${lvl()} + $x);

  return "\$PAD<=${out}=>";
};


# ---   *   ---   *   ---
# value already seen?

sub recursing($value) {
  return 1 if $Cache->{walked}->{$value};
  $Cache->{walked}->{$value}=1;

  return 0;
};


# ---   *   ---   *   ---
# deconstruct value

sub polydump($vref,$blessed=undef) {
  # enter
  my $lvl=lvl();
  ++$$lvl;

  # idex into this array
  # based on value type
  my $tab=[
    \&valuedump,
    \&arraydump,
    \&deepdump,
    \&codedump,
  ];

  # value already seen?
  return $vref if recursing $vref;

  # corner case: compiled regexes
  return "$$vref" if is_qreref($vref);


  # map type to idex
  my $idex=(
    (is_arrayref($$vref))
  | (is_hashref($$vref)*2)
  | (is_coderef($$vref)*3)
  );

  # ^corner case: blessed ones ;>
  if(! $idex && $$vref && $blessed) {
    my $mod =! int($$vref=~ qr{=ARRAY});
    $idex=is_blessref($$vref)*(1+$mod);
  };


  # need for recursion?
  my $rec=($blessed && $blessed == 2)
    ? $blessed
    : undef
    ;

  # select F from table
  my $f=$tab->[$idex];

  # ^give string to print
  my $out=($idex)
    ? $f->($$vref,$rec)
    : $f->($vref,$rec)
    ;

  --$$lvl;
  return "$out";
};


# ---   *   ---   *   ---
# ^ice for hashes

sub deepdump($h,$blessed=undef) {
  return $h if recursing $h;

  my $pad  = pad();
  my $ppad = pad(-1);
  return "${ppad}{\n" . join(",\n",array_nmap(
    deepfilter($h,$blessed),
    sub ($kref,$vref) {"${pad}$$kref => $$vref"},

    'kv'

  )) . "\n${ppad}}";
};


# ---   *   ---   *   ---
# ^print hashes and objects last

sub deepfilter($h,$blessed=undef) {
  return [(
    map  {strk($ARG)=>polydump(\$h->{$ARG},$blessed)}
    grep {is_nref $h->{$ARG}}
    keys %$h

  ) => (
    map  {strk($ARG)=>polydump(\$h->{$ARG},$blessed)}
    grep {! is_nref $h->{$ARG}}
    keys %$h
  )];
};


# ---   *   ---   *   ---
# ice for arrays

sub arraydump($ar,$blessed=undef) {
  return $ar if recursing $ar;

  my $pad  = pad();
  my $ppad = pad(-1);
  return "${ppad}[\n${pad}" . join(",\n${pad}",map {
    polydump(\$ARG,$blessed);

  } @$ar) . "\n${ppad}]";
};


# ---   *   ---   *   ---
# ^single value

sub valuedump($vref,$blessed=undef) {
  return (defined $$vref)
    ? valueprich($$vref)
    : 'undef'
    ;
};


# ---   *   ---   *   ---
# ^just to keep it short ;>

sub valueprich($v) {
  return $v if looks_like_number($v);
  return "'$v'";
};

sub strk($k) {
  return $k if ! ($k=~ qr{\s+});
  return "q[$k]";
};


# ---   *   ---   *   ---
# ^placeholder for coderefs

sub codedump($vref,$blessed=undef) {
  return '\&' . codename($vref,1);
};


# ---   *   ---   *   ---
# ^crux

sub fatdump($vref,%O) {
  # I/O defaults
  my $out=io_procin(\%O);

  # defaults
  $O{blessed} //= 0;
  $O{recurse} //= 0;

  # ^make setting apply recursively
  $O{blessed}=($O{recurse})
    ? $O{blessed} * 2
    : $O{blessed} * 1
    ;

  # ^clear the cache
  $Cache={};


  # get repr for vref
  my $s=(join ",\n",map {
    polydump($ARG,$O{blessed})

  } $vref);

  # cleanup
  my $re=qr{\$PAD<=(\s*)=>\s*};
  $s=join "\n",map {
    $ARG=~ s[$re][]g if $ARG=~ s[$re][$1];
    $ARG;

  } split qr"\n",$s;

  $s=~ s[$re][$+{whole}]gsm;
  $s=~ s[$re][$+{ct}]g;

  $re=qr{=>\s*};
  $s=~ s[$re][=> ]g;

  $re=qr{\[\s*\]};
  $s=~ s[$re][\[\]]g;

  $re=qr{\{\s*\}};
  $s=~ s[$re][\{\}]g;

  # ^give repr
  push @$out,$s;
  return io_procout(\%O);
};


# ---   *   ---   *   ---
1; # ret
