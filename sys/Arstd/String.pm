#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD STRING
# NULL-TERMINATED
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::String;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG $MATCH);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_arrayref is_null);


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    cat
    catpath
    to_char

    sqwrap
    dqwrap

    linewrap
    ilinewrap

    recaptsu
    decaptsu

    has_prefix
    has_string
    has_suffix

    nobs
    charcon
    strip
    gstrip
    gsplit
    fgsplit
    clist

    jag
    cjag
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.6';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# join null,(in)
#
# [0]: byte pptr ; string array

sub cat {join null,@_};


# ---   *   ---   *   ---
# join '/',(in)
#
# [0]: byte pptr ; string array
# [*]: ensures there's no double slashes

sub catpath {
  my $out =  join '/',@_;
  my $re  =  qr{/+};
     $out =~ s[$re][/]g;

  return $out;
};


# ---   *   ---   *   ---
# ^split null,in
#
# [0]: byte ptr ; string

sub to_char {split null,$_[0]};


# ---   *   ---   *   ---
# wrap string in quotes
#
# [0]: byte ptr ; string
# [<]: byte ptr ; new string

sub sqwrap {return "'$_[0]'"};
sub dqwrap {return "\"$_[0]\""};


# ---   *   ---   *   ---
# builds regex for linewrapping
#
# [0]: word ; sz
# [<]: re   ; pattern (new or cached)

sub linewrap_re {
  my $re=cat(

    # line ==   ((sz-1) chars != "\n")
    #         + ["\n","\s",EOF]

    '(?<line>',
    '[^\n]{1,' . ($_[0]-1) . '}',
    '(?: (?: \n|\s) | $)',

    # OR
    '|',

    # line ==   ((sz-2) chars != "\n")
    #         + (any,EOF)

    '[^\n]{1,' . ($_[0]-2) . '}',
    '(?: .|$)',
    ')'

  );

  return qr{$re};

};


# ---   *   ---   *   ---
# split string at X characters
#
# [0]: byte ptr  ; string
# [1]: word      ; size
#
# [<]: byte pptr ; chomped lines (new array)

sub linewrap {
  my $re=linewrap_re($_[1]);
  return map {chomp $ARG;$ARG} gsplit($_[0],$re);
};


# ---   *   ---   *   ---
# ^adds padding on a per-line basis
#
# [0]: byte ptr ;  string
# [1]: word     ; padsz
# [2]: word     ; linesz
#
# [<]: byte pptr ; new array

sub ilinewrap {
  return map {
    ('  ' x $_[1]) . $ARG;

  } linewrap($_[0],$_[2]);

};


# ---   *   ---   *   ---
# captures matches for a subst re
#
# [0]: byte ptr ; string
# [1]: re       ; pattern
#
# [<]: mem  ptr ; new [match=>pos] array
#
# [!]: overwrites input string

sub recaptsu {
  my    @out;
  push  @out,[$MATCH=>$-[0]]
  while $_[0]=~ s[$_[1]][]sxm;

  return @out;

};


# ---   *   ---   *   ---
# ^undo
#
# [0]: byte ptr ; string
# [1]: mem  ptr ; [match=>pos] array
#
# [!]: overwrites input string

sub decaptsu {
  my $sref=\$_[0];
  shift;

  # we keep track of _real_ position to
  # account for string growing as we
  # insert back matches
  my $accum=0;
  for(@_) {
    my ($match,$pos)=@$ARG;
    substr $$sref,$accum,$pos-$accum,$match;
    $accum+=length $match;

  };


  return;

};


# ---   *   ---   *   ---
# selfex -- string has prefix
#
# [0]: byte ptr  ; string
# [1]: byte pptr ; array of prefixes
#
# [<]: byte pptr ; prefixes matched (new array)

sub has_prefix {
  my $sref=\$_[0];
  shift;

  return grep {0 == rindex $$sref,$ARG,0} @_;

};


# ---   *   ---   *   ---
# ^string has string (as in... strstr)
# ^or rather string has _sub_ string
#
# should've named it strsub, maybe? ;>
#
# [0]: byte ptr  ; string
# [1]: byte pptr ; array of substrings
#
# [<]: byte pptr ; substrings matched (new array)

sub has_string {
  my $sref=\$_[0];
  shift;

  return grep {0 <= index $$sref,$ARG} @_;

};


# ---   *   ---   *   ---
# selfex -- string has suffix
#
# [0]: byte ptr  ; string
# [1]: byte pptr ; array of suffixes
#
# [<]: byte pptr ; suffixes matched (new array)

sub has_suffix {
  my $sref=\$_[0];
  shift;

  return grep {
     length($$sref)-1
  == index($$sref,$ARG,length($$sref)-1)

  } @_;

};


# ---   *   ---   *   ---
# convert match of seq into char
#
# [0]: byte ptr ; string
# [1]: mem  ptr ; conversion table
#
# [<]: bool ; string is not null
#
# [!]: overwrites input string

sub charcon {
  return 0 if is_null $_[0];

  # set default
  $_[1]//=[
    qr{\\n} => "\n",
    qr{\\r} => "\r",
    qr{\\b} => "\b",
    qr{\\e} => "\e",
    qr{\\}  => '\\',

  ];

  # ^replace
  for(0..int(@{$_[1]}/2)-1) {
    my $pat=$_[1]->[$ARG*2+0];
    my $seq=$_[1]->[$ARG*2+1];

    $_[0]=~ s[$pat][$seq]sxmg;

  };

  return ! is_null $_[0];

};


# ---   *   ---   *   ---
# rm backslash in string
#
# [0]: byte ptr ; string
#
# [<]: bool ; string is not null
#
# [!]: overwrites input string

sub nobs {
  return 0 if is_null $_[0];
  my $re=qr{\\(.)}x;

  $_[0]=~ s[$re][$1]sxmg;
  return ! is_null $_[0];

};


# ---   *   ---   *   ---
# remove leading/trailing whitespace
#
# [0]: byte ptr ; string
# [<]: bool     ; string is not null
#
# [!]: overwrites input string

sub strip {
  return 0 if is_null $_[0];
  my $re=qr{(?:^\s*)|(?:\s*$)};

  $_[0]=~ s[$re][]smg;
  return ! is_null $_[0];

};


# ---   *   ---   *   ---
# ^from array, filters out empty
#
# [0]: byte pptr ; array
# [<]: byte pptr ; new array (without blanks)
#
# [!]: overwrites input array elems

sub gstrip {
  return grep {strip $ARG} @_;

};


# ---   *   ---   *   ---
# split string with regex,
# then filter out blanks from result
#
# [0]: byte ptr ; string
# [1]: re       ; pattern (defaults to whitespace)
#
# [<]: byte pptr ; new array

sub gsplit {
  return () if is_null($_[0]);

  $_[1]//=qr{\s+};
  return gstrip(split $_[1],$_[0]);
};


# ---   *   ---   *   ---
# ^only keeps whatever matches re
#
# [0]: byte ptr ; string
# [1]: re       ; pattern (no default)
#
# [<]: byte pptr ; new array

sub fgsplit {
  return () if is_null($_[0]);
  return grep {
    strip($ARG) && ($ARG=~ $_[1])

  } split($_[1],$_[0]);
};


# ---   *   ---   *   ---
# gets array from arrayref
# or comma-separated string
#
# [0]: mem ptr   ; array || string
# [<]: byte pptr ; new array

sub clist {
  return (is_arrayref $_[0])
    ? (@{$_[0]})
    : (split qr{\s*,\s*},$_[0])
    ;
};


# ---   *   ---   *   ---
# join after gstrip
#
# [0]: byte ptr  ; prefix (shifted)
# [1]: byte pptr ; array
#
# [<]: byte ptr ; new string
#
# [!]: overwrites input array elems

sub jag {
  return join((shift),gstrip(@_));
};


# ---   *   ---   *   ---
# ^cats string to first elem
#
# [0]: byte ptr  ; prefix
# [1]: byte pptr ; array
#
# [<]: byte*  ; new string
#
# [!]: overwrites input array elems

sub cjag {
  return (@_) ? $_[0] . jag @_ : null ;
};


# ---   *   ---   *   ---
1; # ret

