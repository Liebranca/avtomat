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

  our $VERSION = v0.00.7;#a
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
  "\n"  => 'blank',

  '#'   => 'comment',


  (map {$ARG=>'operator_single'} qw(
    % : + - * < > =
    ! ? ~ & | ^ / @
    ` .

  ),','),

  (map {$ARG=>'delim_beg'} qw~( [ {~),
  (map {$ARG=>'delim_end'} qw~) ] }~),


}};

# ---   *   ---   *   ---
# read input char

sub read($class,$rd,$JMP,$c) {

  # save current char
  $rd->{char}=$c;


  # tick the line counter
  $rd->{lineno} += int($c eq "\n");

  # track beggining of first
  # nterm char in expr
  $rd->{lineat} = $rd->{lineno}
  if $rd->exprbeg();


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

sub proc_single($class,$rd) {

  my $JMP   = $class->load_JMP();
  my @chars = split $NULLSTR,$rd->{buf};

  # consume up to term
  while(@chars) {

    my $c  = shift @chars;
    my $fn = $class->read($rd,$JMP,$c);

    last if $fn eq 'term';

  };

  # re-assemble string without consumed
  $rd->{buf}=join $NULLSTR,@chars;

};

# ---   *   ---   *   ---
# ^read whole

sub proc($class,$rd) {

  my $JMP=$class->load_JMP();

  map   {$class->read($rd,$JMP,$ARG)}
  split $NULLSTR,$rd->{buf};


  return;

};

# ---   *   ---   *   ---
# standard char proc

sub default($class,$rd) {
  $rd->{token} .= $rd->{char};
  $rd->set_ntermf();

};

# ---   *   ---   *   ---
# whitespace
#
# terminates *token* if first
# blank, non-term character

sub blank($class,$rd) {
  $rd->commit() if ! $rd->blank();
  $rd->set('blank');

};

# ---   *   ---   *   ---
# begin stringmode

sub string($class,$rd,$term=undef) {

  $rd->set_ntermf();

  $term //= $rd->{char};

  $rd->commit();

  $rd->{token}=$rd->{char};
  $rd->{l1}->make_tag($rd,'STRING');

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
  $rd->new_branch();

};

sub nest_down($class,$rd) {
  $rd->{branch}=pop @{$rd->{nest}};

};

# ---   *   ---   *   ---
# delimiters

sub delim_beg($class,$rd) {

  $rd->set_termf();

  $rd->commit();

  $rd->{token}=$rd->{char};
  $rd->{l1}->make_tag($rd,'OPERA');

  $rd->commit();
  $class->nest_up($rd);

};

sub delim_end($class,$rd) {

  # no token?
  if(! $rd->commit()) {

    # clear if last expr is empty!
    $rd->{branch}->discard()

    if  $rd->{branch}
    &&! @{$rd->{branch}->{leaves}}

    ;

  };

  $class->nest_down($rd);
  $rd->set_termf();

};

# ---   *   ---   *   ---
# expression terminator

sub term($class,$rd) {

  $rd->commit();
  $rd->{l2}->proc($rd);
  $rd->new_branch();

  $rd->set_termf();

};

# ---   *   ---   *   ---
# argument separator

sub operator_single($class,$rd) {

  return $class->default($rd)
  if $rd->cmd_name_rule();

  $rd->commit();
  $rd->{token}=$rd->{char};
  $rd->{l1}->make_tag($rd,'OPERA');

  $rd->commit();
  $rd->set_ntermf();

};

# ---   *   ---   *   ---
# generate/fetch l0 jump table

sub load_JMP($class) {

  state $charset = $class->charset();
  state $JMP     = [map {

    my $key   = chr($ARG);
    my $value = (exists $charset->{$key})
      ? $charset->{$key}
      : 'default'
      ;

    $value;

  } 0..127];


  return $JMP;

};

# ---   *   ---   *   ---
1; # ret
