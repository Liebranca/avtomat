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

  use Arstd::Array;
  use Arstd::PM;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => sub {

    return {

      main    => undef,
      tab     => undef,

      invoke  => {},

    };

  },

  sigtab_t => 'rd::sigtab',

  fn_t     => 'rd::preprocfn',
  genesis  => 'case',

};

# ---   *   ---   *   ---
# parser genesis

sub ready_or_build($self) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $tab  = $self->{tab};

  # skip already loaded
  return if defined $self->{tab};


  # begin the kick...
  cload $self->fn_t;
  cload $self->sigtab_t;
  cload $self->sigtab_t->sig_t;

  $tab=$self->{tab}=
    $self->sigtab_t->new($main);


  # define token patterns to match
  my $name  = $l1->re(STR => '.+');
  my $curly = $l1->re(SCP => '\{');

  # ^attach function to pattern array
  $tab->begin($self->genesis);

  $tab->pattern(

    [name => $name],
    [loc  => 0],

    [body => $curly],

  );

  $tab->function(\&defproc);
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

  # descriptor to give!
  my $out={-attr=>undef};


  # walk
  my @lv=@{$branch->{leaves}};

  map {


    # clean up branch
    $main->{branch} = $ARG;

    $l2->strip_comments($ARG);
    $l2->cslist();


    # sort expression
    $self->sort_expr($out,@{$ARG->{leaves}});


  } @lv;

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
# default processing for definitions!

sub defproc($self,$data) {


  # get ctx
  my $main = $self->{main};
  my $tab  = $self->{tab};

  # save state
  my $old    = $main->{branch};
  my $status = $self->sort_tree($data->{body});


  # write to table
  $tab->begin($data->{name});

  $self->tree_to_sig($data,$status);
  $self->tree_to_sub($data,$status);

  $tab->build();


  # restore and give
  $main->{branch}=$old;

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

sub tree_to_sig($self,$data,$status) {

  # get ctx
  my $main = $self->{main};
  my $tab  = $self->{tab};
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

sub tree_to_sub($self,$data,$status) {

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
  my $fstate=$self->fn_t->new($main);

  $fstate->{par}  = $self;
  $fstate->{meta} = $data;


  # ^proc and generate perl sub
  my @program=$fstate->fnread($fn);
  $fn=sub ($ice,$idata,@slurp) {


    # this field means a directive is being
    # called from within another, it holds the
    # nodes or values it was invoked with
    #
    # this means we have to expand certain
    # values that could lose meaning if passed
    # as-is, such as references to local attrs

    $fstate->argparse(@slurp) if @slurp;


    # ^all values expanded, run F
    $fstate->{data}=$idata;

    map {
      my ($ins,@args) = @$ARG;
      $ins->($fstate,@args);

    } @program;

    return;

  };

  $self->{tab}->function($fn);
  return $fn;

};

# ---   *   ---   *   ---
# entry point

sub parse($self,$root) {


  # macro genesis ;>
  #
  # this means parse every definition
  # one by one, then expand new keywords
  # as they are defined!

  my @list=$self->genesis;

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
  $O{keyw} //= $self->genesis;

  # get ctx
  my $main     = $self->{main};
  my $l1       = $main->{l1};
  my $tab      = $self->{tab};

  # get patterns
  my $meta     = $tab->fetch($O{keyw});
  my $keyw_re  = $meta->{re};
  my $keyw_fn  = $meta->{fn};

  return if ! $keyw_fn;


  # get branches that contain keyword
  # fail if none found!
  my @have=$root->branches_in($keyw_re);
  return if ! @have;

  # ^walk
  map {

    # make node current
    my $nd=$ARG;
    $main->{branch}=$nd;

    # match and validate
    my $data=$tab->match($O{keyw},$nd);

    $main->perr(

      "no signature match for "
    . "[ctl]:%s '%s'",

      args=>[$self->genesis,$O{keyw}],

    ) if ! length $data;


    # all OK, unroll and run
    $data->{-invoke} //= [];
    $data->{-class}  //= $O{keyw};

    $self->deref($data);
    $keyw_fn->($self,$data);


    # have on-parse code?
    $self->add_invoke($data->{-invoke})
    if @{$data->{-invoke}};

    # clear branch and give
    $nd->{parent}->discard();
    $data->{name};


  } @have;

};

# ---   *   ---   *   ---
# adds a method to be called
# uppon encountering some
# sequence of tokens

sub add_invoke($self,$headar) {


  # get ctx
  my $main = $self->{main};
  my $dst  = $self->{invoke};


  # save state && walk
  my $old=$main->{branch};

  map {


    # make F
    my $head   = $ARG;
    my $status = $self->sort_tree($head->{fn});

    $head->{fn}=
      $self->tree_to_sub($head,$status);


    # write to method table
    my $name=$head->{name};
    $dst->{$name}=$head;


  } @$headar;


  # ^restore and give
  $main->{branch}=$old;
  return;

};

# ---   *   ---   *   ---
# ^executes

sub invoke($self,$root,@src) {


  # get ctx
  my $main=$self->{main};

  # get F to call if none given!
  @src=$self->invoke_order($root)
  if ! @src;


  # walk cases!
  for my $key(@src) {


    # unpack
    my $head = $self->{invoke}->{$key};
    my $sig  = $head->{sig};

    next if ! exists $head->{fn};


    # have match for first token?
    my $nd=$root->branch_in($sig->[0]);
    next if ! $nd;


    # find fwd nodes matching signature
    my ($valid,@args)=$nd->cross_sequence(
      @{$sig}[1..@$sig-1]

    );


    # ^validate
    $main->perr(

      "too few arguments for "
    . "[ctl]:%s '%s'",

      args=>[
        $self->genesis,
        $$head->{data}->{name}

      ],

    ) if @args < @$sig-1;


    # ^call
    if($valid) {

      $nd->pushlv(@args);

      $main->{branch}=$nd;
      $head->{fn}->($self,$head->{data});

    };


  };

  return;

};

# ---   *   ---   *   ---
# gets list of calls to make
# by performing a cannonical walk

sub invoke_order($self,$root) {


  # get ctx
  my $tab  = $self->{invoke};
  my @have = keys %$tab;


  # walk the tree
  my @Q   = @{$root->{leaves}};
  my @out = ();

  while(@Q) {

    my $nd   = shift @Q;
    my $deep = 0;

    # look for matches...
    for my $key(@have) {

      my $sig=$tab->{$key}->{sig};

      # have a match deeper down?
      $deep |= defined
        $nd->branch_in($sig->[0]);


      # have a match HERE?!
      if($nd->{value}=~ $sig->[0]) {

        my ($valid,@args)=$nd->cross_sequence(
          @{$sig}[1..@$sig-1]

        );


        # ^YES
        if($valid) {
          push @out,$key;
          last;

        };

      };


    };


    # go next?
    unshift @Q,@{$nd->{leaves}}
    if $deep;

  };


  # give found!
  return @out;

};

# ---   *   ---   *   ---
1; # ret
