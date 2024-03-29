#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH VALUE
# A thing stored somewhere
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach::Value;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;

  use Mach::Seg;

  use lib $ENV{'ARPATH'}.'/lib/';
  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.8;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $STR_ATTRS=>{

    ipol  => 0,
    len   => 0,

    width => 'byte',

  };

  Readonly our $FLG_ATTRS=>{

    q[flg-type] => 'bare',
    q[flg-name] => $NULLSTR,

    sigil       => '-',

  };

  Readonly our $RE_ATTRS=>{

    seal  => $NULLSTR,
    flags => {},

  };

  Readonly our $VOKE_ATTRS=>{
    depth=>0,

  };

  Readonly our $FCALL_ATTRS=>{
    proc=>$NULLSTR,
    args=>[],

  };

  Readonly our $OPS_ATTRS=>{

    fn     => $NOOP,
    key    => $NULLSTR,

    unary  => 0,
    slurp  => 0,
    ctx    => 0,
    nconst => 0,

    prio   => 0,

    V      => [],

  };

  Readonly our $ITER_ATTRS=>{
    src  => undef,
    i    => 0,

  };

  Readonly our $SEG_ATTRS=>{};
  Readonly our $STK_ATTRS=>{};

  Readonly our $OBJ_ATTRS=>{
    opath=>[],
    procs=>[],

  };

# ---   *   ---   *   ---
# GBL

  my $Attrs={

    str   => $STR_ATTRS,
    re    => $RE_ATTRS,

    voke  => $VOKE_ATTRS,
    fcall => $FCALL_ATTRS,
    ops   => $OPS_ATTRS,
    iter  => $ITER_ATTRS,

    seg   => $SEG_ATTRS,
    stk   => $STK_ATTRS,
    obj   => $OBJ_ATTRS,

  };

# ---   *   ---   *   ---
# ^fetch

sub getattrs($class,$spec) {

  defined $spec or errout(
    q[Undefined type],
    lvl => $AR_FATAL

  );

  my %out=(exists $Attrs->{$spec})
    ? %{$Attrs->{$spec}}
    : ()
    ;

  return %out;

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$type,$id,%O) {

  # defaults
  $O{spec}  //= [];
  $O{raw}   //= $NULL;
  $O{sign}  //= 0;
  $O{real}  //= 0;
  $O{const} //= 1;
  $O{mach}  //= undef;

  # pop args
  my $spec  = $O{spec};
  my $sign  = $O{sign};
  my $real  = $O{real};
  my $raw   = $O{raw};
  my $const = $O{const};
  my $mach  = $O{mach};

  delete $O{raw};
  delete $O{const};
  delete $O{spec};
  delete $O{sign};
  delete $O{real};
  delete $O{mach};

  # unpack type
  my %attrs=map {
    $class->getattrs($ARG)

  } ($type,@$spec);

  # ^set attrs
  map {$attrs{$ARG}=$O{$ARG}} keys %O;

  # ^fcalls are special ;>
  if($type eq 'fcall') {

    $attrs{proc} = shift @$raw;
    $attrs{raw}  = $raw;

    $raw         = $NULL;

  };


  $const=(defined $attrs{nconst})
    ? $const *! $attrs{nconst}
    : $const
    ;


  # make ice
  my $self=bless {

    id    => $id,

    lis   => {
      fasm=>$NULLSTR

    },

    scope => undef,
    path  => undef,

    sign  => $sign,
    real  => $real,
    type  => $type,
    spec  => $spec,

    raw   => $raw,
    const => $const,

    mach  => $mach,

    %attrs,

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# remove type attrs

sub type_pop($self,@types) {

  # make pattern for removed types
  my $re=re_eiths(\@types,bwrap=>1);

  # mask non-popped types
  my @full = ($self->{type},@{$self->{spec}});
     @full = grep {! ($ARG=~ $re)} @full;

  my %rem  = map {$ARG=>1} @full;

  # ^get list of attrs to keep/remove
  my $class = ref $self;
  my %keep  = map {$class->getattrs($ARG)} @full;
  my %attrs = map {$class->getattrs($ARG)} @types;

  # ^filter
  my @keys=grep {
    ! exists $keep{$ARG}

  } keys %attrs;

  # ^remove non-keeped attrs
  map {delete $self->{$ARG}} @keys;

  # ^change type fields for filtered
  $self->{type}=pop @full;
  $self->{spec}=\@full;

  # ^fallback if no type
  $self->{type}='const';


  # fcalls are special ;>
  if($self->{type} eq 'fcall') {

    $self->{proc} = shift @{$self->{raw}};
    $self->{args} = $self->{raw};

    $self->{raw}  = $NULL;

  };

};

# ---   *   ---   *   ---
# give copy of existing

sub dup($self,%attrs) {

  my $o     = {%$self,%attrs};
  my $class = ref $self;

  my $id    = $o->{id};
  my $type  = $o->{type};

  delete $o->{id};
  delete $o->{type};

  return $class->new($type,$id,%$o);

};

# ---   *   ---   *   ---
# ^recursively rewrites path

sub rdup($self,$path,%attrs) {

  # copy and reset path
  my $cpy = $self->dup(%attrs);
  my $x   = $cpy->get();

  $cpy->{path}=[@$path,$cpy->{id}];


  # ^recurse for each child
  if(is_hashref($x)) {

    map {
      $ARG=$ARG->rdup($cpy->{path});

    } values %$x;

  };

  return $cpy;

};

# ---   *   ---   *   ---
# ^save value to scope

sub bind($self,$scope,@path) {

  errout(

    q[Attempted binding of ]
  . q[annonymous value],

    lvl => $AR_FATAL

  ) if ! length $self->{id};

  @path=$scope->path() if ! @path;

  # remove previous, then set
  $self->unbind() if $self->{scope};

  my $ptr=$scope->decl($self,@path,$self->{id});

  $self->{scope} = $scope;
  $self->{path}  = [@path,$self->{id}];

  return $ptr;

};

# ---   *   ---   *   ---
# ^remove

sub unbind($self) {

  errout(

    q[Attempted unbind of ]
  . q[annonymous value],

    lvl => $AR_FATAL

  ) if ! length $self->{id};

  $self->{scope}->rm(@{$self->{path}});

  $self->{scope} = undef;
  $self->{path}  = [];

};

# ---   *   ---   *   ---
# recursive $self->{raw}

sub deref($self,$lvl=-1) {

  my $out   = undef;

  my $src   = $self;
  my $class = ref $src;

  while($lvl != 0 && $class->is_valid($src)) {
    $out=$src=$src->{raw};
    $lvl--;

  };

  return $out;

};

# ---   *   ---   *   ---
# ^handles setting of
# ref-to-ref values

sub set($self,$other) {

  my $class=ref $self;

  # get referenced value of B
  my $x=($class->is_valid($other))
    ? $other->get()
    : $other
    ;

  # ^set referenced value of A
  (is_scalarref($self->{raw}))
    ? ${$self->{raw}}=$x
    : $self->{raw}=$x
    ;

};

# ---   *   ---   *   ---
# ^getter

sub get($self) {

  return (is_scalarref($self->{raw}))
    ? ${$self->{raw}}
    : $self->{raw}
    ;

};

# ---   *   ---   *   ---
# ^recursive

sub rget($self) {

  my $class = ref $self;
  my $out   = $self->get();

  while($class->is_valid($out)) {
    $out=$out->get();

  };


  return (is_coderef($out))
    ? $out->()
    : $out
    ;

};

# ---   *   ---   *   ---
# value is an indirection layer

sub is_ptr($self) {

  return
     $self->{type} eq 'ops'
  && $self->{key}  eq '->'
  ;

};

# ---   *   ---   *   ---
# ^doubly so

sub is_varref($self,$s,$scope=undef) {

  my $out=0;

  if($scope) {
    my $x=$scope->getvar($s);
    $out=$x && $x->is_ptr();

  };


  return $out;

};

# ---   *   ---   *   ---
# makes id by catting all
# elements of structure

sub data_id($self,$ice,$nconst=0) {

  my $out=$NULLSTR;

  # skip if solvable at compile-time
  if($self->{const} &&! $nconst) {

    my $ptr=$ice->deref($self,key=>1);
    $self->{sign} |= $ptr->{sign};
    $self->{real} |= $ptr->{real};

    $out=$ptr->get();

    goto SKIP;

  };


  # A (operator) B
  if($self->{type} eq 'ops') {

    # get sign|real
    $ice->opsign_flat($self)

    if ! $self->{sign}
    || ! $self->{real}
    ;


    my @args=map {
      $ARG->data_id($ice)

    } @{$self->{V}};

    $out.=(@args > 1)
      ? join $self->{key},@args
      : $self->{key} . $args[0]
      ;

  # paste existing name
  } elsif($self->{id}) {
    $out.=$self->{id};

  # basically NYI
  } else {
    $out.=$self->get();

  };


SKIP:

  $self->{c_data_id}=$out;
  return $out;

};

# ---   *   ---   *   ---
# get bytesize of var

sub get_bwidth($self) {

  my $width=$self->{width};


  # ^value found
  if(defined $width) {

    return (exists $PESZ->{$width})
      ? $PESZ->{$width}
      : $width
      ;

  # ^nope, recalc
  } else {
    nyi('OBJ-WIDTH CALC');

  };

};

# ---   *   ---   *   ---
# get/set fasm alias of var

sub get_fasm_lis($self) {
  return $self->{lis}->{fasm};

};

sub set_fasm_lis($self,$off) {
  my $pos=$off + $self->get_bwidth();
  $self->{lis}->{fasm}="rbp-$pos";

  return $self->{lis}->{fasm};

};

# ---   *   ---   *   ---
# ^gives var declaration

sub fasm_data_decl($self,@path) {

  my $cnt  = $self->get_bwidth();
  my $name = join '.',@path,$self->{id};

  return join "\n",
    ".$name:",
    "  db \$00 dup $cnt"

  ;

};

# ---   *   ---   *   ---
# give string repr for fasm

sub fasm_xlate($self,$ice,%O) {

  # defaults
  $O{attrs} //= [];
  $O{r_dst} //= undef;
  $O{lvl}   //= 0;


  my $mach   = $ice->{mach};
  my $scope  = $mach->{scope};
  my $x86    = $mach->{x86_64};

  my $id     = $self->data_id($ice,1);

  map {

    push @{$O{attrs}},$ARG
    if $self->{$ARG}

  } qw(sign real);


  my $out    = $NULLSTR;
  my @prev   = ();

  my $xcur   = $x86->{cur};

  my $blk    = $scope->curblk();
  my $bst    = $blk->{value};
  my $stktab = $bst->{stktab};


  # value was registered
  if(exists $stktab->{$id}) {

    my $stk={ reverse @{$xcur->{stk}} };

    my $dst=$stk->{$id};
       $out=$dst;

    # operation
    if($self->{type} eq 'ops') {

      # translate as instruction list
      # if operation can't be solved and
      # turned into an immediate

      if(! $ice->const_deref($self)) {

        $self->fasm_xlate_ops(
          $ice,%O,r_dst=>$dst,

        );

      };


    # negation
    } elsif(
       $self->{type}  eq 'flg'
    && $self->{sigil} =~ qr{\-} ) {

      my $alias=$stk->{$self->{q[flg-name]}};

      $self->fasm_xlate_flg(
        $ice,%O,r_dst=>$alias,

      );

      $out=$alias;


    };


    $out=(begswith($out,'rbp-'))
      ? "[$out]"
      : $out
      ;


  # decompose id-less op
  # same as what happens on top
  } elsif($self->{type} eq 'ops') {

    my $scratch=(! $O{r_dst})
      ? $x86->get_scratch()
      : $O{r_dst}
      ;

    $self->fasm_xlate_ops(
      $ice,%O,r_dst=>$scratch,

    );

    $out=$scratch if ! $O{lvl};

    $x86->free_scratch($scratch)
    if ! $O{r_dst};


  # ^just give raw for now
  } else {
    $out=($O{lvl})
      ? $ice->deref($self,key=>1)->get()
      : $id
      ;

  };


  return $out;

};

# ---   *   ---   *   ---
# ^decomposes operations
# into instructions

sub fasm_xlate_ops($self,$ice,%O) {

  # beg instruction block
  my $ins=$self->fasm_xlate_ops_prologue(
    $ice,'ops',%O

  );


  # recurse to solve args
  my @args=();

  map {

    my $dst=$ARG->fasm_xlate(
      $ice,%O,lvl=>$O{lvl}+1

    );

    push @args,$dst;

  } @{$self->{V}};


  # ^save to instruction block
  $self->fasm_xlate_ops_epilogue(
    $ice,$ins,\@args,%O

  );

};

# ---   *   ---   *   ---
# ^for unary flg

sub fasm_xlate_flg($self,$ice,%O) {


  # beg instruction block
  my $ins=$self->fasm_xlate_ops_prologue(
    $ice,'flg',%O

  );

  # ^save to instruction block
  $self->fasm_xlate_ops_epilogue(
    $ice,$ice,$ins,$O{r_dst},%O

  );

};

# ---   *   ---   *   ---
# ^begwraps

sub fasm_xlate_ops_prologue(

  $self,
  $ice,

  $mode,%O

) {

  state $ops_tab={

    '-'=>'sub',
    '+'=>'add',
    '*'=>'mul',
    '/'=>'div',

  };

  state $flg_tab={

    '-'=>'neg',

  };


  # get ctx
  my $mach = $ice->{mach};
  my $x86  = $mach->{x86_64};


  # ^fetch instruction name
  my $key  = ($mode eq 'ops')
    ? $self->{key}
    : $self->{sigil}
    ;

  my $ins  = ($mode eq 'ops')
    ? $ops_tab->{$key}
    : $flg_tab->{$key}
    ;


  # start instruction block
  # if not recursing
  $x86->new_insblk($O{r_dst}) if ! $O{lvl};

  return $x86->attr_tie($ins,$O{attrs});

};

# ---   *   ---   *   ---
# ^endwraps

sub fasm_xlate_ops_epilogue(

  $self,
  $ice,

  $ins,$args,

  %O

) {

  # get ctx
  my $mach = $ice->{mach};
  my $x86  = $mach->{x86_64};

  # ^push to instruction block
  $x86->push_insblk($ins,@$args);

};

# ---   *   ---   *   ---
# give string repr of a
# perl decl of value

sub perl_xlate($self,%O) {

  # defaults
  $O{id}    //= 1;
  $O{value} //= 1;
  $O{scope} //= undef;


  # ^run assoc F
  my @out=();

  push @out,$self->perl_xlate_id($O{scope})
  if $O{id};

  push @out,$self->perl_xlate_value($O{scope})
  if $O{value};


  return @out;

};

# ---   *   ---   *   ---
# ^translates id

sub perl_xlate_id($self,$scope=undef) {

  my $id=$self->{id};
  $self->perl_xlate_flg(\$id,$scope);

  return "\$$id";

};

# ---   *   ---   *   ---
# ^transforms flgs into barewords

sub perl_xlate_flg($self,$sref,$scope=undef) {

  state $tab={

    '$'=>'s',
    '*'=>'x',

  };

  state $re=re_eiths([keys %$tab],opscape=>1);
  state $negative=qr{^\-};


  my $out=0;

  if($$sref=~ s[^($re)][]) {
    $$sref="$tab->{$1}flg_$$sref";
    $out=1;

  } elsif($$sref=~ s[$negative][]) {

    my $pre=($self->is_varref($$sref,$scope))
      ? '$$'
      : '$'
      ;

    $$sref="-$pre$$sref";
    $out=0;

  };

  return $out;

};

# ---   *   ---   *   ---
# ^translates value

sub perl_xlate_value($self,$scope=undef) {

  my $raw=$self->get();
  $raw//='undef';


  if(is_hashref($raw)) {
    $raw=Fmat::deepdump($raw);

  } elsif($self->{type} eq 'bare') {

    $raw=($self->is_varref($raw,$scope))
      ? "\$\$$raw"
      : "\$$raw"
      ;

  } elsif($self->{type} eq 'flg') {
    my $sig=$self->perl_xlate_flg(\$raw,$scope);
    $raw=($sig) ? "\$$raw" : $raw ;

  } elsif($self->{type} eq 'str') {
    $raw="'$raw'";

  } elsif($self->{type} eq 'ops') {

    my $key = $self->{key};
    my @V   = ();


    # member attr or fcall
    if($key eq '->' || $key eq '->*') {

      my $other = $self->{V}->[1];
      my $attr  = $other->get();
      my $sig   = $self->perl_xlate_flg(\$attr);

      $attr=($sig) ? "\$$attr" : $attr;
      $attr=($other->is_ptr) ? "\$$attr" : $attr;

      # fcall adjust
      if($key eq '->*') {
        $key='->';

      # ^attr fetch
      } else {
        $attr="{$attr}";

      };


      @V=(

        $self->{V}->[0]->perl_xlate_value(
          $scope

        ),

        $attr,

      );

      $raw=join $key,@V;


    # ^common ops
    } else {

      $key = ' eq ' if $key eq '==';
      $key = ' ne ' if $key eq '!=';

      @V=map {
        $ARG->perl_xlate_value($scope)

      } @{$self->{V}};

      $raw='(' . (join $key,@V) . ')';

    };

  } elsif($raw eq $NULL) {
    $raw='$NULL';

  };


  return $raw;

};

# ---   *   ---   *   ---
