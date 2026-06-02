#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD PPROC
# kinda like the C preprocessor
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::pproc;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);

  use Arstd::String qw(spacecat linecnt lineof);
  use Arstd::Bin qw(orc);
  use Arstd::strtok qw(strtok unstrtok);
  use Arstd::peso qw(peval);
  use Arstd::throw;

  use Shb7::Find qw(ffind);


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(pproc);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.3a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# we use this to record state across
# all subroutines

sub pproc_mem {
  state $mem={
    inc   => {},
    def   => {},
    if    => [],
    pkg   => {},
    depth => 0,
    lnoff => 0,
    retry => 0,
  };
  return $mem;
};


# ---   *   ---   *   ---
# entry point
#
# [0]: byte pptr ; array to save token contents to
# [1]: byte ptr  ; string to process
# [2]: byte pptr ; options
#
# [!]: overwrites input string

sub pproc {
  my $strar = shift;
  my $sref  = \$_[0];
  shift;

  # set defaults
  my %O=@_;
  $O{syx} //= Arstd::strtok::defsyx();

  # up the recursion depth
  my $mem=pproc_mem();
  ++$mem->{depth};

  # we're only interested in preprocessor
  # lines, so fetch the indices of those
  my @pline=Arstd::strtok::fetln(
    $strar,
    $$sref,
    "pproc"
  );
  while(@pline) {
    # fetch and run command
    my ($i,$cmd,@args)=pproc_take($strar,\@pline);
    next if is_null($cmd);

    my $ok=symtab($cmd)->($i,$strar,@args);

    # need to skip lines?
    while(@pline &&! $ok) {
      # jump to next clause...
      my ($si,$scmd,@sargs)=
        pproc_take($strar,\@pline);

      next if is_null($scmd);

      # ^invalid!! strip it!
      if($scmd ne "end" && $scmd ne "e$cmd") {
        $strar->[$si->[0]]=null;
        next;
      };
      # ^valid, so run it!
      $ok=symtab($scmd)->($si,$strar,@sargs);
    };
  };
  # go down one recursion level
  --$mem->{depth};

  # perform textual replacements last
  if(! $mem->{depth}) {
    pproc_txtrepl($strar,$sref);

    # need second pass?
    if($mem->{retry}) {
      $mem->{retry}=0;

      strtok($strar,$$sref,syx=>$O{syx});
      pproc($strar,$$sref,syx=>$O{syx});
    };
  };
  return;
};

sub pproc_take {
  # get next line
  my ($strar,$pline)=@_;
  my $i=shift @$pline;

  # ^make copy of value and untokenize it
  my $cpy=$strar->[$i->[0]];
  unstrtok($cpy,$strar);

  # ^fetch command and give
  return ($i,Arstd::peso::getcmd($cpy));
};


# ---   *   ---   *   ---
# opens file,
# recurses to process it,
# and then pastes it on original
#
# [0]: qword     ; token idex
# [1]: byte pptr ; token array
# [2]: byte ptr  ; filepath

sub pproc_fpaste {
  # either finds the file or throws
  my ($i,$dst,$fpath)=@_;
  $fpath=ffind(peval($fpath));

  # ^it's a nop if file already included ;>
  my $mem=pproc_mem();
  if($mem->{inc}->{$fpath}) {
    $dst->[$i->[0]]=null;
    return;
  };
  $mem->{inc}->{$fpath}=1;

  # get syntax rules for this file
  my $syx=[@{Ftype::syxof($fpath)}];

  # ^ strip preprocessor lines within it,
  #   as stddpproc expects this to be the case
  $ARG->{strip}=1
  for grep {$ARG->{type} eq 'pproc'} @$syx;

  # note how we adjust the line-number offset
  # before recursing!
  $mem->{lnoff} += $i->[1];

  # now read and tokenize the file
  my $strar = [];
  my $body  = orc($fpath);
  strtok($strar,$body,syx=>$syx);

  # ^recurse and untokenize
  pproc($strar,$body,syx=>$syx);
  unstrtok($body,$strar);

  # ^adjust offset again
  $mem->{lnoff} += linecnt($body);

  # overwrite preprocessor directive
  # with the body of the file
  $dst->[$i->[0]]=$body;

  return 1;
};

# ---   *   ---   *   ---
# sets [key=>value]
#
# [0]: qword     ; token idex
# [1]: byte pptr ; token array
# [2]: byte ptr  ; key
# [3]: byte ptr  ; value

sub pproc_define {
  # value is optional...
  my ($i,$dst,$k,$v)=@_;
  $v //= null;

  # ^the key is not
  throw "pproc: <define> without a key"
  if    is_null($k);

  # saving the value is not quite as
  # straight-forward, given that it can
  # be re-or-un-defined later...
  #
  # what we do is save the idex of each token
  # that performs such an operation, so as to
  # have a coordinate that tells us *when* to
  # use each value for the replacement!
  my $mem = pproc_mem();
  my $ar  = $mem->{def}->{$k} //= [];
  push @$ar,[$i->[1] + $mem->{lnoff},$v];

  # overwrite preprocessor directive
  # with the body of the file
  #
  # the replacement will be done later on
  $dst->[$i->[0]]=null;
  return 1;
};


# ---   *   ---   *   ---
# ^ same, but cats input to
#   an existing [key=>value]

sub pproc_cat {
  my ($i,$dst,$k,$v)=@_;
  $v //= null;

  throw "pproc: <defcat> without a key"
  if    is_null($k);

  my $mem=pproc_mem();
  throw "pproc: undefined key for <defcat> '$k'"
  if!   exists $mem->{def}->{$k};

  my $ar=$mem->{def}->{$k};
  $ar->[-1]->[1] .= $v;

  $dst->[$i->[0]]=null;
  return 1;
};


# ---   *   ---   *   ---
# ^also same, but adds newline ;>

sub pproc_catline {
  my ($i,$dst,$k,$v)=@_;
  $v //= null;
  $v  .= "\n";

  return pproc_cat($i,$dst,$k,$v);
};


# ---   *   ---   *   ---
# ^adds an `#include` line!! :O

sub pproc_catin {
  my ($i,$dst,$k,$v)=@_;
  $v //= null;
  $v   = "\n#include $v\n";

  # signal that a second pass will be required!
  pproc_mem()->{retry} |= 1;

  return pproc_cat($i,$dst,$k,$v);
};


# ---   *   ---   *   ---
# evaluates condition
#
# [0]: qword     ; token idex
# [1]: byte pptr ; token array
# [2]: byte pptr ; expr

sub pproc_if {
  # we strip the expression right away
  my ($i,$dst,@expr)=@_;
  $dst->[$i->[0]]=null;

  # get truth of this statement...
  my $ok=pproc_ifeval(0,@expr);

  # remember line where this clause appeared;
  # we'll need it for stripping it later if
  # it evaluates to false
  my $mem = pproc_mem();
  my $ar  = [];
  push @$ar,[$i->[1] + $mem->{lnoff},$ok];
  push @{$mem->{if}},$ar;

  return $ok;
};
sub pproc_eif {
  # we strip the expression right away
  my ($i,$dst,@expr)=@_;
  $dst->[$i->[0]]=null;

  # get truth of this statement...
  my $ok=pproc_ifeval(1,@expr);

  # remember line where this clause appeared;
  # we'll need it for stripping it later if
  # it evaluates to false
  my $mem = pproc_mem();
  my $ar  = $mem->{if}->[-1];

  throw "pproc: <eif> without preceding <if>"
  if!   $ar;

  push @$ar,[$i->[1] + $mem->{lnoff},$ok];
  return $ok;
};


# ---   *   ---   *   ---
# evaluate expression for if/eif...

sub pproc_ifeval {
  # we give default value when there is
  # no expression!
  my ($ok,@expr)=@_;
  my $mem  = pproc_mem();
  my $have = int(@expr);

  return $ok if! $have;

  # checking if a value is defined...
  if($have && $expr[0] eq "def") {
    $ok=exists $mem->{def}->{$expr[1]};

  # ^checking if it's *not* defined!
  } elsif($have && $expr[0] eq "ndef") {
    $ok=! exists $mem->{def}->{$expr[1]};

  # ^checking truth of a statement!! \( ^ .^)/
  } else {
    for(@expr) {
      # we want to use the latest definition
      # of this value, *if* it was `#define`-d
      if(exists $mem->{def}->{$ARG}) {
        $ARG=$mem->{def}->{$ARG}->[-1]->[1];
      };
    };
    # ^and then we can just eval :D
    $ok=eval(spacecat(@expr));
  };
  return $ok;
};


# ---   *   ---   *   ---
# terminates multi-line clause (!!)
#
# [0]: qword     ; token idex
# [1]: byte pptr ; token array
# [2]: byte pptr ; expr

sub pproc_end {
  # we strip the expression right away
  my ($i,$dst,$clause)=@_;
  $dst->[$i->[0]]=null;

  # you gotta tell me what to end...
  throw "pproc: <end> without clause"
  if    is_null($clause);

  # just mark the line where this clause ends ;>
  my $mem = pproc_mem();
  my $ar  = [];
  push @$ar,[$i->[1] + $mem->{lnoff},1];
  push @{$mem->{$clause}},$ar;

  return 1;
};


# ---   *   ---   *   ---
# fetch from function table
#
# [0]: byte ptr ; F name

sub symtab {
  my $out={
    include => \&pproc_fpaste,
    define  => \&pproc_define,
    cat     => \&pproc_cat,
    catline => \&pproc_catline,
    catin   => \&pproc_catin,
    if      => \&pproc_if,
    eif     => \&pproc_eif,
    end     => \&pproc_end,

  }->{$_[0]}

  or throw "pproc: undefined function '$_[0]'";

  return $out;
};


# ---   *   ---   *   ---
# performs textual replacement of
# any `#define`-d symbols ;>

sub pproc_txtrepl {
  my ($strar,$sref)=@_;

  # we need to put the line that terminates
  # the expression back in there, so as to
  # get the actual number of lines
  my $tok_re=Arstd::seq::tok_re("pproc");
  $$sref=~ s[$tok_re][$+{full}
]g;
  for my $k(keys %{pproc_mem()->{def}}) {
    # replace KEY within tokenized body...
    my $re=qr{(?<!\\)\b$k\b};
    pproc_txtrepl_inner($k,$sref,$re,)
    while $$sref=~ $re;

    # ^unescape
    $re=qr{\\\b$k\b};
    $$sref=~ s[$re][$k];

    # replace #KEY; inside strings!! /YES
    $re=qr{(?<!\\)\#$k;};
    pproc_txtrepl_inner(
      $k,
      \$strar->[$ARG->[0]],
      $re,
      $sref,
      Arstd::seq::tok_re("str",$ARG->[0])

    ) for Arstd::strtok::fetln(
      $strar,
      $$sref,
      "str"
    );
    # ^also unescape!
    $re=qr{\\\b$k\b};
    $$sref=~ s[$re][$k];
  };
  # we undo the extra line mambo
  $tok_re=qr{$tok_re\n};
  $$sref=~ s[$tok_re][$+{full}]g;
  return;
};
sub pproc_txtrepl_inner {
  my ($k,$dst,$dst_re,$src,$src_re)=@_;
  $src    //= $dst;
  $src_re //= $dst_re;

  # get line number for this match...
  my $lnx=lineof($$src,$src_re);

  # ^select definition accto line number!
  for(reverse @{pproc_mem()->{def}->{$k}}) {
    my ($lny,$v)=@$ARG;
    if($lnx >= $lny) {
      ($dst ne $src)
        ? $$dst=~ s[$dst_re][$v]g
        : $$dst=~ s[$dst_re][$v]
        ;
      last;
    };
  };
  return;
};


# ---   *   ---   *   ---
1; # ret
