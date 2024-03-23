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

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# custom import method to
# make wrappers

sub import($class) {


  # get package we're merging with
  my $dst=rcaller;


  # ^add segment-type methods
  impwraps $dst,'$self->seg_parse' => q(
    $self,$branch

  ),

  map {["${ARG}_parse" => "\$branch,'$ARG'"]}
  qw  (rom ram exe);


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
  my $main  = $ice->{main};
  my $mc    = $main->{mc};

  my $flags = $mc->{bk}->{flags};


  # generate list
  return (


    # value types
    ( map {$ARG => [$OPT_QLIST]}
      @{$Type::MAKE::ALL_FLAGS}

    ),

    'data-decl' => [$VLIST,$OPT_QLIST],


    # segment types
    seg => [$SYM],
    rom => [$SYM],
    ram => [$SYM],
    exe => [$SYM],


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

  my $main  = $self->{main};
  my $mc    = $main->{mc};

  my $flags = $mc->{bk}->{flags};


  return $flags->ivtab();

};

# ---   *   ---   *   ---
# set/unset object flags

sub flag_list_parse($self,$branch) {


  # get ctx
  my $main  = $self->{main};
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

      $main->perr(
        "'%s' is invalid for <%s>",
        args=>[$ARG,(ref $obj or 'plain')]

      );

    };


  } @$flags;


  $branch->flatten_branch();

  return 1;

};

# ---   *   ---   *   ---
# collapses flag list
# mutates node into flag-list

sub flag_parse($self,$branch) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};


  # rwalk specifier list
  $self->rcollapse_cmdlist($branch,sub {


    # mutate into another command
    $branch->{value}=$l1->make_tag(
      CMD=>'flag-list'

    );


    return $l2->node_mutate();

  });

};

# ---   *   ---   *   ---
# read segment decl/select

sub seg_parse($self,$branch,$type=null) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # clean name
  my $lv   = $branch->{leaves};
  my $name = $lv->[0]->{value};
     $name = $l1->is_sym($name);


  # prepare branch for ipret
  $branch->{vref}={
    type=>$type,
    name=>$name,

  };

  $branch->clear();


  # need mutate?
  if(length $type) {

    $branch->{value}=
      $l1->make_tag(CMD=>'seg')
    . "$type"
    ;

  };


  return;

};

# ---   *   ---   *   ---
# ^step on

sub seg_solve($self,$branch) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};

  # get segment name and type
  my $data = $branch->{vref};
  my $name = $data->{name};
  my $type = $data->{type};


  # scoping or making new?
  my $mem  = $mc->{cas};
  my $have = $mem->haslv($name);

  # ^making new, decl and set flags
  if(! $have) {

    $have=$mem->new(0x10,$name);

    $have->{writeable}  = int($type=~ qr{^ram$});
    $have->{executable} = int($type=~ qr{^exe$});

  };


  # make current and give
  $mc->segid($have);
  $mc->scope($have->ances_list());


  return $have;

};

# ---   *   ---   *   ---
# entry point for (exprtop)[*type] (values)
#
# not called directly, but rather
# by mutation of [*type] (see: type_parse)
#
# reads a data declaration!

sub data_decl_parse($self,$branch) {


  # get ctx
  my $main  = $self->{main};
  my $l1    = $main->{l1};
  my $l2    = $main->{l2};

  my $mc    = $main->{mc};
  my $scope = $mc->{scope};
  my $type  = $branch->{vref};


  # get [name=>value] arrays
  my ($name,$value)=map {

    (defined $l1->is_list($ARG->{value}))
      ? $ARG->{leaves}
      : [$ARG]
      ;

  } @{$branch->{leaves}};


  # get [name=>value] array
  my $idex = 0;
  my @list = map {


    # ensure default value for each name
    $value->[$idex] //= $branch->inew(
      $l1->make_tag('NUM'=>0x00)

    );

    # get symbol name
    my $n=$ARG->{value};
       $n=$l1->is_sym($n);

    # give [name=>value] and go next
    my $v=$value->[$idex++];
    [$n=>$v];


  } @$name;


  # prepare branch for ipret
  $branch->{vref}={
    type => $type,
    list => \@list,

  };

  $branch->clear();

  return;

};

# ---   *   ---   *   ---
# ^performs those declarations
#
# attempts solving values;
# re-run the solve stage if
# not all values resolved

sub data_decl_solve($self,$branch) {

  # get ctx
  my $main  = $self->{main};
  my $mc    = $main->{mc};
  my $l1    = $main->{l1};

  my $scope = $mc->{scope};

  # get pending values
  my $data = $branch->{vref};
  my $type = $data->{type};
  my $list = $data->{list};


  # walk values pending resolution
  my @have = map {


    # unpack
    my ($name,$value)=@$ARG;


    # *attempt* solving
    my ($x,$have)=
      $self->value_solve($value);

    $x=$l1->quantize($x);


    # assume declaration on first pass
    if(! $main->{pass}) {

      $self->throw_redecl('value',$name)
      if $scope->has($name);

      $mc->decl($type,$name,$x);


    # ^else we're retrying value resolution
    } elsif($have) {


      # fetch value
      my $ref = $mc->psearch($name);
      my $mem = $$ref->getseg();

      my $x   = $l1->quantize($x);


      # have ptr?
      my ($ptr_t) = Type->is_ptr($type);

      # ^sanity check
      my $ptrcls=$mc->{bk}->{ptr};
      if($ptrcls->is_valid($x) &&! $ptr_t) {

        $main->perr(

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

  } @$list;


  # wait for next pass if values pending
  # else discard branch
  if(@have) {
    @$list=@have;
    return $branch;


  } else {
    $branch->discard();
    return;

  };

};

# ---   *   ---   *   ---
# try to make sense of a symbol!

sub value_solve($self,$value) {


  # get ctx
  my $main = $self->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};


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
# collapses width/specifier list
#
# mutates node:
#
# * (? exprbeg) [*type] -> [*data-decl]
# * (! exprbeg) [*type] -> [Ttype]

sub type_parse($self,$branch) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};


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


      return $l2->node_mutate();


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
  my $main = $self->{main};
  my $type = typefet @src;

  # ^catch invalid
  $main->perr('invalid type')
  if ! defined $type;


  return $type;

};

# ---   *   ---   *   ---
1; # ret
