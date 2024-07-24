#!/usr/bin/perl
# ---   *   ---   *   ---
# ASM
# Pseudo assembler
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmdlib::asm;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;

  use rd::vref;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.4;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# custom import method to
# make wrappers

sub build($class,$main) {

  # get ctx
  my $mc     = $main->{mc};
  my $guts_t = $mc->{ISA}->guts_t;

  # make wrappers for whole instruction set
  wm_cmdsub $main,'asm-ins' => q(
    qlist args;

  ) => @{$guts_t->list};

  # give table
  return rd::cmd::MAKE::build($class,$main);

};

# ---   *   ---   *   ---
# offset within current segment

sub current_byte($self,$branch) {

  $branch->{vref}=rd::vref->new(
    type => 'SYM',
    spec => '$',
    data => $branch,

  );

  return;

};

# ---   *   ---   *   ---
# template: read instruction

sub parse_ins($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};
  my $ISA  = $mc->{ISA};


  # expand argument list
  my @args = map {

    if($l1->typechk(LIST=>$ARG->{value})) {
      @{$ARG->{leaves}};

    } else {
      $ARG;

    };

  } @{$branch->{leaves}};


  # ^get type of each argument
  @args=map {

    $ARG=$ARG->discard();

    my $key  = $ARG->{value};
    my $have = $l1->xlate($key);
    my $type = $have->{type};
    my $spec = $have->{spec};


    # memory operand?
    if($type eq 'SCP' && $spec eq '[') {
      $type='MEM';


    # operand size specifier?
    } elsif($type eq 'TYPE') {

      $branch->{vref} //= rd::vref->new_list();
      $branch->{vref}->add($have);

      $type=null;

    };


    # give descriptor
    (length $type)
      ? rd::vref->new(data=>$ARG,type=>$type)
      : ()
      ;


  } @args;


  # have opera type spec?
  my $opsz_def = defined $branch->{vref};
  my @vtypes   = grep {$ARG} rd::vref->is_valid(
    TYPE=>$branch->{vref}

  );


  my $opsz=($opsz_def && @vtypes)
    ? typefet @vtypes
    : $ISA->def_t
    ;


  # get instruction name
  my $name=$branch->{cmdkey};


  # give descriptor
  return {

    name     => $name,

    opsz     => $opsz,
    opsz_def => ! $opsz_def,

    args     => \@args,

  };

};

# ---   *   ---   *   ---
# mutate into generic command ;>

sub mutate_ins($self,$branch,$head) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};


  # record name of original
  # just for dbout!
  my $full=(! $head->{opsz_def})
    ? "$head->{name} $head->{opsz}->{name}"
    : "$head->{name}"
    ;

  # ^mutate, clear and give
  $branch->{value}=
    $l1->tag(CMD=>'asm-ins')
  . $full
  ;

  $branch->clear();
  $branch->{vref}->{res}=$head;

  return;

};

# ---   *   ---   *   ---
# generic instruction

sub asm_ins($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $ISA  = $main->{mc}->{ISA};


  # get operands
  my $head=$self->parse_ins($branch);

  # mutate and give
  $self->mutate_ins($branch,$head);

  return;

};

# ---   *   ---   *   ---
# generates a 'pass' meta-instruction
#
# this is used to automate loading
# of registers for an F call

sub mkpass($self,$par,$idex,@args) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};


  # make node
  my ($pass)=$par->insert(
    $idex,$l1->tag(CMD=>'pass'),

  );

  $pass->{cmdkey}='pass';
  $pass->{lineno}=$par->{lineno};


  # process and give
  $pass->pushlv(@args);
  $self->asm_ins($pass);


  return $pass;

};

# ---   *   ---   *   ---
# ^pass+call

sub autocall($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $par  = $branch->{parent};

  # unpack
  my ($fn,@args)=@{$branch->{leaves}};


  # need to automate passing of arguments?
  if(@args) {

    my $pass=$self->mkpass(
      $par,$branch->{idex},@args

    );

    $pass->{lineno}=$branch->{lineno};

  };

  # mutate this branch into a call instruction
  $branch->{value}  = $l1->tag(CMD=>'call');
  $branch->{cmdkey} = 'call';

  $self->asm_ins($branch);


  return;

};

# ---   *   ---   *   ---
# ^pass+call+(ctc ld)
#
# this links the invocation of an F
# to a value within current proc

sub bindcall($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # unpack
  my ($dst,$fn,@args)=
    @{$branch->{leaves}};


  # need to automate passing of arguments?
  $self->mkpass($branch,$fn->{idex},@args)
  if @args;


  # get F being called
  my $fnref = $fn->{vref}->{res};

  my $src   = $fnref->{args}->[0];
     $src   = $src->{data}->dupa(undef,'vref');


  # ^make instruction to put ret F in dst
  my ($ld)=$branch->inew(
    $l1->tag(CMD=>'ld'),

  );

  $ld->{cmdkey}='ld';
  $ld->{lineno}=$branch->{lineno};


  # put operands
  $ld->pushlv($dst);
  $ld->pushlv($src);

  # enqueue ctc to retrieve output
  $ld->{vref}->{ctc}=\&bindret;
  $self->asm_ins($ld);


  # cleanup and give
  $branch->flatten_branch();
  return;

};

# ---   *   ---   *   ---
# ~

sub bindret($self,$branch,$opsz,$ins,@args) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};

  # validate
  my ($dst,$src)=@args;

  $main->perr(
    'cannot bind output of an indirect call'

  ) if ! exists $src->{id};


  # can fetch F to call?
  my ($name,@path)=@{$src->{id}};
  my $ptr=$mc->search($name,@path);

  return $branch if ! $ptr;


  # can find output?
  my $proc=$ptr->{p3ptr}->{vref};
  my $have=$proc->{data}->{io}->{out};

  $main->perr(

    'binding error; '

  . "cannot find [good]:%s var '%s'\n"
  . "for [ctl]:%s '%s'",

    args => [
      out  => $name,
      proc => $proc->{data}->{name},

    ],

  ) if ! @{$have->{var}->{-order}};


  # replace source with register!
  my $key = $have->{var}->{-order}->[0];
  my $r   = $have->{var}->{$key};

  %$src=(
    type => 'r',
    reg  => $r->{decl},

  );

  $opsz=$r->{opsz} if length $r->{opsz};


  return ($src->{reg} eq $dst->{reg})
    ? null
    : $opsz
    ;

};

# ---   *   ---   *   ---
# add entry points

cmdsub 'asm-ins'  => q(qlist src) => \&asm_ins;
cmdsub '$' => q() => \&current_byte;


cmdsub 'autocall' => q(
  any   fn;
  qlist args=();

) => \&autocall;

cmdsub 'bindcall' => q(

  any   dst;
  any   fn;

  qlist args=();

) => \&bindcall;

# ---   *   ---   *   ---
# generic methods, see ipret
# for details

w_cmdsub 'csume-token' => q(
  sym any;

) => qw(
  blk entry proc

);

w_cmdsub 'csume-list-mut' => q(
  cmd input;
  any value=0;

) => qw(io in out);

# ---   *   ---   *   ---
1; # ret
