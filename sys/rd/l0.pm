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
# cstruc

sub new($class,$rd) {
  return bless {rd=>$rd},$class;

};

# ---   *   ---   *   ---
# what to do with chars

sub charset($self) { return {

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

sub read($self,$JMP,$c) {


  # consume char
  my $rd=$self->{rd};
  $self->csume($c);


  # reader set to stringmode?
  if($rd->string()) {
    $self->default();
    return 'default';

  # ^nope, process normally
  } else {

    # get proc for this char
    my $fn=$JMP->[ord($c)];

    # ^invoke and go next
    $self->$fn();


    return $fn;

  };

};

# ---   *   ---   *   ---
# consume character

sub csume($self,$c) {

  my $rd=$self->{rd};

  # save current char
  $rd->{char}=$c;

  # tick the line counter
  $rd->{lineno} += int($c eq "\n");


  # track beggining of first
  # nterm char in expr
  $rd->{lineat}=$rd->{lineno}
  if $rd->exprbeg();


  return;

};

# ---   *   ---   *   ---
# read single expression

sub proc_single($self) {

  my $rd    = $self->{rd};
  my $JMP   = $self->load_JMP();
  my @chars = split $NULLSTR,$rd->{buf};

  # consume up to term
  while(@chars) {

    my $c  = shift @chars;
    my $fn = $self->read($JMP,$c);

    last if $fn eq 'term';

  };

  # re-assemble string without consumed
  $rd->{buf}=join $NULLSTR,@chars;

};

# ---   *   ---   *   ---
# ^read whole

sub proc($self) {

  my $JMP=$self->load_JMP();

  map   {$self->read($JMP,$ARG)}
  split $NULLSTR,$self->{rd}->{buf};


  return;

};

# ---   *   ---   *   ---
# cat to current token and set flags

sub default($self) {

  my $rd=$self->{rd};

  $rd->{token} .= $rd->{char};
  $rd->set_ntermf();

};

# ---   *   ---   *   ---
# whitespace

sub blank($self) {

  my $rd=$self->{rd};

  # save token if last char
  # *wasn't* also blank
  $rd->commit() if ! $rd->blank();

  # ^remember this one was blank
  $rd->set('blank');

};

# ---   *   ---   *   ---
# begin stringmode

sub string($self,$term=undef) {

  # default EOS to current char
  my $rd     = $self->{rd};
     $term //= $rd->{char};


  # save current
  $rd->commit();


  # make new, marked as string
  my $l1=$rd->{l1};

  $rd->{token}=$l1->make_tag(
    'STRING',$rd->{char}

  );


  # ^set flags and EOS char
  $rd->set('string');
  $rd->set_ntermf();

  $rd->{strterm}=$term;

};

# ---   *   ---   *   ---
# ^same mechanic, but terminator
# is a newline

sub comment($self) {
  $self->string("\n");
  $self->{rd}->set('comment');

};

# ---   *   ---   *   ---
# begin new scope

sub delim_beg($self) {

  my $rd=$self->{rd};

  # set flags and save current
  $rd->set_termf();
  $rd->commit();


  # ^make new
  my $l1=$rd->{l1};

  $rd->{token}=$l1->make_tag(
    'OPERA',$rd->{char}

  );

  # go up one nesting level
  $rd->commit();
  $rd->nest_up();

};

# ---   *   ---   *   ---
# ^undo

sub delim_end($self) {

  my $rd=$self->{rd};

  # no token?
  if(! $rd->commit()) {

    # clear if last expr is empty!
    my $branch=$rd->{branch};

    $branch->discard()
    if $branch &&! @{$branch->{leaves}};

  };


  # go down one nesting level and set flags
  $rd->nest_down();
  $rd->set_termf();

};

# ---   *   ---   *   ---
# expression terminator

sub term($self) {
  $self->{rd}->term();

};

# ---   *   ---   *   ---
# argument separator

sub operator_single($self) {

  my $rd=$self->{rd};

  # cat operator to token?
  return $self->default()
  if $rd->cmd_name_rule();


  # save current
  $rd->commit();


  # ^make new from operator
  my $l1=$rd->{l1};
  $rd->{token}=$l1->make_tag(
    'OPERA',$rd->{char}

  );

  # ^save operator as single token
  $rd->commit();
  $rd->set_ntermf();

};

# ---   *   ---   *   ---
# generate/fetch l0 jump table

sub load_JMP($self) {

  state $charset = $self->charset();
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
