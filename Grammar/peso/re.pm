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

    nterm => $st->{nterm},
    seal  => $st->{seal},

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^branch expansion

sub rdre_ctx($self,$branch) {

  my $st   = $branch->{value};

  my $mach = $self->{mach};
  my @path = $mach->{scope}->path();

  # dereference
  my ($o,$flags)=$self->re_vex($st->{nterm});

  # use expr name for capture
  # ie (?<name> expr)
  $o=q[(?<].$st->{seal}.q[>].$o.q[)];

  # re is whitespace intolerant
  $o=(! $flags->{-sigws})
    ? qr{$o}x
    : qr{$o}
    ;

  # push to current namespace
  $mach->{scope}->decl(

    $o,

    @path,
    $st->{type},
    $st->{seal}

  );

};

# ---   *   ---   *   ---
# ^value expansion

sub re_vex($self,$o) {

  my $mach  = $self->{mach};
  my @path  = $mach->{scope}->path();
  my $flags = {};

  # fetch flags from ctx
  for my $key(keys %$PE_RE_FLAGS) {
    my $x=$mach->{scope}->get(@path,$key);
    $flags->{$key}=$x;

  };

  # expand <exprs> in re
  $o=$self->detag($o);

  # significant whitespace turned off
  if(! $flags->{-sigws}) {
    $o=~ s[[\s\n]+][ ]sxmg;

  };

  # perl qw() style lists
  if($flags->{-qwor}) {

    my @ar=split $SPACE_RE,$o;
    array_filter(\@ar);

    $o=Lang::eiths(

      \@ar,

      escape=>$flags->{-escape},
      insens=>$flags->{-insens},

    );

  };

  return ($o,$flags);

};

# ---   *   ---   *   ---
# ^solves compound regexes

sub detag($self,$o) {

  my @tags=();
  my $mach=$self->{mach};

  # fetch every <expr> from scope
  # replace <expr> with placeholder token
  while($o=~ s[$REGEX->{tag}][$Shwl::PL_CUT]) {

    push @tags,(join q[|],map {
      $self->fetch_re($ARG)

    } split q[\|],$+{capt});

  };

  # ^replace placeholder with
  # the expansion of <expr>
  for my $x(@tags) {
    $o=~ s[$Shwl::PL_CUT_RE][$x];

  };

  return $o;

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
# ^generate parser tree

  our @CORE=qw(re);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
