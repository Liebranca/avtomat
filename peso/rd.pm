#!/usr/bin/perl
# ---   *   ---   *   ---
# RD
# reads pe files
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::rd;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use peso::decls;

# ---   *   ---   *   ---
# global state

  my $rb='';
  my $rem='';
  my $fname='';
  my $FH=undef;

  my @exps=();

# ---   *   ---   *   ---
# sanitize line of code

sub clean {

  # do not change contents of strings
  my $string=peso::decls::string;
  my $result='';

  my $i=0;

  my @ar=();
  while($rb=~ s/${string}/#:str;>/) {

    my $s=$1;
    my $j=0;

    my $nums='';

    $s=~ s/\\n/\n/;

    for my $c(split '',$s) {
      $nums.=sprintf "0x%02X,",ord($c);

    };$nums=~ s/,$//;

    push @ar,(0,$nums);

  };for my $s(split '#:str;>',$rb) {
    $ar[$i]=$s;
    $i+=2;

  };

  for my $s(@ar) {

    if($s=~ m/${string}/) {
      goto APPEND;

    } elsif(!$s) {next;};

    # strip comments
    $s=~ s/#.*\n//g;

    # remove indent
    $s=~ s/^\s+//sg;

    # no spaces surrounding commas
    $s=~ s/\s*,\s*/,/sg;

    # force single spaces
    $s=~ s/\s+/\$:pad;>/sg;
    $s=~ s/\$:pad;>/ /sg;

    # strip newlines
    $s=~ s/\n+//sg;
    $s=~ s/;\s+/;/sg;

    APPEND:$result.=$s;

  };$rb=$result;
  if(!$rb) {return 1;};

  return 0;

};

# ---   *   ---   *   ---
# single-line expressions

sub slexps {

  $rb=$rem.$rb;$rem='';
  my @ar=split m/([\{\}])|;$|;/,$rb;

# ---   *   ---   *   ---

  # separate curls
  for my $e(@ar) {

    if(!defined $e || !length $e) {
      next;

    };

# ---   *   ---   *   ---

    if($e=~ m/^\s*\{/) {
      push @exps,'{';
      $e=~ s/^\s*\{//;

    };my $cl=$e=~ s/\}$//;

    $e=~ s/;//;

    push @exps,$e;
    if($cl) {push @exps,'}';};

  };
};

# ---   *   ---   *   ---
# multi-line expressions

sub mlexps {

  my @ar=split m/([\{\}])|;/,$rb;
  my $entry=pop @ar;

  # separate curls
  for my $e(@ar) {

    if(!defined $e || !length $e) {
      next;

    };

# ---   *   ---   *   ---

    if($e=~ m/^\s*\{/) {
      push @exps,'{';
      $e=~ s/^\s*\{//;

    };my $cl=$e=~ s/\}$//;

    $e=~ s/;//;

    push @exps,$e;
    if($cl) {push @exps,'\}';};

  };$rem.=$entry;

# ---   *   ---   *   ---
# proc 'table' for branchless call

};my $rdprocs=[\&mlexps,\&slexps];

# ---   *   ---   *   ---
# in: filepath

# cleans globals
# opens file
# checks header error

sub fopen {

  # blank out global state
  $rb='';
  $rem='';

  fclose();
  @exps=();

# ---   *   ---   *   ---

  my $hed=peso::decls::hed;

  # open file
  $fname=glob(shift);
  open $FH,'<',$fname or die $!;

  # verify header
  $rb=readline $FH;
  if(!($rb=~ m/${hed}/)) {
    printf STDERR "$fname: bad header\n";
    fclose();

  };

  # get remains
  $rb=~ s/${hed}//;
  $rem='';

# ---   *   ---   *   ---
# errchk & close

};sub fclose {

  if(defined $FH) {
    close $FH;

  };$FH=undef;

};

# ---   *   ---   *   ---
# shorthand for nasty one-liner
# use proc A if regex match, else use proc B

sub expsplit {
  $rdprocs->[$rb=~ m/([\{\}])|;$|;/]->();

# ---   *   ---   *   ---
# read a single line saved to rb

};sub line {

  # skip if blank line
  if(clean) {return;};

  # split expressions at {|;|}
  expsplit();

# ---   *   ---   *   ---
# read entire file

};sub file {

  # open & read first line
  fopen(shift);line();

  # read body of file
  while($rb=readline $FH) {line();};

  # close and return expressions
  close $FH;
  return \@exps;

};

# ---   *   ---   *   ---
