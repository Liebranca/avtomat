#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD SEQ
# turns sequences into tokens
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::seq;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Arstd::String qw(cat);
  use Arstd::throw;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    seqnew
    seqtok
    seqtok_push
    seqscan
    seqin
    seqscap
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.2a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub tok_fmat {"__%s_SEQTOK_%i__"};
sub tok_re   {
  return qr{__(?<type>[^_]+)_SEQTOK_(?<idex>\d+)__};
};

sub typed_tok_re {
  my $t=uc($_[0]);
  return qr"__(?<type>${t})_SEQTOK_(?<idex>\d+)__";
};

sub spec_tok_re {
  my ($t)=uc($_[0]);
  my ($i)=$_[1];

  return qr"__(?<type>${t})_SEQTOK_(?<idex>$i)__";
};


# ---   *   ---   *   ---
# cstruc

sub seqnew {
  my %O=@_;

  # catch invalid
  throw "seqnew: 'beg' attr required"
  if ! $O{beg};

  # set defaults
  $O{end}   //= $O{beg};
  $O{keep}  //= 1;
  $O{color} //= 0x07;
  $O{rec}     = ($O{rec}) ? 0 : -1;
  $O{type}  //= 'str';
  $O{strip} //= 0;
  $O{wb}    //= 0;
  $O{inner} //= [];

  # just to make things easier, we don't allow
  # underscores in type names
  throw "seqnew: cannot use underscores in "
  .     "sequence type -- "
  .     "type '$O{type}' is invalid"

  if $O{type}=~ qr{_};
  return \%O;
};


# ---   *   ---   *   ---
# catches sequence

sub seqtok {
  my ($seq,$dst,$i,$ar)=@_;

  # look for sequence
  my $j=seqscan($seq,$i,$ar);

  # sequence not found
  return (0,null) if ! $j;

  # no need to save the contents of this
  # sequence, so only give length
  return ($j-$i,null) if ! $seq->{keep};

  # sequence must be saved, so give a token
  # to insert in it's place
  my $ct=cat(@$ar[$i..$j-1]);
  if($seq->{strip}) {
    # remove sequence delimiters
    my $re=  qr{(?:^$seq->{beg})|(?:$seq->{end}$)};
       $ct=~ s[$re][]g;
  };

  my $tok=seqtok_push($seq,$dst,$ct);
  return ($j-$i,$tok);
};


# ---   *   ---   *   ---
# given a beggining and end sequence
# plus an index, look for
#
# [0]: byte ptr  ; beggining string
# [1]: byte ptr  ; end string
# [2]: word      ; beggining position
# [3]: byte pptr ; arrayref
# [4]: word      ; recursion depth
#                  (no recursion if < 0)
#
# [<]: word ; end position (0 if not found)

sub seqscan {
  my ($seq,$i,$ar)=@_;
  my $depth=$seq->{rec};

  # check for word boundary if need
  return 0 if $seq->{wb} &&! seqwb($i,$ar);

  # get start sequence
  $i=seqin($seq->{beg},$i,$ar);
  return 0 if ! $i;

  # scan til end marker
  while($i < @$ar) {
    # pattern recurses on itself?
    if($depth >= 0 && seqin($seq->{beg},$i,$ar)) {
      ++$depth;
      $i=seqin($seq->{beg},$i,$ar);
      next;
    };
    # ^pattern recurses on another?
    for(@{$seq->{inner}}) {
      my $j=seqscan($ARG,$i,$ar);
      if($j) {
        $i=$j;
        last;
      };
    };

    # stop when end sequence found
    # and depth is at or below zero
    last if! seqscap($i,$ar)
         &&  seqin($seq->{end},$i,$ar)
         &&  ($depth-- <= 0);

    ++$i;
  };

  # validate end pos
  return seqin($seq->{end},$i,$ar);
};


# ---   *   ---   *   ---
# check whether string is present,
# inside an array at idex,
# and split across elements
#
# [0]: byte ptr  ; string to look for
# [1]: word      ; beggining position
# [2]: byte pptr ; arrayref
#
# [<]: word ; end position (0 if not found)

sub seqin {
  my ($seq,$i,$ar)=@_;
  return 0 if ! defined $ar->[$i];

  # scan array for sequence
  my $s=null;
  my $n=length($seq);
  while($i < @$ar && $n > length($s)) {
    last if ! defined $ar->[$i];
    $s .= $ar->[$i++];
  };

  # fail if not matched *exactly*
  return 0 if $s ne $seq;

  # else give position
  return $i;
};


# ---   *   ---   *   ---
# ^related, checks if char is escaped

sub seqscap {
  my ($i,$ar)=@_;
  return 0 if $i==0 ||! defined $ar->[$i-1];
  return $ar->[$i-1] eq '\\'
  &&!    seqscap($i-1,$ar);
};


# ---   *   ---   *   ---
# ^ checks if char is positioned
#   at a word boundary

sub seqwb {
  my ($i,$ar)=@_;
  return 1 if $i==0 ||! defined $ar->[$i-1];
  return (($ar->[$i-1]=~ qr{\W$})
  &&      ($ar->[$i+0]=~ qr{^\w}))

  ||     (($ar->[$i-1]=~ qr{\w$})
  &&      ($ar->[$i+0]=~ qr{^\W}))

  ||     (($ar->[$i-1]=~ qr{\W$})
  &&      ($ar->[$i+0]=~ qr{^\W}));
};


# ---   *   ---   *   ---
# adds contents to content array,
# and gives a token referencing it

sub seqtok_push($seq,$dst,$ct) {
  my $tok=sprintf(
    tok_fmat(),
    uc($seq->{type}),
    int(@$dst)
  );
  push @$dst,$ct;

  return $tok;
};


# ---   *   ---   *   ---
# commonly used sequences for comments

sub com {
  return {
    cline  => seqnew(beg=>'//',end=>"\n",comattr()),
    cmulti => seqnew(beg=>'/*',end=>"*/",comattr()),
    pline  => seqnew(beg=>'#',end=>"\n",comattr()),
  };
};
sub comattr {
  return (keep=>0,color=>0x02,wb=>1,type=>'com');
};


# ---   *   ---   *   ---
# ^strings

sub str {
  return {
    dquote   => seqnew(beg=>'"',strattrs()),
    squote   => seqnew(beg=>"'",strattrs()),
    backtick => seqnew(beg=>'`',strattrs()),
  };
};
sub strattrs {
  return (color=>0x0E,type=>'str');
};


# ---   *   ---   *   ---
# ^escapes/preprocessor

sub pproc {
  return {
    c    => seqnew(
      beg=>'#',end=>"\n",pprocattrs()
    ),
    peso => seqnew(
      beg=>'$:',end=>';>',rec=>1,pprocattrs()
    ),
  };
};
sub pprocattrs {
  return (color=>0x0E,wb=>1,type=>'pproc');
};


# ---   *   ---   *   ---
# ^delimiters

sub delim {
  return {
    paren => seqnew(beg=>'(',end=>')',delimattrs()),
    brack => seqnew(beg=>'[',end=>']',delimattrs()),
    curly => seqnew(beg=>'{',end=>'}',delimattrs()),
  };
};
sub delimattrs {
  return (rec=>1,color=>0x07,type=>'scp');
};


# ---   *   ---   *   ---
1; # ret
