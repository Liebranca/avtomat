#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO RE
# Line noise
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::re;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::String;
  use Arstd::IO;
  use Arstd::PM;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;

  use Grammar;
  use Grammar::peso::common;
  use Grammar::peso::value;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PE_RE $PE_RE_FLAGS);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

# ---   *   ---   *   ---
# class attrs

  sub Frame_Vars($class) { return {
    %{$PE_COMMON->Frame_Vars()},

  }};

  Readonly our $PE_RE_FLAGS=>{
    -qwor   => 0,
    -insens => 0,
    -escape => 0,
    -sigws  => 0,

  };

  Readonly our $RE_FN=>[
    -qwor   => q[qwor],
    -sigws  => q[sigws],

  ];

  Readonly our $PE_RE=>
    'Grammar::peso::re';

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    %{$PE_COMMON->get_retab()},

    q[re-type]=>Lang::eiths(

      [qw(re)],

      bwrap  => 1,
      insens => 1,

    ),

  };

# ---   *   ---   *   ---
# rule imports

  ext_rule($PE_COMMON,qw(nterm));
  ext_rule($PE_VALUE,qw(seal));

# ---   *   ---   *   ---
# regex definitions

  rule('~<re-type>');
  rule('$<re> &rdre re-type seal nterm');

# ---   *   ---   *   ---
# ^ipret

sub rdre($self,$branch) {

  my $st=$branch->bhash(0,0,0);

  $branch->{value}={

    type  => $st->{q[re-type]},

    raw   => $st->{nterm},
    seal  => $st->{seal},

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^branch expansion

sub rdre_ctx($self,$branch) {

  my $st=$branch->{value};

  # ^expand and write to mem
  $st->{re}=$self->re_vex($st);
  $self->bind_re($branch);

};

# ---   *   ---   *   ---
# ^write expanded regex to mem

sub bind_re($self,$branch) {

  my $st    = $branch->{value};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $re    = $st->{re};

  # use expr name for capture
  # ie (?<name> expr)
  $re=q[(?<].$st->{seal}.q[>].$re.q[)];

  # is whitespace intolerant
  $re=(! $st->{flags}->{-sigws})
    ? qr{$re}x
    : qr{$re}
    ;

  # ^push to current namespace
  $scope->decl(

    $re,

    $scope->path(),

    $st->{type},
    $st->{seal},

  );

};

# ---   *   ---   *   ---
# ^value expansion

sub re_vex($self,$o) {

  # copy raw
  my $raw=$o->{raw};

  # ^transform
  my $out   = $self->detag($raw);
  my $flags = $self->apply_re_flags(
    $o->{seal},\$out

  );

  $o->{re}    = $out;
  $o->{flags} = $flags;

  return $out;

};

# ---   *   ---   *   ---
# ^expand <exprs> in re

sub detag($self,$raw) {

  my @tags=();

  # fetch every <expr> from scope
  # replace <expr> with placeholder token
  while($raw=~ s[$REGEX->{tag}][$Shwl::PL_CUT]) {

    push @tags,(join q[|],map {
      $self->fetch_re($ARG)

    } split q[\|],$+{capt});

  };

  # ^replace placeholder with
  # the expansion of <expr>
  for my $x(@tags) {
    $raw=~ s[$Shwl::PL_CUT_RE][$x];

  };

  return $raw;

};

# ---   *   ---   *   ---
# find defined expr in scope

sub fetch_re($self,$name) {

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  # break at ::
  my @npath = split $REGEX->{nsop},$name;
     $name  = pop @npath;

  # path::re::$s
  push @npath,'re',$name;

  # ^search in current namespace
  my $rer=$scope->search(
    (join q[::],@npath)

  );

  return $$rer;

};

# ---   *   ---   *   ---
# fetch regex parse flags from ctx

sub get_re_flags($self) {

  my $out   = {};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};
  my @path  = $scope->path();

  map {
    $out->{$ARG}=$scope->get(@path,$ARG)

  } keys %$PE_RE_FLAGS;

  return $out;

};

# ---   *   ---   *   ---
# apply transforms to regex
# accto parser flags

sub apply_re_flags($self,$id,$sref) {

  state %tab=@$RE_FN;

  my $flags=$self->get_re_flags();

  map {

    my $f="re_flags_$tab{$ARG}";
    $self->$f($sref,$flags);

  } array_keys($RE_FN);

  return $flags;

};

# ---   *   ---   *   ---
# significant whitespace turned off

sub re_flags_sigws($self,$sref,$flags) {

  state $re=qr{[\s\n]+};

  $$sref=~ s[$re][ ]sxmg
  if ! $flags->{-sigws};

};

# ---   *   ---   *   ---
# perl qw() style lists

sub re_flags_qwor($self,$sref,$flags) {

  if($flags->{-qwor}) {

    my @ar=split $SPACE_RE,$$sref;
    array_filter(\@ar);

    $$sref=Lang::eiths(

      \@ar,

      escape=>$flags->{-escape},
      insens=>$flags->{-insens},

    );

  };

};

# ---   *   ---   *   ---
# ^generate parser tree

  our @CORE=qw(re);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
