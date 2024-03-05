#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:LX
# Slow runner ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::lx;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;

  use Arstd::Array;
  use Arstd::Bytes;
  use Arstd::Re;
  use Arstd::PM;
  use Arstd::IO;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,$rd) {

  return bless {

    rd    => $rd,

    links => [],
    queue => [],

  },$class;

};

# ---   *   ---   *   ---
# reset per-expression state

sub exprbeg($self,$rec=0) {

  # get ctx
  my $Q     = $self->{queue};
  my $have  = $self->{links};

  my $ahead = [];


  # preserve current?
  if($rec > 0) {
    push @$Q,$have;

  # ^restore previous?
  } else {
    $ahead   = pop @$Q;
    $ahead //= [];

  };


  # set or clear state
  @$have=@$ahead;

};

# ---   *   ---   *   ---
# records sub-expression result

sub exprlink($self,$have) {

  my $links=$self->{links};

  if(defined $have) {
    push @$links,$have;
    return $have;

  } else {
    return ();

  };

};

# ---   *   ---   *   ---
# names of execution rounds

sub passes($self) { return qw(
  parse ctx solve xlate run

)};

# ---   *   ---   *   ---
# ^name of subroutine for this pass

sub passf($self,$key) {

  my $CMD  = $self->load_CMD();

  my $pass = $self->passname();
  my $fn   = $CMD->{$key}->{$pass};


  return $fn;

};

# ---   *   ---   *   ---
# makes command args

sub cmdarg($type,%O) {

  # defaults
  $O{opt}   //= 0;
  $O{value} //= '.+';

  # give descriptor
  return {%O,type=>$type};

};

# ---   *   ---   *   ---
# ^shorthands

  Readonly my $QLIST=>cmdarg(['LIST','ANY']);
  Readonly my $VLIST=>cmdarg(

    ['LIST','OPERA','BARE'],
    value=>'[^\{]'

  );

  Readonly my $OPT_QLIST=>{%$QLIST,opt=>1};
  Readonly my $OPT_VLIST=>{%$VLIST,opt=>1};

  Readonly my $BARE  => cmdarg(['BARE']);
  Readonly my $CURLY => cmdarg(
    ['OPERA'],value=>'\{'

  );

  Readonly my $PARENS => cmdarg(
    ['OPERA'],value=>'\('

  );

# ---   *   ---   *   ---
# generate/fetch set of commands

sub cmdset($self) {

  my $rd    = $self->{rd};
  my $mc    = $rd->{mc};

  my $flags = $mc->{bk}->{flags};
  my $imp   = $mc->{ISA}->imp();

  return {


    # dbout
    echo => [$QLIST],
    stop => [],

    # make segment
    seg => [$BARE],
    rom => [$BARE],
    ram => [$BARE],
    exe => [$BARE],

    # user command maker
    cmd        => [$BARE,$OPT_VLIST,$CURLY],
    'bat-cmd'  => [$PARENS,$OPT_VLIST,$CURLY],


    # value types
    ( map {$ARG => [$OPT_QLIST]}
      @{$Type::MAKE::ALL_FLAGS}

    ),

    'data-decl' => [$VLIST,$OPT_QLIST],


    # flags
    ( map {$ARG => [$OPT_QLIST]}
      @{$flags->list()}

    ),

    'flag-list' => [$OPT_QLIST],


    # instructions
    ( map {$ARG => [$OPT_QLIST]}
      @{$imp->list()}

    ),

    'A9M-ins'   => [$OPT_QLIST],


  };

};

# ---   *   ---   *   ---
# shorthand: fetch flag table

sub flagtab($self) {

  my $rd    = $self->{rd};
  my $mc    = $rd->{mc};

  my $flags = $mc->{bk}->{flags};


  return $flags->ivtab();

};

# ---   *   ---   *   ---
# get name of current pass

sub passname($self) {
  return ($self->passes())[$self->{rd}->{pass}];

};

# ---   *   ---   *   ---
# selfex

sub stop_parse($self,$branch) {

  my $rd=$self->{rd};

  $rd->{tree}->prich();
  $rd->perr('STOP');

};

# ---   *   ---   *   ---
# template: collapse cmdlist in
# reverse hierarchical order

sub rcollapse_cmdlist($self,$branch,$fn) {


  # get ctx
  my $rd = $self->{rd};
  my $l1 = $rd->{l1};
  my $l2 = $rd->{l2};


  # first token, first command
  my @list = $l1->is_cmd($branch->{value});
  my $par  = $branch->{parent};

  # ^get tokens from previous iterations
  push @list,@{$branch->{vref}}
  if exists $branch->{vref};

  $branch->{vref} //= \@list;


  # parent is command, keep collapsing
  my $head = $l1->is_cmd($par->{value});
  if(defined $head) {

    # save commands to parent, they'll be
    # picked up in the next run of this F
    $par->{vref} //= [];
    push @{$par->{vref}},@list;

    # ^remove this token
    $branch->discard();


    return;


  # ^stop at last node in the chain
  } else {
    $fn->();

  };

};

# ---   *   ---   *   ---
# set/unset object flags

sub flag_list_parse($self,$branch) {


  # get ctx
  my $rd    = $self->{rd};
  my $links = $self->{links};
  my $obj   = pop @$links;

  my $tab   = $self->flagtab();
  my $flags = $branch->{vref};


  # walk list
  map {


    # can set attr for this object?
    my ($key,$value)=@{$tab->{$ARG}};

    eval {

      (exists $obj->{$key})
        ? $obj->{$key}=$value
        : undef
        ;


    # ^nope, throw!
    } or do {

      $rd->perr(
        "'%s' is invalid for <%s>",
        args=>[$ARG,(ref $obj or 'plain')]

      );

    };


  } @$flags;


  $branch->flatten_branch();

  return;

};

# ---   *   ---   *   ---
# collapses flag list
# mutates node into flag-list

sub flag_parse($self,$branch) {

  # get ctx
  my $rd=$self->{rd};
  my $l1=$rd->{l1};


  # rwalk specifier list
  $self->rcollapse_cmdlist($branch,sub {


    # mutate into another command
    $branch->{value}=$l1->make_tag(
      CMD=>'flag-list'

    );


    return 'mut';

  });

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps(

  q[$self->flag_parse]=>q[$self,$branch],

  map {[
    "${ARG}_parse" => "\$branch"

  ]} qw(const var public private)

);

# ---   *   ---   *   ---
# template: read instruction

sub A9M_ins_parse($self,$branch) {


  # get ctx
  my $rd   = $self->{rd};
  my $mc   = $rd->{mc};
  my $ISA  = $mc->{ISA};


  # solve argument tree
  my $idex = 0;
  my @list = $self->A9M_recarg($branch,\$idex);


  # ^break down array
  my $type=undef;
  my @args=();

  array_map \@list,sub ($kref,$vref) {

    my $k=$$kref;
    my $v=$$vref;

    if($k ne 'type') {
      push @args,$v;

    } else {
      $type=$v;

    };


  },'kv';


  # fetch default instruction size
  $type //= $ISA->deft();


  # write instruction to current segment
  my $have=$mc->exewrite(
    $mc->{scope}->{mem},
    [$type,$branch->{cmdkey},@args]

  );

  # ^catch encoding fail
  $rd->perr("cannot encode instruction")
  if ! length $have;


  return;

};

# ---   *   ---   *   ---
# ^template: read operand

sub A9M_arg($self,$branch,$iref) {

  # get ctx
  my $rd  = $self->{rd};
  my $mc  = $rd->{mc};
  my $l1  = $rd->{l1};

  my $src = $branch->{value};


  # recurse on list
  if(defined $l1->is_list($src)) {
    return $self->A9M_recarg($branch,$iref);


  # ^have number?
  } elsif(defined (my $num=$l1->is_num($src))) {

    my $type=(16 > bitsize $num)
      ? 'ix'
      : 'iy'
      ;

    return

       "arg".$$iref++
    => {type=>$type,imm=>$num};


  # ^have type specifier?
  } elsif(defined (my $type=$l1->is_type($src))) {

    return

      type=>$branch->{vref},
      $self->A9M_recarg($branch,$iref);


  # ^operation?
  } elsif(defined $l1->is_opera($src)) {


    # have memory operand?
    my $b=$branch->{leaves}->[0];
    if(defined $l1->is_branch($b->{value})) {


      # NOTE:
      #
      #   value tree collapsing is NYI
      #   so all we can do here is identify
      #   immediate offsets!

      my ($imm)=map {

        my ($x,$have)=
          $self->value_solve($ARG);

        $l1->quantize($x);

      } @{$b->{leaves}};


      # is symbol ref?
      my $ptrcls = $mc->{bk}->{ptr};
      my $seg    = $mc->{scope};

      if($ptrcls->is_valid($imm)) {
        $seg=$imm->getseg();
        $imm=$imm->{addr};

      };


      return "arg".$$iref++ => {

        type => 'mimm',

        seg  => $mc->segid($seg),
        imm  => $imm,

      };


    };


  # ^have bareword
  } else {

    my $reg  = $mc->{bk}->{anima};
    my $idex = $reg->tokin($src);

    my $type = (defined $idex)
      ? 'r'
      : nyi 'bareword operands'
      ;

    if($type eq 'r') {

      return

         "arg".$$iref++
      => {type=>$type,reg=>$idex};

    };

  };

};

# ---   *   ---   *   ---
# ^recursively

sub A9M_recarg($self,$branch,$iref) {
  map {$self->A9M_arg($ARG,$iref)}
  @{$branch->{leaves}};

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps(

  q[$self->A9M_ins_parse]=>q[$self,$branch],

  map {[
    "${ARG}_parse" => "\$branch"

  ]} qw(load store)

);

# ---   *   ---   *   ---
# make new segment

sub seg_parse($self,$branch) {

  my $rd   = $self->{rd};
  my $mc   = $rd->{mc};

  my $lv   = $branch->{leaves};
  my $name = $lv->[0]->{value};


  # scoping or making new?
  my $mem  = $mc->{cas};
  my $have = $mem->haslv($name);

  my $seg  = (! $have)
    ? $mem->new(0x10,$name)
    : $have
    ;


  # make current and give
  $mc->segid($seg);
  $mc->scope($seg->ances_list());


  return $seg;

};

# ---   *   ---   *   ---
# ^shorthand: segment types

sub rom_parse($self,$branch) {

  my $seg=$self->seg_parse($branch);
  $seg->{writeable}=0;

  return $seg;

};

sub ram_parse($self,$branch) {

  my $seg=$self->seg_parse($branch);
  $seg->{writeable}=1;

  return $seg;

};

sub exe_parse($self,$branch) {

  my $seg=$self->seg_parse($branch);
  $seg->{executable}=1;

  return $seg;

};

# ---   *   ---   *   ---
# entry point for (exprtop)[*type] (values)
#
# not called directly, but rather
# by mutation of [*type] (see: type_parse)

sub data_decl_parse($self,$branch) {

  # get ctx
  my $rd    = $self->{rd};
  my $l1    = $rd->{l1};
  my $l2    = $rd->{l2};

  my $mc    = $rd->{mc};
  my $scope = $mc->{scope};
  my $type  = $branch->{vref};


  # get [name=>value] arrays
  my ($name,$value)=map {

    (defined $l1->is_list($ARG->{value}))
      ? $ARG->{leaves}
      : [$ARG]
      ;

  } @{$branch->{leaves}};


  # ensure value for each name
  # then attempt solving value
  my $idex     = 0;
  my @unsolved = map {

    $value->[$idex] //= $branch->inew(
      $l1->make_tag('NUM'=>0x00)

    );

    my $n=$ARG->{value};
    my $v=$value->[$idex++];


    # redecl guard
    $self->throw_redecl('value',$n)
    if $scope->has($n);

    # *attempt* solving
    my ($x,$have)=$self->value_solve($v);

    # ^reserve space
    $x=$l1->quantize($x);
    $mc->decl($type,$n,$x);

    # ^give if not solved!
    (! defined $have) ? [$n=>$v] : () ;


  } @$name;


  $self->wait_next_pass($branch,\@unsolved);


};

# ---   *   ---   *   ---
# try to make sense of a symbol!

sub value_solve($self,$value) {


  # get ctx
  my $rd    = $self->{rd};
  my $mc    = $rd->{mc};
  my $l1    = $rd->{l1};
  my $l2    = $rd->{l2};


  # can solve value now?
  my $have=$l2->value_solve($value);

  # ^zero on nope
  my $x=(! length $have)
    ? $l1->make_tag(NUM=>0)
    : $have
    ;


  return ($x,$have);

};

# ---   *   ---   *   ---
# wait for next pass if values pending
# else discard branch

sub wait_next_pass($self,$branch,$Q) {

  if(@$Q) {

    $branch->{solve_Q} //= [];
    push @{$branch->{solve_Q}},@$Q;

    $branch->clear();


  } else {
    $branch->discard();

  };

};

# ---   *   ---   *   ---
# collapses width/specifier list
#
# mutates node:
#
# * (? exprbeg) [*type] -> [*data-decl]
# * (! exprbeg) [*type] -> [Ttype]

sub type_parse($self,$branch) {


  # get ctx
  my $rd=$self->{rd};
  my $l1=$rd->{l1};
  my $l2=$rd->{l2};


  # rwalk specifier list
  $self->rcollapse_cmdlist($branch,sub {


    # get hashref from flags
    # save it to branch
    my @list=@{$branch->{vref}};
    my $type=$self->type_decode(@list);

    $branch->{vref}=$type;


    # first token in expression?
    if($l2->is_exprtop($branch)) {

      # mutate into another command
      $branch->{value}=
        $l1->make_tag(CMD=>'data-decl')
      . "$type->{name}"
      ;


      return 'mut';


    # ^nope, last or middle
    } else {

      # mutate into command argument
      $branch->{value}=
        $l1->make_tag(TYPE=>$type->{name});


      return;

    };

  });

};

# ---   *   ---   *   ---
# ^fetch/errme

sub type_decode($self,@src) {

  # get type hashref from flags array
  my $rd   = $self->{rd};
  my $type = typefet @src;

  # ^catch invalid
  $rd->perr('invalid type')
  if ! defined $type;


  return $type;

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps(

  q[$self->type_parse]=>q[$self,$branch],

  map {[
    "${ARG}_parse" => "\$branch"

  ]} @{$Type::MAKE::ALL_FLAGS}

);

# ---   *   ---   *   ---
# attempts to solve pending values

sub data_decl_ctx($self,$branch) {

  my $rd   = $self->{rd};
  my $mc   = $rd->{mc};
  my $l1   = $rd->{l1};
  my $type = $branch->{vref};


  # walk values pending resolution
  my @have = map {

    my ($name,$value) = @$ARG;
    my ($have,$x)     = $self->value_solve($value);

    if($have) {


      # fetch value
      my $ref     = $mc->search($name);
      my $mem     = $$ref->getseg();

      my $x       = $l1->quantize($x);


      # have ptr?
      my ($ptr_t) = Type->is_ptr($type);

      $ptr_t=(length $ptr_t)
        ? "$type->{name} $ptr_t"
        : undef
        ;

      # ^sanity check
      my $ptrcls=$mc->{bk}->{ptr};
      if($ptrcls->is_valid($x) &&! $ptr_t) {

        $rd->perr(

          "'%s' is not a pointer type",
          args=>[$type->{name}]

        );

      };


      # overwrite value
      $$ref = $mem->infer(

        $x,

        ptr_t => $ptr_t,
        type  => $type,

        label => $name,
        addr  => $$ref->{addr},

      );

    };


    (! defined $have) ? $ARG : () ;

  } @{$branch->{solve_Q}};


  $self->wait_next_pass($branch,\@have);

};

# ---   *   ---   *   ---
# makes new command!

sub cmd_parse($self,$branch) {

  my $rd=$self->{rd};


  # unpack
  my ($name,$args,$body)=
    @{$branch->{leaves}};

  my $scope = $rd->{scope};
  my $path  = $scope->{path};


  # redecl guard
  $name=$name->{value};
  $self->throw_redecl('user command'=>$name)
  if $scope->has(@$path,'UCMD',$name);


  # ^collapse optional
  if(! defined $body) {
    $body=$args;
    $args=undef;

  };


  # have arguments?
  $args=($args)
    ? $self->argread($args,$body)
    : []
    ;


  # make table for ipret
  my $cmdtab={

    name   => $name,
    body   => $body,

    args   => $args,

  };

  # ^save to current namespace and remove branch
  $scope->decl($cmdtab,@$path,'UCMD',$name);
  $branch->discard();

  my $CMD=$self->load_CMD(1);

  use Fmat;
  fatdump(\$CMD);

  exit;

};

# ---   *   ---   *   ---
# ^errme

sub throw_redecl($self,$type,$name) {

  $self->{rd}->perr(
    "re-declaration of %s '%s'",
    args=>[$type,$name]

  );

};


# ---   *   ---   *   ---
# prepares a table of arguments
# with default values and
# replacement paths into
# command body

sub argread($self,$args,$body) {

  my $rd=$self->{rd};
  my $l1=$rd->{l1};

  # got list or single elem?
  my $ar=(defined $l1->is_list($args->{value}))
    ? $args->{leaves}
    : [$args]
    ;


  # make argsfield
  my $idex = 0;
  my $tab  = [ map {


    # [name => default value]
    my $argname = $ARG->{value};
    my $defval  = undef;


    # have default value?
    my $opera=$l1->is_opera($ARG->{value});

    # ^yep
    if(defined $opera && $opera eq '=') {

      ($argname,$defval)=(
        $ARG->{leaves}->[0]->{value},
        $ARG->{leaves}->[1]

      );

    };


    # make replacement paths
    # this helps insert value later
    my $replpath = [];
    my @pending  = $body;

    my $subst    = "\Q$argname";
    my $subststr = "\%$subst\%";
       $subst    = qr{\b(?:$subst)\b};
       $subststr = qr{(?:$subststr)};

    my $place    = ":__ARG[$idex]__:";
    my $replre   = qr"\Q$place";


    # recursive walk tree of body
    while(@pending) {

      my $nd=shift @pending;

      # have string?
      my $re=(defined $l1->is_string($nd->{value}))
        ? $subststr
        : $subst
        ;


      if($nd->{value}=~ s[$re][$place]) {
        my $path=$nd->ancespath($body);
        push @$replpath,$path;

      };

      unshift @pending,@{$nd->{leaves}};

    };

    $idex++;


    # give argname => argdata
    $argname=>{

      repl   => {
        path => $replpath,
        re   => $replre,

      },

      defval => $defval,

    };


  } @$ar ];


  $args->discard();

  return $tab;

};

# ---   *   ---   *   ---
# consume argument nodes for command

sub argsume($self,$branch) {


  # skip if nodes parented to branch
  # or parent is invalid
  my @lv  = @{$branch->{leaves}};
  my $par = $branch->{parent};

  return if @lv ||! $par;


  # get siblings, skip if none
  my @sib=@{$par->{leaves}};
     @sib=@sib[$branch->{idex}+1..$#sib];

  return if ! @sib;


  # get command meta
  my $rd   = $self->{rd};

  my $CMD  = $self->load_CMD();
  my $key  = $rd->{branch}->{cmdkey};
  my $args = $CMD->{$key}->{-args};
  my $pos  = $branch->{idex}+1;


  # walk siblings
  $rd->{branch}=$par;

  for my $arg(@$args) {

    my $have=$self->argtypechk($arg,$pos);

    $self->throw_badargs($key,$arg,$pos)
    if ! $have &&! $arg->{opt};

    $pos++ if $have;

    $branch->pushlv($have);

  };


  # restore old
  $rd->{branch}=$branch;
  return;

};

# ---   *   ---   *   ---
# type-checks command arguments

sub argchk($self) {


  # get command meta
  my $rd   = $self->{rd};

  my $CMD  = $self->load_CMD();
  my $key  = $rd->{branch}->{cmdkey};
  my $args = $CMD->{$key}->{-args};
  my $pos  = 0;


  # walk child nodes and type-check them
  for my $arg(@$args) {

    my $have=$self->argtypechk($arg,$pos);

    $self->throw_badargs($key,$arg,$pos)
    if ! $have &&! $arg->{opt};

    $pos++ if $have;

  };

};

# ---   *   ---   *   ---
# ^guts, looks at single
# type option for arg

sub argtypechk($self,$arg,$pos) {


  # get anchor
  my $rd=$self->{rd};
  my $l1=$rd->{l1};

  my $nd=$rd->{branch};


  # walk possible types
  for my $type(@{$arg->{type}}) {

    # get pattern for type
    my $re=$l1->tagre($type => $arg->{value});

    # return true on pattern match
    my $chd=$nd->{leaves}->[$pos];
    return $chd if $chd && $chd->{value}=~ $re;

  };


  return 0;

};

# ---   *   ---   *   ---
# ^errme

sub throw_badargs($self,$key,$arg,$pos) {

  my $rd    = $self->{rd};

  my $value = $rd->{branch}->{leaves};
     $value = $value->[$pos]->{value};

  my @types = @{$arg->{type}};


  $rd->perr(

    "invalid argtype for command '%s'\n"
  . "position [num]:%u: '%s'\n"

  . "need '%s' of type "
  . (join ",","'%s'" x int @types),

    args=>[$key,$pos,$value,$arg->{value},@types],

  );

};

# ---   *   ---   *   ---
# generate/fetch command table

sub load_CMD($self,$update=0) {


  # skip update?
  state $CMD = {};
  return $CMD if int %$CMD &&! $update;


  # regen cache
  my $cmdset = $self->cmdset();
  my @keys   = keys %$cmdset;

  $CMD={


    # re to match any command name
    -re=>re_eiths(

      \@keys,

      opscape => 1,
      bwrap   => 1,
      whole   => 1,

    ),


    # command list [cmd=>attrs]
    map {


      # get name of command
      my $key   = $ARG;
      my $args  = $cmdset->{$key};

      my $plkey =  $key;
         $plkey =~ s[\-][_]sxmg;


      # get subroutine variants of
      # command per execution layer
      $key => {

        -args=>$args,

        map { $ARG => codefind(
          (ref $self),"${plkey}_$ARG"

        )} $self->passes()

      };


    } @keys

  };


  return $CMD;

};

# ---   *   ---   *   ---
1; # ret
