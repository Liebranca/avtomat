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
package peso::symbol;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use peso::ptr;
  use peso::block;

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

  if(blessed($sym) && $sym->isa('peso::symbol')) {
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

       ($opt || $varargs)
    && $arg ne $args[-1]

    ) {

      printf

        "Can't make symbol '$name': ".

        "optional and variable-number ".
        "arguments only allowed on ".
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

  },'peso::symbol';

  return $sym;

};

# ---   *   ---   *   ---

sub arg_typechk {

  my $self=shift;
  my $addr=shift;
  my $type=shift;

  if($type eq 'bare') {
    return;

  };

  my $ptr=peso::ptr::fetch($addr);
  if(!peso::ptr::valid($ptr)) {

    printf sprintf
      "ADDR <0x%X> is not a pointer\n",
      $addr;

    exit;

  };

  if(

     defined $type
  && defined $ptr->type

  && $type ne $ptr->type

  ) {

    printf

      "Bad type for symbol '".
      $self->name.
      "'\n";

    exit;

  };

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
# check field has *enough* elements

    my $field=$node->group($j);

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
# consume only up to count elements

    my $i=0;
    if(!$arg->{-VARARGS}) {

      for(my $x=0;$x<$count;$x++) {
        my $leaf=$field->leaves->[$i];
        my $type=$arg->{-TYPES}->[$i];

        if($type ne 'bare') {
          peso::block::treesolve($field);

        };

        $self->arg_typechk(
          $leaf->val,$type

        );push @args,$leaf->val;$i++;

      };

# ---   *   ---   *   ---
# varargs consume all elements left

    } else {

      while($i<@{$field->leaves}) {
        my $v=$field->leaves->[$i]->val;

        $self->arg_typechk(
          $v,$arg->{-TYPES}->[$i]

        );push @args,$v;$i++;

      };
    };

  };

# ---   *   ---   *   ---

  $self->code->(@args);

};

# ---   *   ---   *   ---
1; # ret
