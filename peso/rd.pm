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

};sub in_mls_block {

  my $self=shift;
  my $new=shift;

  if(defined $new) {
    $self->{-IN_MLS}=$new;

  };return $self->{-IN_MLS};

};sub mls_accum {

  my $self=shift;
  my $new=shift;

  if(defined $new) {
    $self->{-MLS_ACCUM}=$new;

  };return $self->{-MLS_ACCUM};

};

# ---   *   ---   *   ---

sub exps {return (shift)->{-EXPS};};
sub program {return (shift)->{-PROGRAM};};
sub lang {return (shift)->program->lang;};
sub strings {return (shift)->{-STRINGS};};
sub raw {return (shift)->{-RAW};};

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

    -MLS_ACCUM=>'',
    -IN_MLS=>undef,

    -RAW=>[],
    -STRINGS=>[],

  },'peso::rd';

};

# ---   *   ---   *   ---
# flags

  use constant {
    FILE=>0x00,
    STR=>0x01,

  };

# ---   *   ---   *   ---

sub mls_block($$) {

  my ($self,$first_frame)=@_;

  my $ode=$self->in_mls_block->[0];
  my $cde=$self->in_mls_block->[1];
  my $doc=\$self->in_mls_block->[2];
  my $lvl=\$self->in_mls_block->[3];

  my ($s,$rem);

  if($first_frame) {
    ($s,$rem)=split ':__CUT__',$self->line;
    $self->in_mls_block->[4]=$s;

  } else {
    ($s,$rem)=('',$self->line);

  };

# ---   *   ---   *   ---
# iter the doc block line

  my $i=0;
  my $accum='';
  my $tok='';

  my @ar=split '',$rem;

  for my $c(@ar) {

    $tok.=$c;

# ---   *   ---   *   ---
# close char downs the depth

    if($cde=~ m/^\Q${tok}/) {

      if($tok=~ m/^${cde}/) {

        if($$lvl) {
          $$doc.=$tok;
          $tok='';

        };$$lvl--;

        if($$lvl<0) {$i++;last;};

      };$i++;next;

# ---   *   ---   *   ---
# open char ups the depth

    } elsif($ode=~ m/^\Q${tok}/) {

      if($tok=~ m/^${ode}/) {

        $$lvl++;
        $$doc.=$tok;
        $tok='';

      };$i++;next;

# ---   *   ---   *   ---
# no match

    } else {$$doc.=$tok;$tok='';};$i++;


  };

# ---   *   ---   *   ---

  if($$lvl<0) {

    my $id=sprintf(
      lang::cut_token_f(),
      'MLS',int(@{$self->strings})

    );

    $s=$self->in_mls_block->[4].
      $id.(substr $rem,$i,length $cde);

    $accum=join '',@ar[$i+length $cde..$#ar];

    push @{$self->strings},$ode.$$doc;
    $self->in_mls_block(0);

  };

  $self->line($s);
  $self->rem($accum);

};

# ---   *   ---   *   ---
# abstracts away preprocessor, strings
# and related blocks that escape
# common interpretation

sub tokenize_block($) {

  my $self=shift;
  my $lang=$self->lang;
  my $matchtab=$lang->del_mt;

  my $first_frame=0;

# ---   *   ---   *   ---
# check for mls block beg

  TOP:if(!$self->in_mls_block) {

    my $pat=$lang->mls_rule->($lang,$self->line);
    if(!defined $pat) {goto END;};

    if($self->{-LINE}=~ s/^(.*)${pat}/$1:__CUT__/) {

      my $ode=$2;
      my $cde=$matchtab->{$ode};

      $self->in_mls_block([
        $ode,$cde,'',0

      ]);

    };$first_frame=1;

# ---   *   ---   *   ---
# beg found/processing pending

  };if($self->in_mls_block) {
    $self->mls_block($first_frame);

# ---   *   ---   *   ---
# new mls beg

    if(!$self->in_mls_block) {

      if(length lang::stripline($self->rem)) {

        $self->mls_accum(
          $self->mls_accum.
          $self->line

        );

        $self->line($self->rem);
        $self->rem('');

        goto TOP;

# ---   *   ---   *   ---
# no mls blocks pending

      };
    };

  };END:if(

       !$self->in_mls_block
    && $self->mls_accum

  ) {

    $self->line(
      $self->mls_accum.
      $self->line

    );

    $self->mls_accum('');
    $self->rem('');

  };
};

# ---   *   ---   *   ---
# abstracts away blocks that
# need to be kept intact

sub mangle($) {

  my $self=shift;

  #$self->tokenize_block();
  if(!length lang::stripline($self->line)) {
    return;

  };

# ---   *   ---   *   ---

  $self->line(lang::mcut(

    $self->line,
    $self->strings,

    $self->lang->mcut_tags,

  ));push @{$self->raw},$self->line;

};

# ---   *   ---   *   ---
# sanitize line of code

sub clean {

  my $self=shift;
  my $lang=$self->lang;

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
# SL AND ML EXPS DEPRECATED
# change these two subs to
# lang-specific methods

# ---   *   ---   *   ---
# single-line expressions

sub slexps($) {

  my $self=shift;
  $self->join_rem();

  my $lang=$self->lang;
  $lang->exp_rule->($self);

  my $eb=$lang->exp_bound;
  my $sb=$lang->scope_bound;

  my @ar=split

    m/(${sb})|${eb}$|${eb}/,
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

sub mlexps($) {

  my $self=shift;
  my $lang=$self->lang;

  my $eb=$lang->exp_bound;
  my $sb=$lang->scope_bound;

  $lang->exp_rule->($self);
  my @ar=split

    m/(${sb})|${eb}/,
    $self->line

  ;

  my $entry=pop @ar;

  # separate curls
  for my $e(@ar) {

    if(!defined $e || !length $e) {
      next;

    };push @{$self->exps},$e;

  };if($entry) {$self->rem($self->rem.$entry);};

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

  my $lang=$self->lang;
  my $hed=$lang->hed;

  # open file
  $self->{-FNAME}=glob(shift);open

    my $FH,'<',
    $self->{-FNAME} or die $!

  ;$self->{-FHANDLE}=$FH;

  # verify header
  my $line=readline $self->{-FHANDLE};
  if($hed eq 'N/A') {goto SKIP;};

  if(!($line=~ m/^${hed}/)) {
    printf STDERR $self->{-FNAME}.": bad header\n";
    fclose();

    exit;

  };

  SKIP:
  $self->line($line);

  # get remains
  $self->{-LINE}=~ s/^${hed}//;
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
  my $lang=$self->lang;

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
  $self->mangle();

# ---   *   ---   *   ---
# pass body of file through mangler

  while(my $line=readline $self->{-FHANDLE}) {
    $self->line($line);
    $self->mangle();

  };

  # close file
  $self->fclose();

# ---   *   ---   *   ---
# iter mangled

  for my $line(@{$self->raw}) {
    $self->line($line);
    $self->procline();

  };

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
    if($l) {push @filtered,$l."\n";};

  };

# ---   *   ---   *   ---
# pass str through mangler

  while(@filtered) {
    $self->line(shift @filtered);
    $self->mangle();

  };

# ---   *   ---   *   ---
# iter mangled

  for my $line(@{$self->raw}) {
    $self->line($line);
    $self->procline();

  };

};

# ---   *   ---   *   ---

sub no_blanks($) {

  my $self=shift;
  my @ar=();

  for my $exp(@{$self->exps}) {

    if(length lang::stripline($exp)) {
      push @ar,$exp;

    };
  };

  $self->{-EXPS}=\@ar;

};

# ---   *   ---   *   ---

sub mam {

  my $lang=shift;
  my $mode=shift;
  my $src=shift;

  my $program=peso::program::nit($lang);
  my $rd=nit($program);

  (\&file,\&string)[$mode]->($rd,$src);

  if($rd->rem) {
    $rd->line($rd->rem);
    $rd->lang->exp_rule->($rd);

  };$rd->no_blanks();

# ---   *   ---   *   ---

  my $fr_node=$program->node;
  my $fr_ptr=$program->ptr;
  my $fr_blk=$program->blk;

  for my $exp(@{$rd->exps}) {

    my $body=$exp;
    if($body=~ m/\{|\}/) {
      $exp=$fr_node->nit(undef,$body);

    } else {

      $exp=$fr_node->nit(undef,'void');

      $exp->tokenize($body);
#      $exp->agroup();

#      $exp->subdiv();

#      $exp->collapse();

#      $exp->reorder();
#      $exp->exwalk();

    };

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

