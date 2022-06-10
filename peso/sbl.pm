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
  use Scalar::Util qw/blessed/;

# ---   *   ---   *   ---
# getters

sub name($) {return (shift)->{-NAME};};
sub args($) {return (shift)->{-ARGS};};
sub argc($) {return (shift)->{-ARGC};};

sub code($) {return (shift)->{-CODE};};

sub num_fields($) {return (shift)->{-NUM_FIELDS};};
sub frame($) {return (shift)->{-FRAME};};

# ---   *   ---   *   ---

sub valid($) {

  my $sym=shift;

  if(blessed($sym) && $sym->isa('peso::sbl')) {
    return 1;

  };return 0;

};

# ---   *   ---   *   ---
# constructors

sub new_frame() {
  return peso::sbl::frame::create();

};

# ---   *   ---   *   ---

sub nit($$$$) {

  my ($frame,$name,$argv,$code)=@_;

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
    -FRAME=>$frame,

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
    -FRAME=>$src->frame,

  },'peso::sbl';

  return $sym;

};

# ---   *   ---   *   ---
# check that elements in field correspond
# to valid argument types for symbol

sub arg_typechk($$$) {

  my ($self,$node,$proto)=@_;
  my $frame=$self->frame;

  my $master=$frame->master;
  my $fr_ptr=$master->ptr;
  my $fr_blk=$master->blk;

  my $lang=$master->lang;

  my $names=$lang->names;
  my $ops=$lang->ops;

# ---   *   ---   *   ---

  my $tag=$node->value;
  my $valid=0;

  for my $v(split '\|',$proto) {

    if($v eq 'ptr') {
      $valid=$fr_ptr->valid($tag);

    # either a string, number or dereference
    } elsif($v eq 'bare') {
      $valid
        =  int($tag=~ m/${names}/)
        || int($tag=~ m/-?[0-9]+/);

# ---   *   ---   *   ---
#:!;> this is a hack

    } elsif($v eq 'path') {

      $valid=(

        $lang->op_prec
        ->{$node->value->{op}}
        ->[$node->value->{idex}]->[0]

      )==-1;$node->collapse();

# ---   *   ---   *   ---

    } elsif($v eq 'type') {
      my $pat=$lang->types->{re};
      $valid=int($tag=~ m/^${pat}/);

    };

    if($valid) {
      return 1;

    };

  };

# ---   *   ---   *   ---
# errme

  if($fr_blk->fpass) {return 0;};

  printf sprintf

    "Invalid argument type for symbol '%s'\n".
    "Valid types are: %s\n",

    $self->name,
    (join ' or ',(split '\|',$proto));

  exit;

};

# ---   *   ---   *   ---
# check passed arguments and execute

sub ex($$) {

  my ($self,$node)=@_;

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

    my $field=$node->fieldn($j++);
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

    };

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
  };

# ---   *   ---   *   ---

  $self->code->(

    $self->name,
    $self->frame,

    @args

  );
};

# ---   *   ---   *   ---

package peso::sbl::frame;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# getters

sub SYMS($) {return (shift)->{-SYMS};};
sub INS($) {return (shift)->{-INS};};
sub INSID($) {return (shift)->{-INSID};};

sub master($) {return (shift)->{-MASTER};};

# ---   *   ---   *   ---
# shorthand for orderly symbol nit

sub DEFINE($$$$) {

  my ($frame,$key,$src,$code)=@_;

  my $idex=$src->{$key}->[0];
  my $args=$src->{$key}->[1];

  my $sym=$frame->nit($key,$args,$code);

  $frame->INS->[$idex]
    =$frame->SYMS->{$key}=$sym;

  $frame->INSID->{$key}=$idex;

# ---   *   ---   *   ---
# shorthand for creating symbol aliases

};sub ALIAS($$$) {

  my ($frame,$key,$src)=@_;

  my $sym=$frame->SYMS->{$src}->dup($key);
  my $idex=$frame->INSID->{$src};

  $frame->INS->[$idex]
    =$frame->SYMS->{$key}=$sym;

  $frame->INSID->{$key}=$idex;

};

# ---   *   ---   *   ---

sub nit($$$$) {
  return peso::sbl::nit(
    $_[0],$_[1],$_[2],$_[3],

  );

# ---   *   ---   *   ---

};sub create() {

  my $frame=bless {

    -SYMS=>{},
    -INS=>[],
    -INSID=>{},

    -MASTER=>undef,

  },'peso::sbl::frame';

  return $frame;

# ---   *   ---   *   ---

};sub setdef($$) {

  my ($self,$def)=@_;
  $self->{-MASTER}=$def;

};

# ---   *   ---   *   ---
# go through a list of nodes and consume them
# as if they were a [command,args] array

sub ndconsume($$$) {

  my ($frame,$node,$i)=@_;

  my $master=$frame->master;
  my $fr_def=$master->defs;

  my $keywords=$fr_def->SYMS();
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
1; # ret
