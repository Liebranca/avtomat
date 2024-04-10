#!/usr/bin/perl
# ---   *   ---   *   ---
# RD CASE
# Keyword maker
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::case;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Storable;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;
  use Arstd::PM;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => sub {

    return {

      main    => undef,
      tab     => {},

      invoke  => [],

    };

  },

  fn_t => 'rd::casefn',

};

# ---   *   ---   *   ---
# parser genesis

sub ready_or_build($self) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $tab  = $self->{tab};

  cload $self->fn_t;


  # the basic keyword from which all
  # others can be built is 'case'
  #
  # we need to define parsing rules
  # for it first, and from these rules,
  # all others should be dynamically built

  my $name  = $l1->tagre(STRING => '.+');
  my $at    = $l1->tagre(SYM    => 'at');
  my $loc   = $l1->tagre(NUM    => '.+');
  my $curly = $l1->tagre(OPERA  => '\{');

  my $sig   = [


    # no location specified
    $self->signew(

      [name => $name],
      [loc  => 0],

      [body => $curly],

    ),


    # location specified
    $self->signew(

      [name => $name],

      $at,

      [loc  => $loc],
      [body => $curly],

    ),

  ];


  # ^ensure all signatures capture or set
  # the same values!
  $self->sigbuild($sig);

  # write to table
  $tab->{case}={
    sig => $sig,
    fn  => \&defproc,

  };

  return;

};

# ---   *   ---   *   ---
# validates signature array

sub sigbuild($self,$ar) {


  # get first definition of default
  # value for attr, across all signatures
  my $defv={};
  map {


    # get keys of all declared attrs
    my $sig  = $ARG;
    my @keys = (
      keys %{$sig->{capt}},
      keys %{$sig->{defv}},

    );

    array_dupop \@keys;


    # get default value if present
    map {

      $defv->{$ARG} //=
        $sig->{defv}->{$ARG}

    } grep {
      exists $sig->{defv}->{$ARG}

    } @keys;


  } @$ar;


  # now add default value to signatures
  # that do not explicitly declare it!
  map {

    my $sig=$ARG;

    map {
      $sig->{defv}->{$ARG}=$defv->{$ARG}

    } grep {
      ! exists $sig->{defv}->{$ARG}
    &&! exists $sig->{capt}->{$ARG}

    } keys %$defv;

  } @$ar;

  return;

};

# ---   *   ---   *   ---
# makes signature

sub signew($self,@sig) {


  # walk pattern array
  my $idex = 0;
  my $capt = {};
  my $defv = {};

  my @seq  = map {

    my ($key,@pat);


    # named field?
    if(is_arrayref $ARG) {

      ($key,@pat)=@$ARG;

      # have capture?
      if(is_qre $pat[0]) {
        $capt->{$key}=$idex;

      # have defval!
      } else {
        $defv->{$key}=$pat[0];
        @pat=();

      };


    # ^nope, match and discard!
    } else {
      @pat=$ARG;

    };


    # give pattern if any
    $idex += int @pat;
    @pat;

  } @sig;


  # give expanded
  return {

    capt => $capt,
    defv => $defv,

    seq  => \@seq

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
# default processing for definitions!

sub defproc($self,$data) {


  # get ctx
  my $main = $self->{main};

  # save state
  my $old    = $main->{branch};
  my $status = $self->sort_tree($data->{body});


  # write to table
  $self->{tab}->{$data->{name}}={
    sig => $self->tree_to_sig($data,$status),
    fn  => $self->tree_to_sub($data,$status),

  };


  # restore and give
  $main->{branch}=$old;

  return;

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
  my $have = undef;


  # declaring attribute?
  if(defined ($have=$l1->is_sym($key))
  && $have eq 'attr') {

    my $name=$l1->is_sym($lv[1]->{value});

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
# reads case signature

sub sigread($self,$sig) {

  my @out=();

  map {


    # unpack expressions to proc
    my @tree=@$ARG;
    my @expr=map {
      [@{$ARG->{leaves}}];

    } @tree;


    # ^get array from which to generate sig
    my @have=map {
      $self->sigread_field(@$ARG)

    } @expr;


    # ^need to expand?
    my @copied = ();
    my $idex   = 0;
    my $total  = 1;

    map {

      my $head=$ARG;
      my $type=$head->{type};


      # handle type combinations
      push @copied,[map {{
        data=>{%$head,type=>$ARG},
        idex=>$idex

      }} @$type];


      $total *= int @$type;
      $idex  ++;

    } @have;


    # ^build ALL combinations!
    my @mat    = ((0) x int @have);
    my $walked = 0;

    while(1) {

      my $end = 0;
      my $i   = 0;

      # fetch from index array
      my @row=map {
        $walked++;
        $copied[$i++]->[$ARG]->{data};

      } @mat;

      # stop if all combinations walked
      $end=$walked == $total;


      # else up the counter ;>
      $mat[0]++;
      map {

        # go to next digit?
        if(! ($mat[$ARG] < @{$copied[$ARG]})) {
          $mat[$ARG+1]++ if $ARG < $#copied;
          $mat[$ARG]=0;

        };

      } 0..$#copied if ! $end;


      # cat and stop when done
      push @out,\@row;
      last if $end;

    };


  } @$sig;


  return @out;

};

# ---   *   ---   *   ---
# ^decomposes signature element!

sub sigread_field($self,@lv) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # first token is name of field
  my $name = shift @lv;
     $name = $l1->is_sym($name->{value});

  # second token is type
  my $type = shift @lv;

  # have list?
  if(defined $l1->is_list($type->{value})) {

    $type=[map {
      $l1->is_sym($ARG->{value})

    } @{$type->{leaves}}];

  # have symbol!
  } else {
    $type=[$l1->is_sym($type->{value})];

  };


  # third is optional value specifier
  my $spec=(@lv)
    ? $l1->detag($lv[0]->{value})
    : '.+'
    ;


  # give descriptor
  return {
    name => $name,
    type => $type,
    spec => $spec,

  };

};

# ---   *   ---   *   ---
# map case tree to signature array

sub tree_to_sig($self,$data,$status) {

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # validate signature
  my $sig=$status->{sig}
  or $main->perr(

    "No signature for "
  . "[ctl]:%s '%s'",

    args=>[$data->{-class},$data->{name}],

  );

  # ^proc
  my @sig=map {

    $self->signew(map {

      [$ARG->{name}=>$l1->tagre(
        uc $ARG->{type} => $ARG->{spec}

      )]

    } @$ARG);

  } $self->sigread($sig);
  $self->sigbuild(\@sig);


  return \@sig;

};

# ---   *   ---   *   ---
# maps attr nodes to perl sub

sub fnread($self,$fn) {

  my $main    = $self->{main};
  my $fn_t    = $self->fn_t;

  my @program = map {

    my @tree=@$ARG;

    map {


      $main->{branch}=$ARG;

      my ($ins,@args)=
        $self->fnread_field($ARG);

      my $ref=$fn_t->fetch($main,$ins);
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
  my $l1   = $main->{l1};
  my @lv   = @{$branch->{leaves}};


  # first token is name of F
  my $name = shift @lv;
     $name = $l1->is_sym($name->{value});

  # ^whatever follows is args!
  my @args=map {
    $self->sigvalue($ARG)

  } @lv;


  return ($name,@args);

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

  # ^proc and generate perl sub
  my @program=$self->fnread($fn);
  $fn=sub ($ice,$idata) {

    map {

      my ($ins,@args) = @$ARG;
      $ins->($ice,$idata,@args);

    } @program;

    return;

  };

  return $fn;

};

# ---   *   ---   *   ---
# entry point

sub parse($self,$keyw,$root) {

  my @new=$self->find($root,keyw=>$keyw);
  map {$self->find($root,keyw=>$ARG)} @new;

  $self->run_invoke($root);

  return;

};

# ---   *   ---   *   ---
# get branches that match

sub find($self,$root,%O) {


  # defaults
  $O{keyw} //= 'case';

  # get ctx
  my $main     = $self->{main};
  my $l1       = $main->{l1};
  my $tab      = $self->{tab};

  # get patterns
  my $keyw_re  = $l1->tagre(SYM=>$O{keyw});
  my $keyw_sig = $tab->{$O{keyw}}->{sig};
  my $keyw_fn  = $tab->{$O{keyw}}->{fn};


  # get all top level branches that
  # begin with keyw. peso v:
  #
  # * "case %keyw at i {...}"
  #
  # ^this is the first pattern we must
  # be able to define without perl!

  my @have=(
    grep {$ARG->{parent} eq $root}
    $root->branches_in($keyw_re)

  );


  # write found to table
  # gives back names of new keywords
  map {


    # make node current
    my $nd   = $ARG;
    my $data = {};

    $main->{branch}=$nd;

    # check signature
    for my $sig(@$keyw_sig) {
      $data=$self->sigchk($nd,$sig);
      last if length $data;

    };


    # all OK, register keyword
    $data->{-class}=$O{keyw};
    $keyw_fn->($self,$data);

    $self->add_invoke($data->{-invoke})
    if $data->{-invoke};

    $nd->discard();
    $data->{name};


  } @have;

};

# ---   *   ---   *   ---
# check node against signature

sub sigchk($self,$nd,$sig) {


  # get signature matches
  my ($pos)=
    $nd->match_sequence(@{$sig->{seq}});


  # args in order?
  if(defined $pos && $pos == 0) {

    my $lv  = $nd->{leaves};
    my $out = $self->sigcapt($lv,$sig,$pos);

    return $out;

  };


  # ^nope!
  return null;

};

# ---   *   ---   *   ---
# captures signature matches!

sub sigcapt($self,$lv,$sig,$pos) {


  # read values from tree
  my %data=map {

    my $key  = $ARG;
    my $idex = $sig->{capt}->{$key}+$pos;

    $key => $self->sigvalue($lv->[$idex]);

  } keys %{$sig->{capt}};


  # set defaults!
  map {

    $data{$ARG} //=
      $sig->{defv}->{$ARG};

  } keys %{$sig->{defv}};

  # give descriptor
  return \%data;

};

# ---   *   ---   *   ---
# ^breaks down capture values ;>

sub sigvalue($self,$nd) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  my $key  = $nd->{value};

  # have annotated value?
  my ($type,$have)=$l1->xlate_tag($key);
  return $nd if ! $type;


  # have string?
  if($type eq 'STRING') {
    return $l1->detag($key);

  # have num?
  } elsif($type=~ qr{^(?:NUM|SYM)}) {
    return $have;


  # have operator?
  } elsif($type eq 'OPERA') {

    if($have eq '{') {
      return $nd;

    } else {
      return $have;

    };


  # have list?
  } elsif($type eq 'LIST') {
    return map {
      $self->sigvalue($ARG)

    } @{$nd->{leaves}};

  # error!
  } else {
    die "unreconized: '$type' at sigvalue";

  };

};

# ---   *   ---   *   ---
# adds a method to be called
# uppon encountering some
# sequence of tokens

sub add_invoke($self,$head) {


  # get ctx
  my $main = $self->{main};

  # save state
  my $old    = $main->{branch};
  my $status = $self->sort_tree($head->{fn});


  # write to method table
  $head->{fn}=
    $self->tree_to_sub($head,$status);

  push @{$self->{invoke}},$head;


  # restore and give
  $main->{branch}=$old;
  return;

};

# ---   *   ---   *   ---
# ^executes

sub run_invoke($self,$root) {


  # get ctx
  my $main=$self->{main};


  # walk cases!
  map {


    # get matches for first token!
    my $head = $ARG;
    my $sig  = $head->{sig};

    my @have = $root->branches_in($sig->[0]);


    # ^make call for each match
    map {

      # use child nodes as args
      my $nd   = $ARG;
      my @args = @{$nd->{leaves}};

      # ^if that's not enough, use
      # sibling nodes
      push @args,$nd->all_fwd()
      if @args < @$sig-1;

      # ^or throw if that's STILL not enough!
      $main->perr(

        "too few arguments for "
      . "[ctl]:%s '%s'",

        args=>['case',$$head->{data}->{name}]

      ) if @args < @$sig-1;


      # validate
      my $i=0;
      my $valid =! int grep {
      ! ($args[$i++]->{value}=~ $ARG)

      } @{$sig}[1..@$sig-1];

      # ^call
      if($valid) {
        $main->{branch}=$nd;
        $head->{fn}->($self,$head->{data});

      };


    } @have;


  } @{$self->{invoke}};

  return;

};

# ---   *   ---   *   ---
1; # ret
