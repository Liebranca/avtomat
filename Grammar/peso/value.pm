#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO VALUE
# Selfex sub-parser
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::value;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;

  use Grammar;
  use Grammar::peso::common;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PE_VALUE);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $PE_VALUE=>
    'Grammar::peso::value';

# ---   *   ---   *   ---
# GBL

BEGIN {

  our $REGEX={

    %{$PE_COMMON->get_retab()},

    bare=>qr{

      [_A-Za-z][_A-Za-z0-9:\.]*

    }x,

    seal=>qr{

      [_A-Za-z<]
      [_A-Za-z0-9:\-\.]+

      [_A-Za-z>]

    }x,

    hexn  => qr{\$ [0-9A-Fa-f][0-9A-Fa-f\.:]*}x,
    octn  => qr{\\ [0-7][0-7\.:]*}x,
    binn  => qr{0b  [0-1][0-1\.:]*}x,
    decn  => qr{[0-9][0-9\.:]*}x,

    dqstr => qr{"([^"]|\\")*?"},
    sqstr => qr{'([^']|\\')*?'},

    vstr  => qr{v[0-9]\.[0-9]{2}\.[0-9][ab]?},

    sigil=>re_eiths(

      [qw(

        $ $: $:% $:/

        %% %

        / // /: //:
        @ @:

        ~:

        * : -- - ++ + ^ & .

        >> >>: << <<:

        |> &>

      )],

      opscape=>1

    ),

  };

# ---   *   ---   *   ---
# numerical notations

  rule('~<hexn>');
  rule('~<octn>');
  rule('~<binn>');
  rule('~<decn>');

  # ^combined
  rule('|<num> &rdnum hexn octn binn decn');

# ---   *   ---   *   ---
# converts all numerical
# notations to decimal

sub rdnum($self,$branch) {

  state %converter=(

    hexn=>\&hstoi,
    octn=>\&ostoi,
    binn=>\&bstoi,

  );

  # ^match branches to subs
  map {

    # ^run on branch
    my $fn=$converter{$ARG};

    map {
      $ARG->{value}=$fn->(
        $ARG->{value}

      );

    } $branch->branches_in(
      $REGEX->{$ARG}

    );

  } keys %converter;

  Grammar::list_flatten($self,$branch);

};

# ---   *   ---   *   ---
# name types

  rule('~<bare>');
  rule('~<seal>');
  rule('~<sigil>');

# ---   *   ---   *   ---
# string types

  rule('~<dqstr>');
  rule('~<sqstr>');
  rule('~<vstr>');

  # ^combo
  rule('|<str> dqstr sqstr vstr');

# ---   *   ---   *   ---
# ipret double quoted

sub dqstr($self,$branch) {

  my $ct=$branch->leaf_value(0);
  return unless defined $ct;

  (  $branch->{is_cdef}->[0]
  || $ct=~ s[^"([\s\S]*)"$][$1]

  ) or throw_badstr($ct);

  charcon(\$ct);

  $branch->{value}={

    ipol => 1,
    raw  => $ct,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^single quoted

sub sqstr($self,$branch) {

  my $ct=$branch->leaf_value(0);
  return unless defined $ct;

  (  $branch->{is_cdef}->[0]
  || $ct=~ s[^'([\s\S]*)'$][$1]

  ) or throw_badstr($ct);

  $branch->{value}={

    ipol => 0,
    raw  => $ct,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^errme

sub throw_badstr($s) {

  errout(

    q[Malformed string: %s],

    args => [$s],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# soul of perl!

  rule('|<flg-name> &clip bare seal');
  rule('$<flg> sigil flg-name');

# ---   *   ---   *   ---
# ^post-parse

sub flg($self,$branch) {

  my $st   = $branch->bhash();
  my $type = (exists $st->{seal})
    ? 'seal'
    : 'bare'
    ;

  my $raw  = "$st->{sigil}$st->{$type}";

  $branch->{value}={

    q[flg-name] => $st->{$type},
    q[flg-type] => $type,

    sigil       => $st->{sigil},
    raw         => $raw,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# combo

  rule(q[

    |<value>
    &value_sort

    num str flg bare seal sigil

  ]);

# ---   *   ---   *   ---
# ^handler

sub value_sort($self,$branch) {

  state $is_re=qr{^\< (?<id> [^>]+) \>$}x;

  my $st = $branch->bhash();
  my $xx = $branch->leaf_value(0);
  my $o  = {};

  my ($type)=keys %$st;

  $branch->clear();

  if(is_hashref($xx)) {
    $type = 'flg';
    $o    = {%$xx};

  } elsif(defined $st->{$type}) {

    my $raw=$st->{$type};

    if($type eq 'seal' && $raw=~ $is_re) {

      $o={

        seal => $+{id},
        raw  => $raw,

      };

      $type='re';

    } else {
      $o={raw => $st->{$type}};

    };

  };

  if(is_hashref($o->{raw})) {

    my $raw=$o->{raw};
    delete $o->{raw};

    $o={%$o,%$raw};

  };

  $o=$self->{mach}->vice($type,%$o);
  $branch->init($o);

};

# ---   *   ---   *   ---
# get values in branch

sub find_values($self,$branch) {

  state $re=qr{^value$};

  return $branch->branches_in(
    $re,keep_root=>0

  );

};

# ---   *   ---   *   ---
# branch is value

sub is_value($self,$branch) {
  return $branch->{value} eq 'value';

};

# ---   *   ---   *   ---
# ^bat

sub array_is_value($self,@ar) {

  return int(grep {
   $self->is_value($ARG)

  } @ar) eq @ar;

};

# ---   *   ---   *   ---
# applies value expansion when needed

sub deref($self,$v,%O) {

  # defaults
  $O{ptr} //= 0;


  # skip non-blessed values
  my $out=$v;

  if($self->needs_deref($v)) {

    # call expansion F accto type
    my $fn  = $v->{type} . '_vex';
       $out = $self->$fn($v);

    # value expansion failed
    if(! $out) {
      $out=undef;

    # ^succesful
    } else {
      $out=($O{ptr})
        ? $out->deref()
        : $out
        ;

    };


  # ^ptr to non-complex type
  } elsif(

     Mach::Value->is_valid($v)
  && $O{ptr}

  ) {
    $out=$v->deref();

  };

  return $out;

};

# ---   *   ---   *   ---
# ^check value can be derefenced

sub needs_deref($self,$v) {

  state $re=qr{(?:seal|bare|str|flg|re|ops)};

  return

     Mach::Value->is_valid($v)
  && $v->{type}=~ $re
  ;

};

# ---   *   ---   *   ---
# ^bat

sub array_needs_deref($self,@ar) {

  return int(grep {
    $self->needs_deref($ARG)

  } @ar) eq @ar;

};

# ---   *   ---   *   ---
# check value is const

sub const_deref($self,$v) {

  my $o=$self->deref($v);

  if($o->{const}) {
    return $o;

  } else {
    return undef;

  };

};

# ---   *   ---   *   ---
# ^bat

sub array_const_deref($self,@ar) {

  my @results=grep {defined $ARG} map {
    $self->const_deref($ARG)

  } @ar;

  return (@results == @ar)
    ? @results
    : ()
    ;

};

# ---   *   ---   *   ---
# value expansion

sub vex($self,$fet,$vref,@path) {

  my $out   = undef;

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  # check vref in SYS
  my $sys=$scope->cderef($fet,$vref,'SYS');
  if($sys) {
    $out=$sys;

  # ^nope, lookup in path
  } else {

    # check vref is runtime alias
    my $lis=q[$LIS::].$$vref;
       $lis=$scope->cderef($fet,\$lis,@path);

    # ^matching alias found, recurse
    if($lis) {
      $out=\$self->deref($$lis);

    # ^nope, look up common table
    } else {
      $out=$scope->cderef(
        $fet,$vref,@path

      );

    };

  };

  return $out;

};

# ---   *   ---   *   ---
# ^name/ptr

sub bare_vex($self,$o) {

  my $raw=$o->{raw};
  my $out=$self->vex(0,\$raw);

  return ($out) ? $$out : undef;

};

# ---   *   ---   *   ---
# ^ptr to complex
# placeholder for now ;>

sub seal_vex($self,$o) {
  return $o;

};

# ---   *   ---   *   ---
# ^unary calls

sub flg_vex($self,$o) {

  my $raw  = $o->{raw};
  my $out  = $self->vex(0,\$raw);

# old stuff, needs rewrit
#
#  my $mach = $self->{mach};
#  my @path = $mach->{scope}->path();
#
#  if($o->{sigil} eq q[~:]) {
#
#    my $rem=$mach->{scope}->get(
#      @path,q[~:rematch]
#
#    )->{value};
#
#    my $key=$o->{name};
#    $out=pop @{$rem->{$key}};
#
#  } else {
#    $out=$raw;
#
#  };

  return ($out) ? $$out : undef;

};

# ---   *   ---   *   ---
# ^strings

sub str_vex($self,$o) {

  my $raw   = $o->{raw};
  my $const = 1;

  my $re    = $REGEX->{repl};

  # do string interpolation
  if($o->{ipol}) {

    while($raw=~ $re) {

      # get value of var
      my $name = $+{capt};
      my $ref  = $self->bare_vex({raw=>$name});

      last if ! defined $ref;

      # ^replace name with value
      my $s=$ref->{raw};

      $raw    =~ s[$re][$s];
      $const &=~ ! $ref->{const};

    };

    nobs(\$raw);

  };

  return $o->dup(
    raw   => $raw,
    const => $const,

  );

};

# ---   *   ---   *   ---
# re-parse string attached
# to value descriptor

sub value_expand($self,$vref) {

  return if ! is_hashref($$vref);

  my $type = $$vref->{type};
  my $raw  = $$vref->{raw};

  # ipret nums and bares
  if(! is_hashref($raw)) {

    my $t=$PE_VALUE->parse($raw,-r=>0);

    $t=$t->{p3}->{leaves}->[0];
    $$vref=$t->leaf_value(0);

  # ^an sre is enough for strings
  } elsif($type eq 'str') {
    $raw->{raw}=~ s[^(?:['"])|(?:['"])$][]sxmg;
    $$vref->{raw}=$raw;

  };

};

# ---   *   ---   *   ---
# get pointer to value

sub vstar($self,$o,@path) {

  my $raw=(is_blessref($o))
    ? $o->{raw}
    : $o
    ;

  return $self->vex(1,\$raw,@path);

};

# ---   *   ---   *   ---
# list patterns

  ext_rule($PE_COMMON,'clist');

  rule('$<bare-list> &list_flatten bare clist');
  rule('$<flg-list> &list_pop flg clist');

  rule('$<vlist> &list_flatten value clist');

  rule('?<opt-vlist> &clip vlist');

# ---   *   ---   *   ---
# ^generate parser tree

  our @CORE=qw(value);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
