#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:LX DD
# Data declarations
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::lx::dd;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;

  use Arstd::PM;
  use rd::lx::common;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# custom import method to
# make wrappers

sub import($class) {


  # get package we're merging with
  my $dst=rcaller;


  # ^add flag-type methods
  impwraps $dst,'$self->flag_parse' => q(
    $self,$branch

  ),

  map {["${ARG}_parse" => "\$branch"]}
  qw  (const var public private);


  # ^add data-type methods
  impwraps $dst,'$self->type_parse' => q(
    $self,$branch

  ),

  map {["${ARG}_parse" => "\$branch"]}
  @{$Type::MAKE::ALL_FLAGS};


  return;

};

# ---   *   ---   *   ---
# keyword table

sub cmdset($class,$ice) {


  # get ctx
  my $rd    = $ice->{rd};
  my $mc    = $rd->{mc};

  my $flags = $mc->{bk}->{flags};


  # generate list
  return (


    # value types
    ( map {$ARG => [$OPT_QLIST]}
      @{$Type::MAKE::ALL_FLAGS}

    ),

    'data-decl' => [$VLIST,$OPT_QLIST],


    # segment types
    seg => [$BARE],
    rom => [$BARE],
    ram => [$BARE],
    exe => [$BARE],


    # flags
    ( map {$ARG => [$OPT_QLIST]}
      @{$flags->list()}

    ),

    'flag-list' => [$OPT_QLIST],


  );

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
1; # ret
