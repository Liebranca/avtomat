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

  our $VERSION = v0.00.3;#b
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

    hexn  => qr{\$  [0-9A-Fa-f\.:]+}x,
    octn  => qr{\\ [0-7\.:]+}x,
    binn  => qr{0b  [0-1\.:]+}x,
    decn  => qr{[0-9\.:]+}x,

    dqstr => qr{"([^"]|\\")*?"},
    sqstr => qr{'([^']|\\')*?'},

    vstr  => qr{v[0-9]\.[0-9]{2}\.[0-9][ab]?},

    sigil=>Lang::eiths(

      [qw(

        $ $: $:% $:/

        %% %

        / // /: //:
        @ @:

        ~:

        * : -- - ++ + ^ &

        >> >>: << <<:

        |> &>

      )],

      escape=>1

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

    hexn=>\&Lang::pehexnc,
    octn=>\&Lang::peoctnc,
    binn=>\&Lang::pebinnc,

  );

  for my $type(keys %converter) {

    my $fn=$converter{$type};

    map {

      $ARG->{value}=$fn->(
        $ARG->{value}

      );

    } $branch->branches_in(
      $REGEX->{$type}

    );

  };

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
    ct   => $ct,

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
    ct   => $ct,

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

  $branch->{value}={

    sigil => $st->{sigil},
    name  => $st->{$type},

    type  => $type,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# combo

  rule(q[

    |<value>
    &value_sort

    num str flg sigil bare seal

  ]);

# ---   *   ---   *   ---
# ^handler

sub value_sort($self,$branch) {

  state $is_re=qr{^\< (?<id> [^>]+) \>$}x;

  my $st     = $branch->bhash();
  my $xx     = $branch->leaf_value(0);

  my ($type) = keys %$st;

  if(is_hashref($xx)) {
    $type='flg';

  };

  $branch->clear();

  my $o={};

  if(defined $st->{$type}) {

    my $raw=$st->{$type};

    if($type eq 'seal' && $raw=~ $is_re) {

      $o={

        type => 're',

        seal => $+{id},
        raw  => $raw,

      };

    } else {

      $o={
        type => $type,
        raw  => $st->{$type}

      };

    };

  } else {

    $o={
      type => $type,
      raw  => $xx,

    };

  };

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
  $O{give_raw}//=1;

  my $out=$v;

  if($self->needs_deref($v)) {
    my $fn = $v->{type} . '_vex';
    $out   = $self->$fn($v);

  };

  return ($O{give_raw} && is_hashref($v))
    ? $out->{raw}
    : $out
    ;

};

# ---   *   ---   *   ---
# ^check value can be derefenced

sub needs_deref($self,$v) {

  state $re=qr{(?:seal|bare|str|flg|re|ops)};

  return
     is_hashref($v)
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


  return 1 if ! $self->needs_deref($v);

  my $o=$self->deref($v,give_raw=>0);
  return (defined $o->{const})
    ? $o->{const}
    : 0
    ;

};

# ---   *   ---   *   ---
# ^bat

sub array_const_deref($self,@ar) {
  return int(grep {
    $self->const_deref($ARG)

  } @ar) eq @ar;

};

# ---   *   ---   *   ---
# value expansion

sub vex($self,$fet,$vref,@path) {

  my $mach=$self->{mach};

  # default to current scope
  @path=$mach->{scope}->path()
  if ! @path;

  my $out=$mach->{scope}->cderef(
    $fet,$vref,@path,q[$LIS]

  ) or $mach->{scope}->cderef(
    $fet,$vref,@path

  );

  return $out;

};

# ---   *   ---   *   ---
# ^bat

sub array_vex($self,$fet,$ar,@path) {

  my @ar=@$ar;

  for my $v(@ar) {
    $self->vex($fet,\$v,@path);

  };

  my $valid=int(
    grep {defined $ARG} @ar

  ) eq @ar;

  my @out=($valid)
    ? @ar
    : ()
    ;

  return @out;

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
  return {%$o};

};

# ---   *   ---   *   ---
# ^unary calls

sub flg_vex($self,$o) {

  my $raw  = $o->{raw};
  my $out  = $NULLSTR;

  my $mach = $self->{mach};
  my @path = $mach->{scope}->path();

  if($raw->{sigil} eq q[~:]) {

    my $rem=$mach->{scope}->get(
      @path,q[~:rematch]

    );

    my $key=$raw->{name};
    $out=pop @{$rem->{$key}};

  };

  return {%$o,raw=>$out};

};

# ---   *   ---   *   ---
# ^strings

sub str_vex($self,$o) {

  my $raw   = $o->{raw};
  my $const = 1;

  my $re    = $REGEX->{repl};
  my $ct    = $raw->{ct};

  if($raw->{ipol}) {

    while($ct=~ $re) {

      my $name  = $+{capt};
      my $value = $self->bare_vex($name)->{raw};

      $ct     =~ s[$re][$value];
      $const &=~ 1;

    };

    nobs(\$ct);

  };

  return {%$o,const=>$const,raw=>$ct};

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
    $raw->{ct}=~ s[^(?:['"])|(?:['"])$][]sxmg;
    $$vref->{raw}=$raw;

  };

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
