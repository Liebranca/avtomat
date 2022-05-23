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
package peso::sbl;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use peso::decls;
  use peso::defs;
  use peso::ptr;
  use peso::blk;

  use Scalar::Util qw/blessed/;

# ---   *   ---   *   ---
# global state

my %CACHE=(

  -INS=>{},

);

# ---   *   ---   *   ---
# getters

sub INS {return $CACHE{-INS};};

sub name {return (shift)->{-NAME};};
sub args {return (shift)->{-ARGS};};
sub argc {return (shift)->{-ARGC};};

sub code {return (shift)->{-CODE};};

sub num_fields {return (shift)->{-NUM_FIELDS};};

# ---   *   ---   *   ---

sub valid {

  my $sym=shift;

  if(blessed($sym) && $sym->isa('peso::sbl')) {
    return 1;

  };return 0;

};

# ---   *   ---   *   ---
# constructor

sub nit {

  my $name=shift;
  my $argv=shift;
  my $code=shift;

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

  @args=split ':',$argv;
  for my $arg(@args) {

    # startswith '*': optional field
    # negative count: varargs
    my $opt=int($arg=~ s/^\*//);
    my $varargs=int($arg=~ s/^-//);

    # only allow optional/varargs on
    # last field
    if(

       ($opt)
    && $arg ne $args[-1]

    ) {

      printf

        "Can't make symbol '$name': ".

        "optional arguments only allowed on ".
        "last field\n";

      exit;

    };

# ---   *   ---   *   ---

    # *minimum* number of values in field
    $arg=~ s/([0-9]+)//;
    my $count=$1;

    $argc+=$count*!$opt;
    $num_fields+=1*!$opt;

# ---   *   ---   *   ---
# get value types

    my @types=();
    if($count) {

      # get <type0,...typeN>
      $arg=~ s/<(.*)>//;
      my $types=$1;

      # skip if no types specified
      if(!$types) {goto SKIP;};

      # repeat last type if len<count
      @types=split ',',$types;
      while(@types<$count) {
        push @types,$types[-1];

      };SKIP:

# ---   *   ---   *   ---
# make array value into a dict
# when symbol is invoked this is used
# to error-check the call

    };$arg={

      -OPT=>$opt,

      -COUNT=>$count,
      -TYPES=>[@types],

      -VARARGS=>$varargs,

    };
  };

# ---   *   ---   *   ---
# make instance

  SKIP:my $sym=bless {

    -NAME=>$name,
    -ARGS=>[@args],
    -ARGC=>$argc,

    -CODE=>$code,

    -NUM_FIELDS=>$num_fields,

  },'peso::sbl';

  return $sym;

# ---   *   ---   *   ---
# ^ creates a duplicate of a symbol
# under a different name

};sub dup {

  my $src=shift;
  my $name=shift;

  my $sym=bless {

    -NAME=>$name,
    -ARGS=>$src->args,
    -ARGC=>$src->argc,

    -CODE=>$src->code,

    -NUM_FIELDS=>$src->num_fields,

  },'peso::sbl';

  return $sym;

};

# ---   *   ---   *   ---
# go through a list of nodes and consume them
# as if they were a [command,args] array

sub ndconsume {

  my $node=shift;
  my $i=shift;

$node->prich();

  my $keywords=peso::defs::SYMS();
  my $leaf=$node->leaves->[$$i++];

  my $key=$leaf->value;

  # check that we're not in void context
  if(!$leaf || !exists $keywords->{$key}) {
    return;

  };

# ---   *   ---   *   ---
# consume nodes according to context

  my $anchor=$leaf;
  $anchor->value($keywords->{$key});

  my $ref=$anchor->value->args;
  my @args=@{$ref};

  for my $arg(@args) {

    my $field=$node->leaves->[$$i];

    my $argc=$arg->{-COUNT};
    my $j=0;while($argc>0) {

      $leaf=$field->leaves->[$j++];
      my $value=($leaf) ? $leaf->value : 0;

      $argc--;

# ---   *   ---   *   ---
# handle bad number/order of command args

      if(!$leaf && !$arg->{-OPT}) {
        printf "Insufficient args for ".
          "symbol '%s'\n",$anchor->value->name;

        exit;

      };
    };

# ---   *   ---   *   ---
# relocate accumulated nodes && clear

    $node->pluck($field);
    $anchor->pushlv(0,$field);

  };
};

# ---   *   ---   *   ---
# check that elements in field correspond
# to valid argument types for symbol

sub arg_typechk {

  my $self=shift;
  my $node=shift;
  my $types=shift;

  my $pesonames=peso::decls::names;
  my $ops=peso::decls::ops;

# ---   *   ---   *   ---

  if(

      !($node->value=~ m/@/)
  &&  $node->value=~ m/${ops}/

  ) {

    peso::blk::treesolve($node);

    $node=$node->value;

    if(peso::ptr::valid_addr($node)) {
      $node=peso::ptr::fetch($node);

    };

# ---   *   ---   *   ---

  } else {
    $node=$node->value;

  };

# ---   *   ---   *   ---

  my $valid=0;
  for my $type(split '\|',$types) {

    if($type eq 'ptr') {
      $valid=peso::ptr::valid($node);

    # either a string, number or dereference
    } elsif($type eq 'bare') {
      $valid
        =  int($node=~ m/${pesonames}*/)
        || int($node=~ m/-?[0-9]+/);

    };

    if($valid) {
      return 1;

    };

  };

# ---   *   ---   *   ---
# errme

  if(peso::blk::fpass) {return 0;};

  printf sprintf

    "Invalid argument type for symbol '%s'\n".
    "Valid types are: %s\n",

    $self->name,
    (join ' or ',(split '\|',$types));

  exit;

};

# ---   *   ---   *   ---
# check passed arguments and execute

sub ex {

  my $self=shift;
  my $node=shift;

  # check *enough* fields passed
  if(@{$node->leaves}<$self->num_fields) {

    printf

      "Bad number of fields for ".
      "symbol <".$self->name.">\n";

    exit;

  };

# ---   *   ---   *   ---
# iter symbol arguments

  my $j=0;
  my @args=();

  for my $arg(@{$self->args}) {
    my $count=$arg->{-COUNT};

# ---   *   ---   *   ---
# get next field

    my $field=$node->group($j);

    if(!$field && $arg->{-OPT}) {
      last;

    };

# ---   *   ---   *   ---
# check field has *enough* elements

    if(

        @{$field->leaves}<$count
     && !$arg->{-OPT}

    ) {

      printf

        "Bad number of arguments ".
        "on field $j for ".
        "symbol <".$self->name.">\n";

      exit;

    };$j++;

# ---   *   ---   *   ---
# only the loop changes between paths
# so just shove the proc into a code ref

    my $i=0;my @field_args=();
    my $consume_arg=sub {

      my $leaf=$field->leaves->[$i];
      my $type=$arg->{-TYPES}->[$i];

      # use last defined type (for varargs)
      if(!$type) {
        $type=$arg->{-TYPES}->[-1];

      # check type is OK
      };if(!$self->arg_typechk($leaf,$type)) {
        return 0;

      };push @field_args,$leaf->value;$i++;
      return 1;

    };

# ---   *   ---   *   ---
# consume only up to count elements

    if(!$arg->{-VARARGS}) {

      for(my $x=0;$x<$count;$x++) {
        if(!$consume_arg->()) {return;};

      };

# ---   *   ---   *   ---
# varargs consume all elements left

    } else {

      while($i<@{$field->leaves}) {
        if(!$consume_arg->()) {return;};

      };
    };

# ---   *   ---   *   ---
# pass arguments for each field as
# a list of array references

    push @args,\@field_args;
  };$self->code->($self->name,@args);

};

# ---   *   ---   *   ---
1; # ret
