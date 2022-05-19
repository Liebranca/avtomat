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
  use lyperl::decls;

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
      lang::cut_token_f()
      'MLS',int(@{$self->{strings}})

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
  my $mangled=shift;

  # replace string tokens
  return lang::stitch($mangled,$self->{strings});

};

# ---   *   ---   *   ---

sub subst_iter($$) {

  my $self=shift;
  my $node=shift;

  my $leaf=$node->leaves->[0];
  if(!defined $leaf) {
    print "Symbol 'iter' requires $,$\n";
    exit;

  };

  my ($a,$b)=split m/\s*,\s*/,$leaf->val;
  $node->pluck($leaf);

  $node->{-VAL}="for my $a".'(@{'.$b.'})';

};

# ---   *   ---   *   ---

my %PROCS=();

sub subst_proc($$) {

  my $self=shift;
  my $node=shift;

  my ($name)=$node->pluck($node->leaves->[0]);
  $name=$name->val;

  $PROCS{$name}=[];

  my @args=();
  my $i=0;

  while(@{$node->leaves}) {

    my ($vtype,$vname)=$node->pluck(
      @{$node->leaves}[0,1]

    );

    push @args,[$vname->val=>$vtype->val];
    push @{$PROCS{$name}},$vtype->val;

    $i++;

  };

  $node->{-VAL}="sub $name(".('$'x$i).")";

  my $s='';
  for my $ref(@args) {
    my $key=$ref->[0];
    $s.='my '.$key."=shift;";

  };return $s;

};

# ---   *   ---   *   ---

sub expsplit($) {

  my $self=shift;
  my @exps=
    split m/([\{\};])/,(join '',@{$self->{unpro}});

  my $root=peso::node::nit(undef,'ROOT');
  my @ances=();

  peso::program::nit();

# ---   *   ---   *   ---

  my %keywords=(
    'iter'=>\&subst_iter,
    'proc'=>\&subst_proc,

  );

# ---   *   ---   *   ---

  my $vname=lyperl::decls::names;

  my $anchor=$root;
  my $last=$root;
  my $rem='';

  for my $exp(@exps) {

    if(defined $exp && length lang::stripline($exp)) {

      if($exp eq '{') {
        push @ances,$anchor;
        $anchor=$last;

      } elsif($exp eq '}') {
        $anchor=pop @ances;

      };

# ---   *   ---   *   ---

      $exp=~ s/^\s*|\s*$//sg;
      $exp=~ s/^${vname}//;

      my $hed=$1;

      if(defined $hed) {

        if(exists $keywords{$hed}) {

          $last=$anchor->nit($hed);
          $last->tokenize($exp);

          $rem=$keywords{$hed}->($self,$last);

        } elsif(exists $PROCS{$hed}) {

          $exp=~ s/^\s*|\s*$//sg;
          my @args=split m/\s*,\s*/,$exp;

          my $i=0;
          for my $type(@{$PROCS{$hed}}) {

            my @wrap=($type eq 'char')
              ? ('int','(',')')
              : ('','"','"')
              ;

            $args[$i]=

              "$wrap[0]$wrap[1]".

              $args[$i].
              "$wrap[2]";

            $i++;

          };my $exp=join ',',@args;

          $last=$anchor->nit($hed.' '.$exp);

        } else {
          $last=$anchor->nit($hed.' '.$exp);

        };

      } else {

        if($exp eq ';') {
          $last->{-VAL}.=$exp;
          next;

        };

        $last=$anchor->nit($exp);

        if($rem) {

          $anchor->nit($rem);
          $rem='';

        };

      };
    };
  };

# ---   *   ---   *   ---

  my $s='';
  my @leaves=(@{$root->leaves});

  TOP:my $leaf=shift @leaves;

  $s.=$leaf->val;
  $s.=('',"\n")[int($leaf->val=~ m/\{|;/)];

  if($leaf->leaves) {
    unshift @leaves,@{$leaf->leaves};

  };

# ---   *   ---   *   ---

  if(@leaves) {goto TOP;};
  END:return $s;

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

      $_=$self->restore(
        $self->expsplit()

      );

printf "$_\n";

      $self->{killed}=1;
      $status=1;

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

