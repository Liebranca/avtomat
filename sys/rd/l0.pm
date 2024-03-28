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

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  TABID   => 'JMP',

  charset => {

    ';'   => 'term',
    '"'   => 'string',
    "'"   => 'string',
    '\\'  => 'escape',

    ' '   => 'blank',
    "\t"  => 'blank',
    "\r"  => 'blank',
    "\n"  => 'blank',

    '#'   => 'comment',


    (map {$ARG=>'operator_single'} qw(
      % + - * < > = !
      ? ~ & | ^ / @ `

    ),','),

    (map {$ARG=>'delim_beg'} qw~( [ {~),
    (map {$ARG=>'delim_end'} qw~) ] }~),

  },

};

# ---   *   ---   *   ---
# read input char

sub read($self,$JMP,$c) {

  # get ctx
  my $main=$self->{main};

  # consume char
  $self->csume($c);


  # reader set to stringmode?
  if($main->string()) {
    $self->strcat();
    return 'strcat';

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

  # get ctx
  my $main=$self->{main};

  # save current char
  $main->{char}=$c;

  # tick the line counter
  $main->{lineno} += int($c eq "\n");


  # track beggining of first
  # nterm char in expr
  $main->{lineat}=$main->{lineno}
  if $main->exprbeg();


  return;

};

# ---   *   ---   *   ---
# read single expression

sub parse_single($self) {


  # get ctx
  my $main  = $self->{main};
  my $JMP   = $self->load_JMP();
  my @chars = split $NULLSTR,$main->{buf};


  # consume up to term
  while(@chars) {

    my $c  = shift @chars;
    my $fn = $self->read($JMP,$c);

    last if $fn eq 'term';

  };


  # re-assemble string without consumed
  $main->{buf}=join $NULLSTR,@chars;


  return;

};

# ---   *   ---   *   ---
# ^read whole program

sub parse($self) {

  my $JMP=$self->load_JMP();

  map   {$self->read($JMP,$ARG)}
  split $NULLSTR,$self->{main}->{buf};


  return;

};

# ---   *   ---   *   ---
# cat to current token and set flags

sub default($self) {

  my $main=$self->{main};

  $main->{token} .= $main->{char};
  $main->set_ntermf();

  return;

};

# ---   *   ---   *   ---
# ^similar, but sets no flags

sub strcat($self) {

  my $main=$self->{main};
  $main->{token} .= $main->{char};

  return;

};

# ---   *   ---   *   ---
# whitespace

sub blank($self) {

  # get ctx
  my $main=$self->{main};


  # save token if last char
  # *wasn't* also blank
  $main->commit() if ! $main->blank();

  # ^remember this one was blank
  $main->set('blank');


  return;

};

# ---   *   ---   *   ---
# begin stringmode

sub string($self,$term=undef) {

  # default EOS to current char
  my $main   = $self->{main};
     $term //= $main->{char};


  # save current
  $main->commit();


  # make new, marked as string
  my $l1=$main->{l1};

  $main->{token}=$l1->make_tag(
    'STRING',$main->{char}

  );


  # ^set flags and EOS char
  $main->set('string');
  $main->set_ntermf();

  $main->{strterm}=$term;


  return;

};

# ---   *   ---   *   ---
# ^same mechanic, but terminator
# is a newline

sub comment($self) {

  # get ctx
  my $main = $self->{main};
  my $beg  = $main->exprbeg();


  # enter stringmode
  $self->string("\n");
  $self->{main}->set('comment');

  # ^mainain beggining of expression
  # ^if that stateflag is set
  if($beg) {
    $main->set('exprbeg','blank');
    $main->unset('nterm');

  };


  return;

};

# ---   *   ---   *   ---
# begin new scope

sub delim_beg($self) {

  # get ctx
  my $main=$self->{main};

  # set flags and save current
  $main->set_termf();
  $main->commit();


  # ^make new
  my $l1=$main->{l1};

  $main->{token}=$l1->make_tag(
    'OPERA',$main->{char}

  );


  # go up one nesting level
  $main->commit();
  $main->nest_up();

  return;

};

# ---   *   ---   *   ---
# ^undo

sub delim_end($self) {

  # get ctx
  my $main=$self->{main};

  # no token?
  if(! $main->commit()) {

    # clear if last expr is empty!
    my $branch=$main->{branch};

    $branch->discard()
    if $branch &&! @{$branch->{leaves}};

  };


  # go down one nesting level and set flags
  $main->nest_down();
  $main->set_termf();

  return;

};

# ---   *   ---   *   ---
# expression terminator

sub term($self) {
  $self->{main}->term();
  return;

};

# ---   *   ---   *   ---
# argument separator

sub operator_single($self) {

  my $main=$self->{main};

  # cat operator to token?
  return $self->default()
  if $main->cmd_name_rule();


  # save current
  $main->commit();


  # ^make new from operator
  my $l1=$main->{l1};
  $main->{token}=$l1->make_tag(
    'OPERA',$main->{char}

  );

  # ^save operator as single token
  $main->commit();
  $main->set_ntermf();


  return;

};

# ---   *   ---   *   ---
# marks next token

sub escape($self) {

  my $main=$self->{main};

  if(! $main->escaped) {
    $main->set('escape');

  } else {
    $main->unset('escape');
    $self->default();

  };

};

# ---   *   ---   *   ---
# generate/fetch l0 jump table

sub load_JMP($self,$update=0) {


  # skip update?
  my $tab=$self->classattr($self->TABID);

  return $tab
  if int @$tab &&! $update;


  # ^nope, regen!
  my $charset=$self->charset;

  @$tab=map {

    my $key   = chr($ARG);
    my $value = (exists $charset->{$key})
      ? $charset->{$key}
      : 'default'
      ;

    $value;

  } 0..127;


  return $tab;

};

# ---   *   ---   *   ---
1; # ret
