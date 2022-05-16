#!/usr/bin/perl
# ---   *   ---   *   ---
# LYPERL
# Makes Perl even cooler
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package lyperl;
  use strict;
  use warnings;

  use Filter::Util::Call;

  use lib $ENV{'ARPATH'}.'/avtomat/';

  use lang;
  use peso::node;
  use peso::program;

# ---   *   ---   *   ---

sub import {

  my ($type)=@_;
  my ($ref)={

    lline_exp=>0,

    killed=>0,
    lineno=>1,
    in_doc_block=>0,

    macros=>{},

    unpro=>[],
    exps=>[],
    strings=>[],

    docs_accum=>'',

  };filter_add(bless $ref);

};

# ---   *   ---   *   ---

sub read_doc_block($$$) {

  my $self=shift;
  my $s=shift;

  my $first_frame=shift;

  my $ode=$self->{in_doc_block}->[0];
  my $cde=$self->{in_doc_block}->[1];
  my $doc=\$self->{in_doc_block}->[2];
  my $lvl=\$self->{in_doc_block}->[3];

  my $len=length $cde;

  my $rem;if($first_frame) {
    ($s,$rem)=split ':__CUT__',$s;
    $self->{in_doc_block}->[4]=$s;

  } else {
    ($s,$rem)=('',$s);

  };

# ---   *   ---   *   ---
# iter the doc block line

  my $i=0;
  my $accum='';

  my @ar=split '',$rem;

  for my $c(@ar) {

    my $last=$ar[$i-(1*$i>0)];
    my $next=$ar[$i+(1*$i<$#ar)];

    my $term=substr $rem,$i,$i+$len;

# ---   *   ---   *   ---
# close char downs the depth if not escaped

    if($c eq $cde && $last ne '\\') {

      if($$lvl) {
        $$doc.=$c;

      };$$lvl--;

      if($$lvl<0) {last;};

# ---   *   ---   *   ---
# open char ups the depth if not escaped

    } elsif($c eq $ode && $last ne '\\') {
      $$lvl++;
      $$doc.=$c;

# ---   *   ---   *   ---
# =<<EOF (or similar) reached

    } elsif($len>1 && $term eq $cde) {
      $$lvl=-1;last;

# ---   *   ---   *   ---
# do not append BS if followed
# by open/close char

    } elsif(!(

          $c eq '\\'
      && ($next ne $cde || $next eq $ode)

      )

    ) {$$doc.=$c;};$i++;

  };

# ---   *   ---   *   ---

  if($$lvl<0) {

    my $id=sprintf(
      ':__MLS_CUT_%04X__:',
      int(@{$self->{strings}})

    );

    $s=$self->{in_doc_block}->[4].
      $id.(substr $rem,$i,length $cde);

    $accum=join '',@ar[$i+length $cde..$#ar];

    push @{$self->{strings}},$$doc;
    $self->{in_doc_block}=0;

  };return ($s,$accum);
};

# ---   *   ---   *   ---

sub tokenize_doc($$) {

  my $self=shift;
  my $s=shift;

  my @odes=split '','([{/';
  my %cdes=(

    '('=>')',
    '['=>']',
    '{'=>'}',
    '/'=>'/',

  );for my $c(@odes) {
    $c='\\'.$c;

  };

# ---   *   ---   *   ---

  my $cde='';
  my $ode='';

  my $first_frame=0;
  my $rem='';

  TOP:

  if(!$self->{in_doc_block}) {

    my $pat;
    if($s=~ m/\$[\w][_\w\d]*\.?=<<([\w][_\w\d]*)/) {
      $pat='(\$[\w][_\w\d]*\.?=<<([\w][_\w\d]*))';

      $cdes{$1}=$1;
      push @odes,$1;

    } else {
      my $odes='('.(join '|',@odes).')';
      $pat='(\bq[q|w]?\s*'.$odes.')';

    };

    if($s=~ s/${pat}/$1:__CUT__/) {

      my $ode=$2;
      my $cde=$cdes{$ode};

      $self->{in_doc_block}=[
        $ode,$cde,'',0

      ];

    };$first_frame=1;

# ---   *   ---   *   ---

  };if($self->{in_doc_block}) {

    ($s,$rem)=$self->read_doc_block(
      $s,$first_frame

    );

    if(!$self->{in_doc_block}) {

      if(length $rem) {

        $self->{docs_accum}.=$s;
        $s=$rem;

        goto TOP;

      } else {

        $s=$self->{docs_accum}.$s;
        $self->{docs_accum}='';

        $first_frame=0;

      };

    };

# ---   *   ---   *   ---

  } else {

    if($self->{docs_accum}) {
      $s=$self->{docs_accum}.$s;
      $self->{docs_accum}='';

    };$first_frame=0;

  };

  return ($first_frame)

    ? ''
    : $s

    ;

# ---   *   ---   *   ---
# abstracts away blocks that
# need to be kept intact

};sub mangle($$) {

  my $self=shift;
  my $s=shift;

  $s=$self->tokenize_doc($s);

  if(!length lang::stripline($s)) {
    return;

  };

  my $matches;

  $s=lang::mcut(

    $s,$self->{strings},

    'DQ'=>lang::dqstr,
    'SQ'=>lang::sqstr,
    'RE'=>lang::restr,

  );

  push @{$self->{unpro}},$s;

# ---   *   ---   *   ---
# demangles the accumulated code strings

};sub restore($) {

  my $self=shift;
  my $s='';

# ---   *   ---   *   ---
# replace string tokens

  for my $exp(@{$self->{exps}}) {
    $s.=lang::stitch($exp.';',$self->{strings});

  };return $s;
};

# ---   *   ---   *   ---

sub expsplit($) {

  my $self=shift;
  my @exps=
    split m/([\{\}])|;/,(join '',@{$self->{unpro}});

  my $root=peso::node::nit(undef,'ROOT');
  my @ances=();

  peso::program::nit();

# ---   *   ---   *   ---

  my $anchor=$root;
  my $last=$root;

  for my $exp(@exps) {

    if(defined $exp && length lang::stripline($exp)) {

      if($exp eq '{') {
        push @ances,$anchor;
        $anchor=$last;
        next;

      } elsif($exp eq '}') {

        $anchor=pop @ances;
        next;

      };

# ---   *   ---   *   ---

      $exp=~ s/^\s*|\s*$//sg;
      $exp=~ s/([_\w][_\w\d]*)\s+|\$|\@|\%//;

      my $hed=$1;

      $last=$anchor->nit($hed);
      if(defined $exp) {
        $last->tokenize($exp);

      };

    };
  };

# ---   *   ---   *   ---

  ;

  $root->prich();

};

# ---   *   ---   *   ---

sub filter {

  my ($self)=@_;
  my $status=filter_read();

# ---   *   ---   *   ---

  if( (!length lang::stripline($_)

      && !$self->{in_doc_block}

      )

  || m/^\s*#/

  ) {

# ---   *   ---   *   ---

    if($status<=0 && !$self->{killed}) {

      $self->expsplit();
#      $_=$self->restore();
#
#      $self->{killed}=1;
#      $status=1;

    };return $status;

  };

# ---   *   ---   *   ---

  my $s=$_;$_='';

  $self->mangle($s);
  $self->{lineno}++;

  $status;

};

# ---   *   ---   *   ---
1; # ret

