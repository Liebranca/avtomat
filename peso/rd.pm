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
;;sub program {return (shift)->{-PROGRAM};};
;;sub lang {return (shift)->program->lang;};

# ---   *   ---   *   ---
# constructor

sub nit {

  my $program=shift;

  return bless {

    -PROGRAM=>$program,

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
  my $lang=$self->program->lang;

  my $com=$lang->com;
  my $eb=$lang->exp_bound;

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

  my $lang=$self->program->lang;

  my $eb=$lang->exp_bound;
  my $sb=$lang->scope_bound;

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
  my $lang=$self->program->lang;

  my $eb=$lang->exp_bound;
  my $sb=$lang->scope_bound;

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

  my $lang=$self->program->lang;
  my $hed=$lang->hed;

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
  $self->{-LINE}=~ s/${hed}//;
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
  my $lang=$self->program->lang;

  my $eb=$lang->exp_bound;
  my $sb=$lang->scope_bound;

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

  my $lang=shift;
  my $mode=shift;
  my $src=shift;

  my $program=peso::program::nit($lang);
  my $rd=nit($program);

  (\&file,\&string)[$mode]->($rd,$src);

# ---   *   ---   *   ---

  my $fr_node=$program->node;
  my $fr_ptr=$program->ptr;
  my $fr_blk=$program->blk;

  for my $exp(@{$rd->exps}) {

    #

    my $body=$exp;
    if($body=~ m/\{|\}/) {
      $exp=$fr_node->nit(undef,$body);

    } else {

      $exp=$fr_node->nit(undef,'void');

      $exp->tokenize($body);
      $exp->agroup();

      $exp->subdiv();

#      $exp->collapse();

#      $exp->reorder();
#      $exp->exwalk();

    };

printf "\n";
$exp->prich();

  };exit;

# ---   *   ---   *   ---

  my $non=$fr_blk->NON;

  for my $exp(@{$rd->exps}) {
    $exp->findptrs();

  };

# ---   *   ---   *   ---

  $fr_blk->incpass();

  for my $exp(@{$rd->exps}) {
    $exp->exwalk();

  };

  $non->prich();

};

# ---   *   ---   *   ---

