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

  use lang;

  use peso::decls;
  use peso::node;
  use peso::blk;
  use peso::program;

# ---   *   ---   *   ---
# getters/setters

;;sub line {

  my $self=shift;
  my $new=shift;

  if(defined $new) {
    $self->{-LINE}=$new;

  };return $self->{-LINE};

};sub rem {

  my $self=shift;
  my $new=shift;

  if(defined $new) {
    $self->{-REM}=$new;

  };return $self->{-REM};

};sub exps {return (shift)->{-EXPS};};
;;sub langkey {return (shift)->{-LANG};};

# ---   *   ---   *   ---
# constructor

sub nit {

  my $langkey=shift;

  return bless {

    -LANG=>$langkey,

    -LINE=>'',
    -REM=>'',

    -FNAME=>'',
    -FHANDLE=>undef,

    -EXPS=>[],

  },'peso::rd';

};

# ---   *   ---   *   ---
# flags

  use constant {
    FILE=>0x00,
    STR=>0x01,

  };

# ---   *   ---   *   ---
# sanitize line of code

sub clean {

  my $self=shift;

  my $com=lang::comment($self->langkey);
  my $eb=lang::exp_bound($self->langkey);

  # strip comments
  $self->{-LINE}=~ s/${com}.*//g;

  # remove indent
  $self->{-LINE}=~ s/^\s+//sg;

  # no spaces surrounding commas
  $self->{-LINE}=~ s/\s*,\s*/,/sg;

  # force single spaces
  $self->{-LINE}=~ s/\s+/\$:rdclpad;>/sg;
  $self->{-LINE}=~ s/\$:rdclpad;>/ /sg;

  $self->{-LINE}=~ s/'.$eb.'\s+/'.$eb.'/sg;

  if(!$self->line) {return 1;};

  return 0;

};

# ---   *   ---   *   ---
# append leftovers from previous
# lines read

sub join_rem {

  my $self=shift;

  $self->line($self->rem.$self->line);
  $self->rem('');

};

# ---   *   ---   *   ---
# single-line expressions

sub slexps {

  my $self=shift;
  $self->join_rem();

  my $eb=lang::exp_bound($self->langkey);
  my $sb=lang::scope_bound($self->langkey);

  my @ar=split

    m/([${sb}])|${eb}$|${eb}/,
    $self->line

  ;

# ---   *   ---   *   ---

  # separate curls
  for my $e(@ar) {

    if(!defined $e || !length $e) {
      next;

    };push @{$self->exps},$e;

  };
};

# ---   *   ---   *   ---
# multi-line expressions

sub mlexps {

  my $self=shift;

  my $eb=lang::exp_bound($self->langkey);
  my $sb=lang::scope_bound($self->langkey);

  my @ar=split m/([${sb}])|${eb}/,$self->line;
  my $entry=pop @ar;

  # separate curls
  for my $e(@ar) {

    if(!defined $e || !length $e) {
      next;

    };push @{$self->exps},$e;

  };$self->rem($self->rem.$entry);

# ---   *   ---   *   ---
# proc 'table' for branchless call

};my $rdprocs=[\&mlexps,\&slexps];

# ---   *   ---   *   ---
# blanks out instance

sub wipe {

  my $self=shift;

  $self->line('');
  $self->rem('');

  $self->fclose();
  $self->{-EXPS}=[];

};

# ---   *   ---   *   ---
# in: filepath

# cleans globals
# opens file
# checks header error

sub fopen {

  my $self=shift;
  $self->wipe();

  my $hed=lang::file_header($self->langkey);

  # open file
  $self->{-FNAME}=glob(shift);open

    $self->{-FHANDLE},'<',
    $self->{-FNAME} or die $!

  ;

  # verify header
  $self->line(readline $self->{-FHANDLE});
  if(!($self->line=~ m/${hed}/)) {
    printf STDERR $self->{-FNAME}.": bad header\n";
    fclose();

  };

  # get remains
  $self->line_re("s/${hed}//");
  $self->rem('');

# ---   *   ---   *   ---
# errchk & close

};sub fclose {

  my $self=shift;

  if(defined $self->{-FHANDLE}) {
    close $self->{-FHANDLE};

  };$self->{-FHANDLE}=undef;

};

# ---   *   ---   *   ---
# shorthand for nasty one-liner
# use proc A if regex match, else use proc B

sub expsplit {

  my $self=shift;

  my $eb=lang::exp_bound($self->langkey);
  my $sb=lang::scope_bound($self->langkey);

  $rdprocs
    ->[$self->line=~ m/([${sb}])|${eb}$|${eb}/]
    ->($self)

  ;

# ---   *   ---   *   ---
# process buffered line

};sub procline {

  my $self=shift;

  # skip if blank line
  if($self->clean) {return;};

  # split expressions at scope bound (def: '{ or }')
  # or split at expression bound (def: ';')
  $self->expsplit();

# ---   *   ---   *   ---
# read entire file

};sub file {

  my $self=shift;

  # open & read first line
  $self->fopen(shift);
  $self->procline();

  # read body of file
  while($self->line(
    readline $self->{FHANDLE}

  )) {$self->procline();};

  # close file
  $self->fclose();

# ---   *   ---   *   ---
# read expressions from a string

};sub string {

  my $self=shift;

  # flush cache
  $self->wipe();

  # split string into lines
  my $s=shift;
  my @ar=split "\n",$s;

  my @filtered=();
  for my $l(@ar) {
    if($l) {push @filtered,$l;};

  };

  # iter lines && read
  while(@filtered) {
    $self->line(shift @filtered);
    $self->procline();

  };

};

# ---   *   ---   *   ---

sub mam {

  my $langkey=shift;
  my $mode=shift;
  my $src=shift;

  my $rd=nit($langkey);

  peso::program::nit();
  (\&file,\&string)[$mode]->($rd,$src);

# ---   *   ---   *   ---

  for my $exp(@{$rd->exps}) {

    #

    my $body=$exp;
    if($body=~ m/\{|\}/) {
      $exp=peso::node::nit(undef,$body);

    } else {

      $exp=peso::node::nit(undef,'void');

      $exp->tokenize($body);
      $exp->agroup();

      $exp->subdiv2();

#      $exp->subdiv();

#      $exp->collapse();

#      $exp->reorder();
#      $exp->exwalk();

    };

printf "\n";
$exp->prich();

  };exit;

# ---   *   ---   *   ---

  my $non=peso::blk::NON;

  for my $exp(@{$rd->exps}) {
    $exp->findptrs();

  };

# ---   *   ---   *   ---

  peso::blk::incpass();

  for my $exp(@{$rd->exps}) {
    $exp->exwalk();

  };

  $non->prich();

};

# ---   *   ---   *   ---
