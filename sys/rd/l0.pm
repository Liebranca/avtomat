#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:L0
# Byte-sized chunks
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::l0;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';
  use Style;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# what to do with chars

sub charset($class) { return {

  ';'   => 'term',
  '"'   => 'string',
  "'"   => 'string',

  ' '   => 'blank',
  "\t"  => 'blank',
  "\r"  => 'blank',
  "\n"  => 'line',

  '#'   => 'comment',


  (map {$ARG=>'operator_single'} qw(
    $ % : + - *),','

  ),

  (map {$ARG=>'delim_beg'} qw~( [ {~),
  (map {$ARG=>'delim_end'} qw~) ] }~),


}};

# ---   *   ---   *   ---
# read input char

sub read($class,$rd,$JMP,$c) {

  # save current char
  $rd->{char}=$c;


  # reader set to stringmode?
  if($rd->string()) {
    $class->default($rd);

    return 'default';

  # ^nope, process normally
  } else {

    # get proc for this char
    my $fn=$JMP->[ord($c)];

    # ^invoke and go next
    $class->$fn($rd);


    return $fn;

  };

};

# ---   *   ---   *   ---
# read single expression

sub proc_single($class,$rd,$srcref) {

  my $JMP   = $class->load_JMP();
  my @chars = split $NULLSTR,$$srcref;

  # consume up to term
  while(@chars) {

    my $c  = shift @chars;
    my $fn = $class->read($rd,$JMP,$c);

    last if $fn eq 'term';

  };

  # re-assemble string without consumed
  $$srcref=join $NULLSTR,@chars;

};

# ---   *   ---   *   ---
# ^read whole

sub proc($class,$rd,$src) {

  my $JMP=$class->load_JMP();

  map   {$class->read($rd,$JMP,$ARG)}
  split $NULLSTR,$src;


  return;

};

# ---   *   ---   *   ---
# standard char proc

sub default($class,$rd) {
  $rd->{token} .= $rd->{char};
  $rd->unset('blank');

};

# ---   *   ---   *   ---
# whitespace

sub blank($class,$rd) {

  # terminate *token* if first blank
  if(! $rd->blank()) {
    $class->commit($rd);

  };

  $rd->set('blank');

};

# ---   *   ---   *   ---
# ^tick line counter

sub line($class,$rd) {
  $rd->{lineno}++;
  $class->blank($rd);

};

# ---   *   ---   *   ---
# begin stringmode

sub string($class,$rd,$term=undef) {

  $rd->unset('blank');

  $term //= $rd->{char};

  $class->commit($rd);
  $rd->{token}="[\%$rd->{char}] ";

  $rd->set('string');
  $rd->{strterm}=$term;

};

# ---   *   ---   *   ---
# ^same mechanic, but terminator
# is a newline

sub comment($class,$rd) {
  $class->string($rd,"\n");
  $rd->set('comment');

};

# ---   *   ---   *   ---
# nesting

sub nest_up($class,$rd) {
  push @{$rd->{nest}},$rd->{branch};
  $class->new_branch($rd);

};

sub nest_down($class,$rd) {
  $rd->{branch}=pop @{$rd->{nest}};

};

# ---   *   ---   *   ---
# delimiters

sub delim_beg($class,$rd) {

  $rd->set('blank');
  $rd->set('term');

  $class->commit($rd);

  $rd->{token}="[\*$rd->{char}]";
  $class->commit($rd);

  $class->nest_up($rd);

};

sub delim_end($class,$rd) {

  # no token?
  if(! $class->commit($rd)) {

    # clear if last expr is empty!
    $rd->{branch}->discard()

    if  $rd->{branch}
    &&! @{$rd->{branch}->{leaves}}

    ;

  };


  $class->nest_down($rd);

  $rd->set('blank');
  $rd->set('term');

};

# ---   *   ---   *   ---
# expression terminator

sub term($class,$rd) {

  if(! $rd->term()) {
    $class->commit($rd);
    $class->new_branch($rd);

  };

  $rd->set('term');
  $rd->set('blank');

};

# ---   *   ---   *   ---
# clear current if not nesting
# else make sub-branch

sub new_branch($class,$rd) {

  if(! @{$rd->{nest}}) {
    $rd->{branch}=undef;

  } else {

    my $anchor = $rd->{nest}->[-1];
       $anchor = $anchor->{leaves}->[-1];

    my $idex   = int @{$anchor->{leaves}};

    $rd->{branch}=$anchor->inew(
      "[$idex]"

    );

  };

};

# ---   *   ---   *   ---
# argument separator

sub operator_single($class,$rd) {

  return $class->default($rd)
  if $rd->cmd_name_rule();

  $class->commit($rd);
  $rd->{token}="[*$rd->{char}] ";

  $class->commit($rd);

};

# ---   *   ---   *   ---
# push token to tree

sub commit($class,$rd) {

  # have token?
  my $have=0;

  if(length $rd->{token}) {

    # start of new branch?
    if(! defined $rd->{branch}) {
      $rd->{branch}=$rd->{tree}->inew($rd->{token});

    # ^cat to existing
    } else {
      $rd->{branch}->inew($rd->{token});

    };

    $have |= 1;

  };


  # give true if token added
  $rd->{token}=$NULLSTR;
  return $have;

};

# ---   *   ---   *   ---
# generates l0 jump table

sub load_JMP($class) {

  my $charset=$class->charset();

  return [map {

    my $key   = chr($ARG);
    my $value = (exists $charset->{$key})
      ? $charset->{$key}
      : 'default'
      ;

    $value;

  } 0..127];

};

# ---   *   ---   *   ---
1; # ret
