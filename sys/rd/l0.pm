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
# lib,

# ---   *   ---   *   ---
# deps

package rd::l0;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.9a';
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # cstruc values
  DEFAULT => sub {

    my $flags=$_[0]->flags;

    return {

      main    => undef,

      status  => 0x00,
      strterm => undef,

      prev    => null,
      stack   => [],

    };

  },

  # used to find table in cache
  TABID   => 'JMP',


  # possible states
  flags => {

    ws     => 0x01,

    str    => 0x02,
    com    => 0x04,

    nterm  => 0x08,

    exp    => 0x10,
    esc    => 0x20,

  },


  # possible inputs
  charset => {

    ';'   => 'term',
    '"'   => 'str',
    "'"   => 'str',
    '\\'  => 'esc',

    ' '   => 'ws',
    "\t"  => 'ws',
    "\r"  => 'ws',
    "\n"  => 'ws',

    '#'   => 'com',


    (map {$ARG=>'opr'} qw(
      % + - * < > = !
      ? ~ & | ^ / @ `

    ),','),

    (map {$ARG=>'enter'} qw~( [ {~),
    (map {$ARG=>'leave'} qw~) ] }~),


    "\x{7F}" => 'com',

  },


  # get special char array!
  spchars => sub {

    my $charset=$_[0]->charset;

    return [grep {
      $charset->{$ARG} eq 'opr'

    } keys %$charset];

  },

};

# ---   *   ---   *   ---
# read input char

sub read($self,$JMP,$c) {


  # get ctx
  my $main=$self->{main};

  # consume char
  $self->csume($c);


  # reader set to string mode?
  if($self->strmode()) {
    $self->strcat();
    return 'strcat';

  # ^nope, process normally
  } else {

    # sneaky hack for C comments ;>
    if($main->{C}
    && $c eq '/' && $self->{prev} eq '/') {
      $c=$self->{char}="\x{7F}";

      my $b=$main->{l2}->{branch};
      $b->pluck($b->{leaves}->[-1]);

    };

    # get proc for this char
    my $fn=$JMP->[ord($c)];

    # ^invoke and go next
    $self->$fn();
    $self->{prev}=$c;


    return $fn;

  };

};

# ---   *   ---   *   ---
# consume character

sub csume($self,$c) {

  # get ctx
  my $main=$self->{main};

  # save current char
  $self->{char}=$c;

  # tick the line counter
  $main->{lineno} += int($c eq "\n");


  # track beggining of first
  # nterm char in expr
  my ($exp)=$self->flagchk(exp=>1);
  $main->next_line() if ! $exp;

  return;

};

# ---   *   ---   *   ---
# read single expression

sub parse_single($self) {


  # get ctx
  my $main  = $self->{main};
  my $JMP   = $self->load_JMP();
  my @chars = split null,$main->{buf};


  # consume up to term
  while(@chars) {

    my $c  = shift @chars;
    my $fn = $self->read($JMP,$c);

    last if $fn eq 'term';

  };


  # re-assemble string without consumed
  $main->{buf}=catar @chars;


  return;

};

# ---   *   ---   *   ---
# ^read whole program

sub parse($self) {

  my $JMP=$self->load_JMP();

  map   {$self->read($JMP,$ARG)}
  split null,$self->{main}->{buf};

  return;

};

# ---   *   ---   *   ---
# cat to current token and set flags

sub cat($self) {

  my $main = $self->{main};
  my $l1   = $main->{l1};

  $l1->{token} .= $self->{char};
  $self->set_ntermf();

  return;

};

# ---   *   ---   *   ---
# ^similar, but sets no flags

sub strcat($self) {

  my $main = $self->{main};
  my $l1   = $main->{l1};

  $l1->{token} .= $self->{char};

  return;

};

# ---   *   ---   *   ---
# whitespace

sub ws($self) {

  # save token if last char
  # *wasn't* also whitespace
  my ($ws)=$self->flagchk(ws=>1);
  $self->commit() if ! $ws;

  # ^remember current *is* whitespace
  $self->flagset(ws=>1);

  return;

};

# ---   *   ---   *   ---
# begin stringmode

sub str($self,$term=undef) {


  # string character escaped?
  my ($esc)=$self->flagchk(esc=>1);
  if($esc) {
    $self->flagset(esc=>0);
    return $self->cat();

  };


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # default EOS to current char
  $term //= $self->{char};


  # push leftovers
  $self->commit();

  # make a typed token
  $l1->{token}=$l1->tag(
    STR => $self->{char}

  );


  # ^set flags and EOS char
  $self->flagset(str=>1);
  $self->set_ntermf();

  $self->{strterm}=$term;

  return;

};

# ---   *   ---   *   ---
# ^same mechanic, but terminator
# is a newline

sub cpreproc($self) {$self->com()};
sub com($self) {


  # are we inside an expression?
  my ($exp) = $self->flagchk(exp=>1);


  # enter string mode and set flags
  $self->str("\n");
  $self->flagset(com=>1);

  # if not at expression, keep it that way!
  $self->flagset(

    exp   => 0,

    ws    => 1,
    nterm => 0,

  ) if ! $exp;

  return;

};

# ---   *   ---   *   ---
# begin new scope

sub enter($self) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};

  # set flags and save current
  $self->set_termf();
  $self->commit();


  # ^make new
  $l1->{token}=$l1->tag(
    SCP=>$self->{char}

  );


  # open scope!
  $self->commit();
  $l2->enter($l2->{branch}->{leaves}->[-1]);

  return;

};

# ---   *   ---   *   ---
# ^undo

sub leave($self) {

  # get ctx
  my $main = $self->{main};
  my $l2   = $main->{l2};

  # no token?
  if(! $self->commit()) {

    # clear if last expr is empty!
    my $branch=$l2->{branch};

    $branch->discard()
    if $branch &&! @{$branch->{leaves}};

  };


  # close scope!
  $l2->leave();
  $self->set_termf();

  return;

};

# ---   *   ---   *   ---
# expression terminator

sub term($self) {

  # get ctx
  my $main = $self->{main};
  my $l2   = $main->{l2};

  # start new expression!
  $self->commit();
  $l2->term();

  $self->set_termf();

  return;

};

# ---   *   ---   *   ---
# argument separator

sub opr($self) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # save current
  $self->commit();


  # ^make new from operator
  $l1->{token}=$l1->tag(
    OPR=>$self->{char}

  );

  # ^save operator as single token
  $self->commit();
  $self->set_ntermf();


  return;

};

# ---   *   ---   *   ---
# marks next token

sub esc($self,%O) {

  $O{nocat} //= 0;

  my ($esc)=$self->flagchk(esc=>1);

  if(! $esc) {
    $self->flagset(esc=>1);

  } else {
    $self->flagset(esc=>0);
    $self->cat() if ! $O{nocat};

  };

  return;

};

# ---   *   ---   *   ---
# push token to tree

sub commit($self) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};


  # have token?
  my $have=0;
  if(length $l1->{token}) {


    # add type data if needed
    $l1->{token}=$l1->detect(
      $l1->{token}

    );


    # add new node
    my ($exp) = $self->flagchk(exp=>1);
    my $nd    = $l2->cat($l1->{token});

    $self->flagset(exp=>1);


    # set misc attrs
    $main->next_line();
    $have |= 1;

  };

  # give true if token added
  $l1->{token}=null;
  $self->flagset(esc=>0);

  return $have;

};

# ---   *   ---   *   ---
# throw away the token
#
# we don't really use this from
# charset, so it's redundant!
#
# BUT: it's in the docs, so I've
# implemented it ;>

sub discard($self) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  $l1->{token}=null;

  return;

};

# ---   *   ---   *   ---
# set/unset status flags

sub flagset($self,%bits) {


  # get ctx
  my $dst = \$self->{status};
  my $tab = $self->flags;


  # walk input
  map  {


    # set bit?
    if($bits{$ARG}) {
      $$dst |= $tab->{$ARG};

    # unset!
    } else {
      $$dst &=~ $tab->{$ARG};

    };

  } keys %bits;

  return;

};

# ---   *   ---   *   ---
# ^set terminator flags

sub set_termf($self) {

  $self->flagset(
    ws    => 1,
    nterm => 0,
    exp   => 0,

  );

};

# ---   *   ---   *   ---
# ^set *non* terminator flags

sub set_ntermf($self) {

  $self->flagset(

    ws      => 0,
    exp     => 1,

    nterm   => 1,

  );

};

# ---   *   ---   *   ---
# get flag is set or unset

sub flagchk($self,%bits) {


  # get ctx
  my $src = $self->{status};
  my $tab = $self->flags;

  # give bool array
  map {

    my $have=$src & $tab->{$ARG};

    if($bits{$ARG}) {
      $have == $tab->{$ARG};

    } else {
      $have == 0;

    };

  } keys %bits;

};

# ---   *   ---   *   ---
# save current status

sub store($self) {

  my $stack=$self->{stack};
  push @$stack,$self->{status};

  return;

};

# ---   *   ---   *   ---
# ^restore

sub load($self) {

  my $stack=$self->{stack};
  $self->{status}=pop @$stack;

  return;

};

# ---   *   ---   *   ---
# gives true if we are currently
# inside a string
#
# additionally, handle exit from
# string if we step on the terminator

sub strmode($self) {


  # get ctx
  my $main = $self->{main};
  my $l2   = $main->{l2};


  # have we stepped on an escape?
  my $type = $self->charset->{$self->{char}};
  my $esct = defined $type && $type eq 'esc';

  $self->esc(nocat=>1) if $esct;

  # ^get flag
  my ($esc)=$self->flagchk(esc=>1);


  # are we inside a string?
  my ($out)=$self->flagchk(
    str=>1

  );

  # have we stepped on the string terminator?
  my $end=$out && (
     $self->{char}
  eq $self->{strterm}

  );


  # ^terminate string if both are true!
  # ^(and term is not escaped ;>)
  if($end &&! $esc) {

    $self->{char}=null;
    $self->flagset(str=>0);

    $self->commit();


    # are we inside a comment?
    my ($com)=$self->flagchk(
      com=>1

    );

    # ^yep, terminate!
    if($com) {
      $self->flagset(com=>0);
      $l2->term();

    };

  } elsif($esc &&! $esct) {
    $self->flagset(esc=>0);

  };


  return $out;

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
      : 'cat'
      ;

    $value;

  } 0..127;


  return $tab;

};

# ---   *   ---   *   ---
1; # ret
