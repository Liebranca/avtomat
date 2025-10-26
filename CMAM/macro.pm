#!/usr/bin/perl
# ---   *   ---   *   ---
# CMAM MACRO
# pointed at your feet
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package CMAM::macro;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_coderef is_hashref);

  use Arstd::String qw(cat);
  use Arstd::throw;

  use lib "$ENV{ARPATH}/lib/";
  use CMAM::static qw(
    cmamdef
    cmamout
    cpackage
  );
  use CMAM::token qw(
    tokenshift
    semipop
  );
  use CMAM::parse qw(
    blk2expr
    type2expr
  );


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    macroguard
    macroload
    macrosave
    macroin
    macrofoot
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.7a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# base of every CMAM definition
#
# [0]: mem ptr ; code block capture
# [<]: null
#
# [!]: adds an actual subroutine to CMAM package

sub macro {
  # unpack && validate input
  my ($name,$type,$args,$blk)=macroin(
    $_[0],qw(type args blk)
  );

  # redef guard
  throw "Redefinition of macro '$name'"
  if exists cmamdef()->{$name};

  my $money_re=qr{^\$};
  for(@$args) {
    $ARG=~ s[$money_re][];
  };


  # need to handle arguments?
  if(@$args) {
    # slap the macroin bit (see above) into
    # the body of the new subroutine
    my $argline=cat(
      '$_[0]=macroguard([qw(',
      join(' ',@$args),
      ')],@_);',

      'my ($',
      join(',$',@$args),
      ')=macroin(',
      '$_[0],qw(',
      join(' ',@$args),
      '));'
    );

    # ^cleanup for that
    my $foot=cat(
      'macrofoot($_[0],',
      $args->[0],'=>$' . join(',$',@$args),
      ');'
    );
    unshift @$blk,$argline;
    my $ret=pop @$blk;
    push @$blk,$foot;
    push @$blk,$ret;
  };

  # ^assemble together with blocks to
  # ^make subroutine
  my $fnstr=cat("sub {",@$blk,"};");


  # generate and register new symbol
  macroload($name,$fnstr);
  macrosave($name,$fnstr);

  # defining a macro gives back nothing ;>
  return null;
};


# ---   *   ---   *   ---
# unpack && validate macro input
#
# [0]: mem  ptr  ; code block capture
# [1]: byte pptr ; argument names
#
# [<]: byte pptr ; args (new string array)
#
# [!]: throws on missing args

sub macroin {
  # get input keys
  my $capt  = shift;
  my @order = @_;

  # ^extract keys from capture
  my %O=map {
    throw "Missing macro param: '$ARG'"
    if ! exists $capt->{$ARG};

    # need to pop semis?
    semipop($capt->{$ARG});

    # give name => value
    $ARG=>$capt->{$ARG};

  } @order;


  # need to extract type and name?
  if(exists $O{type}) {
    type2expr($O{type});
    $O{name}=pop @{$O{type}};

    # put 'name' key into order
    # else it won't be returned ;>
    unshift @order,'name';
  };

  # extract argument names?
  if(exists $O{args}) {
    # NOTE: for macros, these are just which capts
    #       it'll check for
    my @args=split qr{\s*,\s*},$O{args};
    $O{args}=\@args;
  };

  # extract expressions from blk?
  blk2expr($O{blk}) if exists $O{blk};

  # give back values
  return map {$O{$ARG}} @order;
};


# ---   *   ---   *   ---
# ensures you can call a macro from
# within another by turning arguments
# passed asis into a capture hashref
#
# [0]: byte pptr ; list of argument names
# [1]: mem  ptr  ; first argument passed
#
# [<]: mem ptr ; capture hashref

sub macroguard {
  my $names=shift;
  if(! is_hashref($_[0])) {
    $_[0]={map {$ARG=>(shift @_)} @$names};
  };
  return $_[0];
};


# ---   *   ---   *   ---
# synchronizes capture with
# copies used within macro
#
# [0]: mem  ptr  ; capture hashref
# [1]: byte pptr ; list of argument names

sub macrofoot {
  my $capt=shift;
  for(keys %$capt) {
    $capt->{$ARG}=shift;
  };
  return;
};


# ---   *   ---   *   ---
# makes/reloads definitions
#
# [0]: byte ptr ; name of symbol
# [1]: byte ptr ; symbol definition
#
# [*]: writes to CMAMOUT

sub macrosave {
  tokenshift($_[1]);
  push @{cmamout()->{def}},"sub $_[0]$_[1]";
  return;
};


# ---   *   ---   *   ---
# makes/reloads definitions
#
# [0]: byte ptr  ; name of symbol
# [1]: byte fptr ; symbol definition
#                  OR pointer to defined symbol
#
# [!]: makes an actual subroutine

sub macroload {
  # need to make definition?
  my $fn=(! is_coderef($_[1]))
    ? eval "package CMAM::sandbox;$_[1]"
    : $_[1]
    ;

  # ^catch compile error
  throw "Cannot define macro '$_[0]'\n"
  .     "Definition: $_[1]"

  if ! defined $fn;


  # add symbol to internal command table
  #
  # this allows the macro to be recognized
  # when invoked from C code
  cmamdef()->{$_[0]}=$fn;

  # add symbol to current package's subroutines
  #
  # this allows the macro to be invoked from
  # within another, as you would in regular perl
  no strict 'refs';

  *{"CMAM\::sandbox\::$_[0]"}=$fn
  if ! defined *{$_[0]};

  use strict 'refs';
  return;
};


# ---   *   ---   *   ---
# sets namespace for CMAM defs
#
# [!]: header guards are affected by this;
#      the __last__ package essentially gets
#      to name the guards -- so careful

sub setpkg {
  # unpack && validate input
  $_[0]=macroguard([qw(expr)],@_);
  my ($expr)=macroin($_[0],qw(expr));

  # 'non' just means global scope
  $expr=null if $expr eq 'non';
  cpackage(lc $expr);

  $expr=null;
  macrofoot($_[0],qw(expr));
  return null;
};


# ---   *   ---   *   ---
1; # ret
