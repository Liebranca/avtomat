#!/usr/bin/perl
# ---   *   ---   *   ---
# SYMBOL
# Execution as data
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Peso::Sbl;

  use v5.36.0;

  use strict;
  use warnings;

  use Scalar::Util qw/blessed/;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;

# ---   *   ---   *   ---
# info

  our $VERSION=v1.08.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# getters

sub name($self) {return $self->{name}};
sub args($self) {return $self->{args}};
sub argc($self) {return $self->{argc}};

sub code($self) {return $self->{code}};

sub num_fields($self) {return $self->{num_fields}};
sub frame($self) {return $self->{frame}};

# ---   *   ---   *   ---

sub valid($sym) {
  return blessed($sym) && $sym->isa('Peso::Sbl');

};

# ---   *   ---   *   ---
# constructors

sub new_frame {return Peso::Sbl::Frame::create()};

# ---   *   ---   *   ---

sub nit($frame,$name,$argv,$code,$plps) {

  my $sym;
  if($plps) {goto USE_PLPS;};

# ---   *   ---   *   ---
# handle unspecified args

  my $argc=0;
  my $num_fields=0;

  my @args=();if(!$argv) {
    goto SKIP;

  };

# ---   *   ---   *   ---
# decode argv parameter
# format is [*==opt]N==COUNT<TYPES,TYPES>
# multiple groups separated by : semicolons

  @args=split m/[:]/,$argv;
  for my $arg(@args) {

    # startswith '*': optional field
    # negative count: varargs
    my $opt=int($arg=~ s/^[*]//);
    my $varargs=int($arg=~ s/^-//);

    # only allow optional/varargs on
    # last field
    if(

       ($opt)
    && $arg ne $args[-1]

    ) {

      Arstd::errout(

        'Can\'t make symbol \'%s\': '.

        'optional arguments only allowed on '.
        "last field\n",

        args=>[$name],
        lvl=>$AR_FATAL,

      )

    };

# ---   *   ---   *   ---

    # *minimum* number of values in field
    $arg=~ s/([0-9]+)//;

    my $count=0;
    if(defined $1) {
      $count=$1;

    };

    $argc+=$count*!$opt;
    $num_fields+=1*!$opt;

# ---   *   ---   *   ---
# get value types

    my @types=();
    if($count) {

      # get <type0,...typeN>
      $arg=~ s/<(.*)>//;

      my $types=undef;
      if(defined $1) {
        $types=$1;

      # skip if no types specified
      } else {
        goto SKIP;

      };

      # repeat last type if len<count
      @types=split m/[,]/,$types;
      while(@types<$count) {
        push @types,$types[-1];

      };SKIP:

# ---   *   ---   *   ---
# make array value into a dict
# when symbol is invoked this is used
# to error-check the call

    };$arg={

      opt=>$opt,

      count=>$count,
      types=>[@types],

      varargs=>$varargs,

    };
  };

# ---   *   ---   *   ---
# make instance

  SKIP:$sym=bless {

    name=>$name,
    args=>[@args],
    argc=>$argc,

    code=>$code,

    num_fields=>$num_fields,
    frame=>$frame,

  },$class;

  return $sym;

# ---   *   ---   *   ---
# for languages that use *.lps files
# rather than the old system

USE_PLPS:$sym=bless {

    name=>$name,
    args=>$argv,
    argc=>0,

    code=>$code,

    num_fields=>0,
    frame=>$frame,

  },$class;

  return $sym;


# ---   *   ---   *   ---
# ^ creates a duplicate of a symbol
# under a different name

};sub dup($class,$src,$name) {

  my $sym=bless {

    name=>$name,
    args=>$src->args,
    argc=>$src->argc,

    code=>$src->code,

    num_fields=>$src->num_fields,
    frame=>$src->frame,

  },$class;

  return $sym;

};

# ---   *   ---   *   ---
# check that elements in field correspond
# to valid argument types for symbol

sub arg_typechk($self,$node,$proto) {

  my $frame=$self->frame;
  my $out=0;

# ---   *   ---   *   ---

  my $master=$frame->master;
  my $fr_ptr=$master->ptr;
  my $fr_blk=$master->blk;

  my $lang=$master->lang;

  my $names=$lang->names;
  my $ops=$lang->ops;

# ---   *   ---   *   ---

  my $tag=$node->{value};
  my $valid=0;

# ---   *   ---   *   ---

  my $calltab={

    'ptr'=>sub {
      return peso::ptr::valid($tag);

    },

    'bare'=>sub {

      return

         int($tag=~ m/${names}/)
      || int($tag=~ m/-?[0-9]+/)

      ;

    },

    'path'=>sub {

      $valid=(

        $lang->op_prec
        ->{$node->{value}->{op}}
        ->[$node->{value}->{idex}]->[0]

      )==-1;

      if($valid) {$node->collapse();};
      return $valid;

    },

    'type'=>sub {
      my $pat=$lang->types->{re};
      return int($tag=~ m/^${pat}/);

    },

    'op'=>sub {
      $valid=int($tag=~ m/^node_op=HASH/);
      if($valid) {$node->collapse();};

      return $valid;

    },

  };

# ---   *   ---   *   ---

  for my $v(split m/[|]/,$proto) {

    # catch bad type
    if(!exists $calltab->{$v}) {

      arstd::errout(

        'Unrecognized type \'%s\'',

        args=>[$v],
        lvl=>$FATAL,

      );

    };

# ---   *   ---   *   ---
# get value isa type

    $valid=$calltab->{$v}->();

    if($valid) {
      $out=1;
      last;

    };

  };$out=$valid;

# ---   *   ---   *   ---
# catch invalid argument

  if(!$master->fpass()) {

    arstd::errout(

      "Invalid argument type for symbol '%s'\n".
      "Valid types are: %s\n",

      args=>
        [$self->name,join ', ',(split m/[|]/,$proto)],

      lvl=>$FATAL,

    );
  };

  return $out;

};

# ---   *   ---   *   ---
# check passed arguments and execute

sub ex($self,$node) {

  # check *enough* fields passed
  if(@{$node->{leaves}}<$self->num_fields) {

    arstd::errout(

      'Bad number of fields for '.
      "symbol <%s>\n",

      args=>[$self->name],
      lvl=>$FATAL,

    );

  };

# ---   *   ---   *   ---
# iter symbol arguments

  my $j=0;
  my @args=();

  for my $arg(@{$self->args}) {
    my $count=$arg->{count};

# ---   *   ---   *   ---
# get next field

    my $field=$node->fieldn($j++);
    if(!$field && $arg->{opt}) {
      last;

    };

# ---   *   ---   *   ---
# check field has *enough* elements

    if(

        @{$field->{leaves}}<$count
     && !$arg->{opt}

    ) {

      arstd::errout(

        'Bad number of arguments '.
        'on field %i for '.
        "symbol <%s>\n",

        args=>[$j,$self->name],
        lvl=>$FATAL,

      );

    };

# ---   *   ---   *   ---
# only the loop changes between paths
# so just shove the proc into a code ref

    my $i=0;my @field_args=();
    my $consume_arg=sub {

      my $leaf=$field->{leaves}->[$i];
      my $type=$arg->{types}->[$i];

      # use last defined type (for varargs)
      if(!$type) {
        $type=$arg->{types}->[-1];

      # check type is OK
      };if(!$self->arg_typechk($leaf,$type)) {
        return 0;

      };push @field_args,$leaf->{value};$i++;
      return 1;

    };

# ---   *   ---   *   ---
# consume only up to count elements

    if(!$arg->{varargs}) {

      for my $x(0..$count-1) {
        if(!$consume_arg->()) {return;};

      };

# ---   *   ---   *   ---
# varargs consume all elements left

    } else {

      while($i<@{$field->{leaves}}) {
        if(!$consume_arg->()) {return;};

      };
    };

# ---   *   ---   *   ---
# pass arguments for each field as
# a list of array references

    push @args,\@field_args;
  };

# ---   *   ---   *   ---

  return $self->code->(

    $self->name,
    $self->frame,

    @args

  );
};

# ---   *   ---   *   ---

package peso::sbl::frame;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use arstd;
  use style;

# ---   *   ---   *   ---
# shorthand for orderly symbol nit

sub DEFINE($frame,$key,$src,$code,$plps) {

  my $idex=$src->{$key}->[0];
  my $args=$src->{$key}->[1];

  my $sym=$frame->nit($key,$args,$code,$plps);

  $frame->{ins}->[$idex]
    =$frame->{syms}->{$key}=$sym;

  $frame->{insid}->{$key}=$idex;

  return;

# ---   *   ---   *   ---
# shorthand for creating symbol aliases

};sub ALIAS($frame,$key,$src) {

  my $sym=$frame->{syms}->{$src}->dup($key);
  my $idex=$frame->{insid}->{$src};

  $frame->{ins}->[$idex]
    =$frame->{syms}->{$key}=$sym;

  $frame->{insid}->{$key}=$idex;

  return;

};

# ---   *   ---   *   ---

sub nit($class,@args) {
  return peso::sbl::nit(@args);

# ---   *   ---   *   ---

};sub create {

  my $frame=bless {

    syms=>{},
    ins=>[],
    insid=>{},

    master=>undef,

  },'peso::sbl::frame';

  return $frame;

# ---   *   ---   *   ---

};sub setdef($self,$def) {
  $self->{master}=$def;
  return;

};

# ---   *   ---   *   ---
# go through a list of nodes and consume them
# as if they were a [command,args] array

sub ndconsume($frame,$node,$i) {

  my $master=$frame->master;
  my $fr_def=$master->defs;

  my $keywords=$fr_def->SYMS();
  my $leaf=$node->{leaves}->[$$i++];

  my $key=$leaf->{value};

  # check that we're not in void context
  if(!$leaf || !exists $keywords->{$key}) {
    goto FAIL;

  };

# ---   *   ---   *   ---
# consume nodes according to context

  my $anchor=$leaf;
  $anchor->{value}=$keywords->{$key};

  my $ref=$anchor->{value}->args;
  my @args=@{$ref};

  for my $arg(@args) {

    my $field=$node->{leaves}->[$$i];

    my $argc=$arg->{count};
    my $j=0;while($argc>0) {

      $leaf=$field->{leaves}->[$j++];
      my $value=($leaf) ? $leaf->{value} : 0;

      $argc--;

# ---   *   ---   *   ---
# handle bad number/order of command args

      if(!$leaf && !$arg->{opt}) {

        arstd::errout(

          'Insufficient args for '.
          "symbol '%s'\n",

          args=>[$anchor->{value}->name],
          lvl=>$FATAL,

        );

      };
    };

# ---   *   ---   *   ---
# relocate accumulated nodes && clear

    $node->pluck($field);
    $anchor->pushlv($field);

  };

# ---   *   ---   *   ---

FAIL:
  return;

};

# ---   *   ---   *   ---
1; # ret
