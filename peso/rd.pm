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
  use peso::node;
  use peso::program;

# ---   *   ---   *   ---
# global state

  my $rb='';
  my $rem='';
  my $fname='';
  my $FH=undef;

  my @exps=();

# ---   *   ---   *   ---
# flags

  use constant {
    FILE=>0x00,
    STR=>0x01,

  };

# ---   *   ---   *   ---
# sanitize line of code

sub clean {

  # strip comments
  $rb=~ s/#.*\n//g;

  # remove indent
  $rb=~ s/^\s+//sg;

  # no spaces surrounding commas
  $rb=~ s/\s*,\s*/,/sg;

  # force single spaces
  $rb=~ s/\s+/\$:pad;>/sg;
  $rb=~ s/\$:pad;>/ /sg;

  # strip newlines
  $rb=~ s/\n+//sg;
  $rb=~ s/;\s+/;/sg;

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

    };push @exps,$e;

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

    };push @exps,$e;

  };$rem.=$entry;

# ---   *   ---   *   ---
# proc 'table' for branchless call

};my $rdprocs=[\&mlexps,\&slexps];

# ---   *   ---   *   ---
# blanks out global state

sub wipe {

  $rb='';
  $rem='';

  fclose();
  @exps=();

};

# ---   *   ---   *   ---
# in: filepath

# cleans globals
# opens file
# checks header error

sub fopen {

  wipe();my $hed=peso::decls::hed;

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

  # close file
  fclose();

# ---   *   ---   *   ---
# read expressions from a string

};sub string {

  # flush cache
  wipe();

  # split string into lines
  my $s=shift;
  my @ar=split "\n",$s;

  # iter lines && read
  while($rb=shift @ar) {line();};

};

# ---   *   ---   *   ---

sub mam {

  my $mode=shift;
  my $src=shift;

  peso::program::nit();

  (\&file,\&string)[$mode]->($src);

  for my $exp(@exps) {

    #

    my $body=$exp;
    if($body=~ m/\{|\}/) {
      $exp=peso::node::nit(undef,$body);

    } else {

      $exp=peso::node::nit(undef,'void');

      $exp->tokenize($body);
      $exp->agroup();
      $exp->collapse();
      $exp->reorder();

      $exp->exwalk();

    };$exp->prich();

  };

};

# ---   *   ---   *   ---
