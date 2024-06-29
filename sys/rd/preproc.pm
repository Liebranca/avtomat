#!/usr/bin/perl
# ---   *   ---   *   ---
# RD PREPROC
# 80s groove
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::preproc;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Shb7;

  use Arstd::Array;
  use Arstd::PM;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => sub {

    return {

      main    => undef,
      tab     => undef,

      invoke  => undef,
      order   => [],

    };

  },

  fn_t     => 'rd::preprocfn',
  genesis  => ['lib','use','case'],

};

# ---   *   ---   *   ---
# parser genesis

sub ready_or_build($self) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};
  my $tab  = $self->{tab};

  # skip already loaded
  return if defined $self->{tab};


  # begin the kick...
  cload $self->fn_t;

  $tab=$self->{tab}=
    $l2->sigtab_t->new($main);

  $self->{invoke}=
    $l2->sigtab_t->new($main);


  # define token patterns to match
  my $name  = $l1->re(STR => '.+');
  my $curly = $l1->re(SCP => '\{');

  # ^attach function to pattern array
  $tab->begin($self->genesis->[2]);

  $tab->pattern(
    [name => $name],
    [body => $curly],

  );

  $tab->function(\&defproc);
  $tab->object($self);
  $tab->build();


  # ~
  my $sym_re=$l1->re(SYM => '.+');

  $tab->begin($self->genesis->[0]);
  $tab->pattern(

    [name => $sym_re],

  );

  $tab->function(\&_lib);
  $tab->object($self);
  $tab->build();

  $tab->begin($self->genesis->[1]);
  $tab->pattern(

    [name => $sym_re],

  );

  $tab->function(\&_use);
  $tab->object($self);
  $tab->build();


  return;

};

# ---   *   ---   *   ---
# break down a capture value
# from a matched signature

sub deref($self,$nd) {


  # input is hashref?
  if(is_hashref $nd) {

    map {
      $nd->{$ARG}=
        $self->deref($nd->{$ARG})

    } keys %$nd;

    return;

  };


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  my $key  = (Tree->is_valid($nd))
    ? $nd->{value}
    : $nd
    ;


  # have annotated value?
  my $have=$l1->xlate($key);
  return $nd if ! $have;

  my $type=$have->{type};

  # have string?
  if($type eq 'STR') {
    return $have->{data};

  # have num?
  } elsif($type=~ qr{^(?:NUM|SYM|OPR)$}) {
    return $have->{spec};

  # have scope or expression?
  } elsif($type=~ qr{^(?:EXP|SCP)$}) {
    return $nd;


  # have list?
  } elsif($type eq 'LIST') {
    return map {
      $self->deref($ARG)

    } @{$nd->{leaves}};

  # error!
  } else {

    $self->{main}->perr(
      "unreconized: '%s' at preproc::deref",
      args=>[$type],

    );

  };

};

# ---   *   ---   *   ---
# walk expressions in tree and
# clear it up a bit ;>

sub sort_tree($self,$branch) {


  # get ctx
  my $main = $self->{main};
  my $l2   = $main->{l2};
  my $old  = $l2->{branch};

  # descriptor to give!
  my $out={-attr=>undef};


  # walk
  my @lv=@{$branch->{leaves}};

  map {


    # clean up branch
    $l2->{branch} = $ARG;

    $l2->strip_comments($ARG);
    $l2->invoke('fwd-parse'=>'csv');


    # sort expression
    $self->sort_expr($out,@{$ARG->{leaves}});


  } @lv;


  $l2->{branch}=$old;
  return $out;

};

# ---   *   ---   *   ---
# reads expressions inside case

sub sort_expr($self,$status,@lv) {

  return if ! @lv;


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  # get first token
  my $head = $lv[0];
  my $key  = $head->{value};
  my $have = $l1->xlate($key);


  # declaring attribute?
  if(defined $have && $have->{spec} eq 'attr') {

    my $name=$l1->xlate($lv[1]->{value});
       $name=$name->{spec};

    $status->{-attr}   = $name;
    $status->{$name} //= [];

    push @{$status->{$name}},[];


  # adding to definition?
  } elsif($status->{-attr}) {

    my $name = $status->{-attr};
    my $dst  = $status->{$name}->[-1];

    push @$dst,$head->{parent};


  # assume we're defining a function ;>
  } else {

    $status->{-attr}   = 'fn';
    $status->{fn}    //= [];

    push @{$status->{fn}},[];

    my $dst=$status->{fn}->[-1];
    push @$dst,$head->{parent};

  };

};

# ---   *   ---   *   ---
# common path-solving method

sub solve_path($self,$src) {


  # get ctx
  my $main = $self->{main};
  my $mc   = $main->{mc};


  # get file or dir path
  join '/',map {


    # have environment variable?
    my $environ=$ARG=~ s[^ENV\.][];

    # ^validate
    $main->perr(
      "bad environment variable '%s'",
      args=>[$ARG],

    ) if $environ &&! exists $ENV{$ARG};


    # give sub-path
    ($environ)
      ? $ENV{$ARG}
      : $ARG
      ;

  } split $mc->{pathsep},$src;

};

# ---   *   ---   *   ---
# fetch the dir!

sub _lib($self,$data) {


  # get ctx
  my $main = $self->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};

  # unpack arg
  my $name = $data->{name};


  # get path to library
  my $path=$self->solve_path($name);

  # ^validate
  $main->perr(
    "cannot find libpath '%s'",
    args=>[$path]

  ) if ! -d $path;


  # ^all OK, add to search
  push @{$main->{PATH}},$path;
  Shb7::push_includes $path;


  return;

};

# ---   *   ---   *   ---
# ^fetch the file ;>

sub _use($self,$data) {


  # get ctx
  my $main = $self->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};

  # unpack arg
  my $name = $data->{name};


  # get path to object
  my $path  = $self->solve_path($name);
     $path  = Shb7::ffind($path,'pe');

  # ^validate
  $main->perr(
    "missing *.pe object '%s'",
    args=>[$name],

  ) if ! defined $path;


  # recurse
  my $class = ref $main;
  my $fn    = "$class\::crux";
    $fn    = \&$fn;

  my $rd    = $fn->($path);


  # ~
  my $xplant = {
    invoke => $rd->{preproc}->{invoke},
    tab    => $rd->{preproc}->{tab},

  };

  map {

    my ($from,$name)=split $COMMA_RE,$ARG;
    my $have=$xplant->{$from}->{tab}->{$name};

    my $obj=$have->{obj};

    $obj->{main} = $main;
    $obj->{par}  = $self;

    push @{$self->{order}},$ARG;
    $self->{$from}->{tab}->{$name}=$have;

    $name;


  } @{$rd->{preproc}->{order}};

};

# ---   *   ---   *   ---
# default processing for definitions!

sub defproc($self,$data) {


  # get ctx
  my $main = $self->{main};
  my $tab  = $self->{tab};
  my $l2   = $main->{l2};

  # save state
  my $old    = $l2->{branch};
  my $status = $self->sort_tree($data->{body});


  # write to table
  $tab->begin($data->{name});

  $self->tree_to_sig($data,$status);
  my $fn=$self->tree_to_sub($data,$status);

  $tab->build();


  # restore and give
  $l2->{branch}=$old;

  return;

};

# ---   *   ---   *   ---
# reads case signature

sub sigread($self,$sig) {

  map {


    # unpack expressions to proc
    my @tree=@$ARG;
    my @expr=map {
      [@{$ARG->{leaves}}];

    } @tree;


    # ^get array from which to generate sig
    [map {
      $self->sigread_field(@$ARG)

    } @expr];


  } @$sig;

};

# ---   *   ---   *   ---
# ^decomposes signature element!

sub sigread_field($self,@lv) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # first two nodes are type => name
  my ($type,$name)=map {

    my $have=shift @lv;
       $have=$self->deref($have->{value});

    $have;

  } 0..1;


  # third is optional value specifier
  my $spec=(@lv)
    ? $l1->untag($lv[0]->{value})->{data}
    : '.+'
    ;


  # give descriptor
  return {

    type => $type,

    name => $name,
    spec => $spec,

  };

};

# ---   *   ---   *   ---
# map case tree to signature array

sub tree_to_sig($self,$data,$status,$dst='tab') {


  # get ctx
  my $main = $self->{main};
  my $tab  = $self->{$dst};
  my $l1   = $main->{l1};


  # validate signature
  my $sig=$status->{sig}
  or $main->perr(

    "No signature for "
  . "[ctl]:%s '%s'",

    args=>[$data->{-class},$data->{name}],

  );

  # ^proc
  map {

    $tab->pattern(map {

      # get token-matching pattern
      my $re=$l1->re(
        uc $ARG->{type} => $ARG->{spec}

      );

      # if name is NOT quest, then capture
      # else match and discard
      ($ARG->{name} ne '?')
        ? [$ARG->{name}=>$re]
        : $re
        ;

    } @$ARG);

  } $self->sigread($sig);

  return;

};

# ---   *   ---   *   ---
# map case tree to perl sub

sub tree_to_sub($self,$data,$status,$dst='tab') {


  # get ctx
  my $main=$self->{main};

  # validate method
  my $fn=$status->{fn}
  or $main->perr(

    "No method for "
  . "[ctl]:%s '%s'",

    args=>[$data->{-class},$data->{name}],

  );


  # make F container
  my $fn_t   = $self->fn_t;
  my $fstate = $fn_t->new($main);

  $fstate->{par}  = $self;
  $fstate->{meta} = $data;


  # ^proc
  $fstate->fnread($fn);

  $fn = "$fn_t\::run";
  $fn = \&$fn;

  $self->{$dst}->function($fn);
  $self->{$dst}->object($fstate);


  # remember order in which functions are
  # defined, this is required for rebuilding
  # the tables!

  push @{$self->{order}},
    "$dst,$data->{name}";

  return;

};

# ---   *   ---   *   ---
# entry point

sub parse($self,$root) {


  # macro genesis ;>
  #
  # this means parse every definition
  # one by one, then expand new keywords
  # as they are defined!

  my @list=@{$self->genesis};

  @list=map {
    $self->find($root,keyw=>$ARG);

  } @list while @list;


  # execute all and give
  $self->invoke($root);
  return 1;

};

# ---   *   ---   *   ---
# get branches that match keyword

sub find($self,$root,%O) {


  # defaults
  $O{keyw} //= $self->genesis->[2];

  # get ctx
  my $main = $self->{main};
  my $tab  = $self->{tab};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};
  my $old  = $l2->{branch};

  # get patterns
  my $meta=$tab->fetch($O{keyw});
  return if ! $meta->{fn};


  # get branches that contain keyword
  # fail if none found!
  my @have=$root->branches_in($meta->{re});
  return if ! @have;

  # ^walk
  my @out=map {

    # make node current
    my $nd=$ARG;
    $l2->{branch}=$nd;

    # match and validate
    my $data=$tab->matchin($meta,$nd);

    $main->perr(

      "no signature match for "
    . "[ctl]:%s '%s'",

      args=>[$self->genesis->[2],$O{keyw}],

    ) if ! length $data;


    # all OK, unroll and run
    $data->{-invoke} //= [];
    $data->{-class}  //= $O{keyw};

    $self->deref($data);
    my @extra=$tab->run($meta,$data);


    # have on-parse code?
    $self->add_invoke($data->{-invoke})
    if @{$data->{-invoke}};

    # clear branch and give
    $nd->{parent}->discard();

    (@extra)
      ? @extra
      : $data->{name}
      ;


  } @have;

  $l2->{branch}=$old;
  return @out;

};

# ---   *   ---   *   ---
# adds a method to be called
# uppon encountering some
# sequence of tokens

sub add_invoke($self,$headar) {


  # get ctx
  my $main = $self->{main};
  my $dst  = $self->{invoke};
  my $l2   = $self->{l2};


  # save state && walk
  my $old=$l2->{branch};

  map {


    # cleanup/validate input
    my $head   = $ARG;
    my $status = $self->sort_tree($head->{fn});


    # make F using sigtab_t (see: ready_or_build)
    #
    # the same classes used to define builtins
    # are then re-used for user definitions ;>

    $dst->begin($head->{name});

    $dst->pattern(@{$head->{sig}});
    $self->tree_to_sub($head,$status,'invoke');

    $dst->regex($head->{re});
    $dst->build();


  } @$headar;


  # ^restore and give
  $l2->{branch}=$old;
  return;

};

# ---   *   ---   *   ---
# ^executes

sub invoke($self,$root,@src) {


  # get ctx
  my $main = $self->{main};
  my $l2   = $main->{l2};
  my $old  = $l2->{branch};

  # get F to call if none given!
  my $tab=$self->{invoke};

  @src=$tab->find($root)
  if ! @src;



  # walk cases!
  for my $packed(@src) {

    my ($keyw,$data,$nd)=@$packed;
    next if ! $keyw->{fn};

    $l2->{branch}=$nd;
    $tab->run($keyw,$data);

  };


  $l2->{branch}=$old;
  return;

};

# ---   *   ---   *   ---
# encode to binary

sub mint($self) {

  my @out=rd::layer::mint($self);

  return @out,map {
    $ARG=>$self->{$ARG};

  } qw(order tab invoke);

};

# ---   *   ---   *   ---
1; # ret
