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

# ---   *   ---   *   ---

sub import {

  my ($type)=@_;
  my ($ref)={

    lline_exp=>0,

    line=>'',
    lineno=>1,
    in_doc_block=>0,

    macros=>{},

    unpro=>[],
    exps=>[],
    docs=>{},

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

  my $rem;if($first_frame) {
    ($s,$rem)=split ':__CUT__',$s;
    $self->{in_doc_block}->[4]=$s;

  } else {
    ($s,$rem)=('',$s);

  };

# ---   *   ---   *   ---
# iter the doc block line

  my $i=0;
  my @ar=split '',$rem;

  for my $c(@ar) {

    my $last=$ar[$i-(1*$i>0)];
    my $next=$ar[$i+(1*$i<$#ar)];

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
      ':__MLS_CUT_%04i__:',
      int(keys %{$self->{docs}})

    );$s.=
      $self->{in_doc_block}->[4].
      $id.(substr $rem,$i,-1);

    $self->{docs}->{$id}=$$doc;
    $self->{in_doc_block}=0;

  };return $s;
};

# ---   *   ---   *   ---

sub tokenize_doc($$) {

  my $self=shift;
  my $s=shift;

  my $odes='([\(|\[|\{|\/])';
  my %cdes=(

    '('=>')',
    '['=>']',
    '{'=>'}',
    '/'=>'/',

  );

# ---   *   ---   *   ---

  my $cde='';
  my $ode='';

  my $first_frame=0;
  my $last_frame=0;

  if(!$self->{in_doc_block}) {
    if($s=~ s/(.*q[q|w]?\s*${odes})/$1:__CUT__/) {

      my $ode=$2;
      my $cde=$cdes{$ode};

      $self->{in_doc_block}=[
        $ode,$cde,'',0

      ];

    };$first_frame=1;

# ---   *   ---   *   ---

  };if($self->{in_doc_block}) {
    $s=$self->read_doc_block($s,$first_frame);

    $last_frame=!$self->{in_doc_block};

  };return ($first_frame)

    ? ('',$last_frame)
    : ($s,$last_frame)

    ;

# ---   *   ---   *   ---

};sub mangle($$) {

  my $self=shift;
  my $s=shift;

  my $hasdoc=0;

  ($s,$hasdoc)=$self->tokenize_doc($s);
  if(!length lang::stripline($s)) {
    return;

  };

  my $matches;

  ($s,$matches)=lang::mcut(

    $s,

    'DQ'=>lang::dqstr,
    'SQ'=>lang::sqstr,
    'RE'=>lang::restr,

  );

  push @{$self->{unpro}},[$s,$matches];

  #printf "$s\n";

# ---   *   ---   *   ---

};sub restore($) {

  my $self=shift;
  my @ar=@{$self->{unpro}};

  my $s='';
  while(@ar) {

    my $ref=shift @ar;
    my $sub=lang::mstitch($ref->[0],$ref->[1]);

    for my $key(keys %{$self->{docs}}) {

      my $mls=$self->{docs}->{$key};
      if($sub=~ s/${key}/$mls/) {
        delete $self->{docs}->{$key};

      };

    };$s.=$sub;

  };printf "$s\n";
};

# ---   *   ---   *   ---

sub filter {

  my ($self)=@_;
  my $status=filter_read();

  if(
      $status<=0
  ||  !length lang::stripline($_)
  || m/^\s*#/

  ) {

    if($status<=0) {
      $self->restore();

    };return $status;

  };my $s=$_;

# ---   *   ---   *   ---

  # not a multi-line bit
  if($self->{lline_exp}) {
    $self->{line}=$s;

  # the other way around
  } else {
    $self->{line}.=$s;

  };

# ---   *   ---   *   ---

  $self->mangle($s);$_='';
  $self->{lineno}++;

  return $status;

};

# ---   *   ---   *   ---
1; # ret

