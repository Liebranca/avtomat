#!/usr/bin/perl
# ---   *   ---   *   ---
# RD PREPROCFN
# F-enn macros!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::preprocfn;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Storable;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => {

    main => undef,
    par  => undef,
    data => undef,
    meta => undef,

  },

};

# ---   *   ---   *   ---
# maps attr nodes to perl sub

sub fnread($self,$fn) {


  # get ctx
  my $main = $self->{main};

  # walk input
  my @program = map {

    my @tree=@$ARG;

    map {


      $main->{branch}=$ARG;

      my ($ins,@args)=
        $self->fnread_field($ARG);

      my $ref=$self->fetch($ins);
      [$ref,@args];

    } @tree;

  } @$fn;


  return @program;

};

# ---   *   ---   *   ---
# ^decomposes single branch!

sub fnread_field($self,$branch) {


  # get ctx
  my $main = $self->{main};
  my $par  = $self->{par};
  my $l1   = $main->{l1};
  my @lv   = @{$branch->{leaves}};


  # first token is name of F
  my $name = shift @lv;
     $name = $par->deref($name->{value});

  # ^whatever follows is args!
  my @args=map {$par->deref($ARG)} @lv;


  return ($name,@args);

};

# ---   *   ---   *   ---
# get sub or die

sub fetch($self,$name) {


  # get ctx
  my $main  = $self->{main};
  my $par   = $self->{par};

  my $class = ref $self;


  # get list of subroutines
  no strict 'refs';

  my %tab   = %{"$class\::"};
  my @valid = grep {
     defined &{$tab{$ARG}};

  } keys %tab;


  # ^get name is defined in this package
  my ($have) = grep {
     $ARG =~ qr{^_?$name$}

  } @valid;

  # ^backup: get name is user-defined
  if(! $have) {

    my $tab  = $par->{tab};
       $have = $tab->{$name}->{fn};

  };


  # ^validate either case
  $main->perr(

    "[ctl]:%s function '%s' "
  . "not implemented",

    args=>[$par->genesis,$name],

  ) if ! defined $have;

  # give coderef
  $have=\&$have if ! is_coderef $have;
  return $have;

};

# ---   *   ---   *   ---
# replace node in hierarchy

sub replace($self,$dst,$src) {

  ($dst,$src)=$self->deref($dst,$src);

  if(Tree->is_valid($src)) {
    $dst->repl($src);

  } else {
    $dst->{value}=$src;

  };

  return;

};

# ---   *   ---   *   ---
# adds new nodes at pos

sub insert($self,$dst,@src) {

  ($dst,@src)=$self->deref($dst,@src);


  my $idex=shift @src;

  map {

    (Tree->is_valid($ARG))
      ? $dst->insertlv($idex,$ARG)
      : $dst->insert($idex,$ARG)
      ;

  } @src;

  return;

};

# ---   *   ---   *   ---
# ^adds new node at end

sub _push($self,$dst,@src) {

  ($dst,@src)=$self->deref($dst,@src);

  map {
    (Tree->is_valid($ARG))
      ? $dst->pushlv($ARG)
      : $dst->inew($ARG)
      ;

  } @src;

  return;

};

# ---   *   ---   *   ---
# move branch to top!

sub merge($self,$dst) {

  $dst = $self->discard($dst);

  my ($anchor,$root)=
    $self->deref(qw(branch root));


  while($anchor->{parent} ne $root) {
    $anchor=$anchor->{parent};

  };

  my $idex=$anchor->{idex};

  ($dst)=$root->insertlv($idex+1,$dst);

  return $dst;

};

# ---   *   ---   *   ---
# ^merge and flatten ;>

sub mergef($self,$dst,$depth=0) {

  $dst=$self->merge($dst);
  $self->flatten($dst,$depth);

  return;

};

# ---   *   ---   *   ---
# replace node with children

sub flatten($self,$dst,$depth=0) {

  $dst=$self->deref($dst);
  $dst->flatten_tree(max_depth=>$depth);

  return;

};

# ---   *   ---   *   ---
# remove yourself!

sub discard($self,$dst) {
  ($dst)=$self->deref($dst);
  return $dst->discard();

};

# ---   *   ---   *   ---
# remove your children!

sub clear($self,$dst) {

  $dst=$self->deref($dst);
  $dst->clear();

  return;

};

# ---   *   ---   *   ---
# declares that a sequence of
# tokens should mutate to a call

sub invoke($self,@args) {


  # get ctx
  my $main = $self->{main};
  my $data = $self->{data};
  my $l1   = $main->{l1};


  # the 'as' in 'invoke as' gets discarded ;>
  shift @args;

  # ^last elem is function body
  my $fn=pop @args;

  # ^the rest is args, parse and stringify
  @args=$self->xstirr(@args);
  my $first=shift @args;


  # add it all to table ;>
  push @{$data->{-invoke}},{

    fn   => $fn,
    re   => $l1->re(WILD=>$first),

    sig  => [map {$l1->re(WILD=>$ARG)} @args],

    data => $self->{data},
    name => join '->',@args,

  };

  return;

};

# ---   *   ---   *   ---
# ^undo

sub banish($self,$data,@args) {

  my $name=join '->',$self->xstirr(@args);

  my $par=$self->{par};
  my $dst=$par->{invoke};

  delete $dst->{$name};

  return;

};

# ---   *   ---   *   ---
# contextual value transform

sub deref($self,@args) {


  # get ctx
  my $main   = $self->{main};
  my $l2     = $main->{l2};
  my $branch = $l2->{branch};
  my $data   = $self->{data};

  my $tab    = {

    branch => $branch,
    expr   => $branch->{parent},
    parent => $branch->{parent}->{parent},
    last   => $branch->{leaves}->[-1],
    root   => $main->{tree},

  };


  # walk values
  map {


    # have attr name?
    if(! index $ARG,'self.') {
      $ARG=substr $ARG,5,length($ARG)-5;
      $ARG=$data->{$ARG};

    # have branch name?
    } elsif(! index $ARG,'lv.') {
      $ARG=substr $ARG,3,length($ARG)-3;
      $ARG=$branch->branch_in(qr{$ARG});

    # have reference?
    } elsif(exists $tab->{$ARG}) {
      $ARG=$tab->{$ARG};

    };


    $ARG;


  } @args;

};

# ---   *   ---   *   ---
# ^transform and stringify

sub xstirr($self,@args) {

  @args=$self->deref(@args);

  map {

    (Tree->is_valid($ARG))

      ? $ARG->to_string(
          join_char=>'.',
          keep_root=>1,

        )

      : $ARG

      ;

  } @args;

};

# ---   *   ---   *   ---
# deref + tree expansion

sub deep_deref($self,@args) {


  # get ctx
  my $par=$self->{par};

  # walk args
  map {


    # expand tokens in a tree
    if(Tree->is_valid($ARG)) {


      my @Q=(@{$ARG->{leaves}});
      while(@Q) {


        # map node to value
        my $nd   = shift @Q;

        my $key  = $par->deref($nd);
        my $have = $self->deref($key);


        # ^replace node with result
        if(Tree->is_valid($have)) {
          $nd->repl($have);

        # ^replace only the string!
        } else {
          $nd->{value}=$have;

        };

        unshift @Q,@{$nd->{leaves}};

      };

      $ARG;


    # plain value, so straight map
    } else {
      $self->deref($ARG);

    };


  } @args;

};

# ---   *   ---   *   ---
# dereferences parsed args
# within a function definition

sub argparse($self,@slurp) {


  # get ctx
  my $meta = $self->{meta};
  my $par  = $self->{par};


  # argument array to value array ;>
  @slurp=$self->deep_deref(@slurp);

  # use signature to identify passed args
  my $tab  = $par->{tab};
  my $case = $meta->{name};
  my $capt = $tab->match($case,\@slurp);

  # ^write them to instance
  $par->deref($capt);

  map {

    $self->{data}->{$ARG} //=
      $capt->{$ARG};

  } keys %$capt;

  return;

};

# ---   *   ---   *   ---
1; # ret
