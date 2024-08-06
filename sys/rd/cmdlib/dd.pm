#!/usr/bin/perl
# ---   *   ---   *   ---
# DD
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

package rd::cmdlib::dd;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;

  use Arstd::String;
  use rd::vref;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# pass definitions to cmdlib

sub build($class,$main) {


  # get ctx
  my $mc    = $main->{mc};
  my $flags = $mc->{bk}->{flags};

  # generate flag types
  wm_cmdsub $main,'flag-type' => q(
    qlist src

  ) => @{$flags->list};


  # give table
  return rd::cmd::MAKE::build($class,$main);

};

# ---   *   ---   *   ---
# parse and collapse flag list

sub flag_type($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # proc list
  $self->rcollapse_list($branch,sub {

      # mutate into another command
      $branch->{value}=
        $l1->tag(CMD=>'flag-type')
      . "$branch->{cmdkey}"
      ;


      return;

  });

};

# ---   *   ---   *   ---
# read segment decl

sub seg_type($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # clean name
  my $lv   = $branch->{leaves};
  my $name = $lv->[0]->{value};
     $name = $l1->xlate($name)->{spec};


  # prepare branch for ipret
  my $type=$branch->{cmdkey};

  $branch->{vref}=rd::vref->new(
    type => 'SYM',
    spec => $name,
    data => $type,

  );

  $branch->clear();


  # need to mutate?
  $branch->{value}=
    $l1->tag(CMD=>'seg-type')
  . "$type"

  if $type ne 'seg-type';


  # set preproc namespace!
  my $scope = $main->{scope};
  my @path  = $scope->ances_list(root=>0);

  pop @path if @path > 1;


  $main->{inner}->force_get(@path,$name);
  $main->{scope}=$main->{inner}->{'*fetch'};


  return;

};

# ---   *   ---   *   ---
# find children nodes of a
# hierarchical block

sub mkhier($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # get nesting pattern
  my $key={
    clan  => [qw(clan)],
    struc => [qw(clan struc proc)],
    proc  => [qw(clan struc proc)],

  }->{$branch->{cmdkey}};


  # get leaves
  my $re=$l1->re(CMD=>(join '|',@$key));
  my @lv=$branch->{parent}->match_up_to(

    $re,

    inclusive => 0,
    deep      => 1,

  );

  $branch->pushlv(@lv);


  return;

};

# ---   *   ---   *   ---
# make/swap addressing space

sub clan($self,$branch) {


  # get ctx
  my $frame = $self->{frame};
  my $main  = $frame->{main};

  # fetch name
  my $cmd=$frame->fetch('csume-token');
  $cmd->csume_token($branch);


  # ^set as namespace
  my $name=$branch->{vref}->{spec};

  $main->{inner}->force_get($name);
  $main->{scope}=$main->{inner}->{'*fetch'};


  # parent nodes and give
  $self->mkhier($branch);
  return;

};

# ---   *   ---   *   ---
# ^make type dummy for structure

sub _struc($self,$branch) {


  # get ctx
  my $frame = $self->{frame};
  my $main  = $frame->{main};
  my $l1    = $main->{l1};
  my $l2    = $main->{l2};

  # fetch name
  my $cmd=$frame->fetch('csume-token');
  $cmd->csume_token($branch);


  # make dummy typedecl
  #
  # this is done so mentions of this structure
  # are themselves recognized as a type
  # and processed accordingly
  #
  # the actual definition is done later!

  my $name=$branch->{vref}->{spec};
  my $clan=$main->{scope}->{value};

  my $full="$clan\::$name";

  struc $full=>q[tiny dummy];


  # make command
  $cmd=$frame->new(

    lis   => $full,

    fn    => \&{"rd::cmd::MAKE::wrapper"},
    pkg   => St::cpkg,

    wraps => 'data-type',
    sig   => ['qlist any'],

  );

  # ^recurse for mentions of this type
  my $par = $branch->{parent}->{parent};
  my $re  = $l1->re(SYM=>"$full|$name");

  my @lv  = $par->branches_in($re);
  my $old = $l2->{branch};


  map {

    $ARG->{value} = $l1->tag(CMD=>$full);
    $l2->{branch} = $ARG;

    $l2->cmd();
    $cmd->{key}->{fn}->($cmd,$ARG);

  } @lv;


  $l2->{branch}=$old;


  # parent nodes and give
  $self->mkhier($branch);
  return;

};

# ---   *   ---   *   ---
# ^make F

sub proc($self,$branch) {


  # get ctx
  my $frame = $self->{frame};
  my $main  = $frame->{main};
  my $l1    = $main->{l1};
  my $l2    = $main->{l2};

  # fetch name
  my $cmd=$frame->fetch('csume-token');
  $cmd->csume_token($branch);


  # parent nodes and give
  $self->mkhier($branch);
  return;

};

# ---   *   ---   *   ---
# entry point for (exprtop)[*type] (values)
#
# not called directly, but rather
# by mutation of [*type] (see: type_parse)
#
# reads a data declaration!

sub data_decl($self,$branch) {


  # get ctx
  my $main  = $self->{frame}->{main};
  my $l1    = $main->{l1};
  my $l2    = $main->{l2};

  my $mc    = $main->{mc};
  my $scope = $mc->{scope};


  # get decl type
  my ($type)=rd::vref->is_valid(
    TYPE=>$branch->{vref}

  );

  $type=typefet $type if defined $type;


  # absolute corner case:
  # ANONYMOUS DECLARATIONS

  my $lv    = $branch->{leaves};
  my $first = $lv->[0];

  # detect lack of name list!
  if(@$lv == 1) {

    my ($have,$dst);

    if($l1->typechk(LIST=>$first->{value})) {
      $dst=$first->{leaves}->[0];


    } elsif(@{$first->{leaves}}) {
      $dst=$first;

    };


    if($dst) {

      # get first value
      $have=$l1->xlate(
        $dst->{value}

      );

      # ^ensure first value is a '?' QUEST
      $main->perr(
        "use a (?) question mark "
      . 'for anonymous declarations'

      ) if ! $have

      || $have->{type} ne 'OPR'
      || $have->{spec} ne '?';


      # ^add QUEST as name of block ;>
      $dst->flatten_branch();
      $branch->insert(0,$l1->tag(SYM=>'?'));

    };

  };


  # get [name=>value] arrays
  my ($name,$voa,$value)=map {

    ($l1->typechk(LIST=>$ARG->{value}))
      ? $ARG->{leaves}
      : [$ARG]
      ;

  } @{$branch->{leaves}};


  # have array decl?
  if(defined $voa) {


    my $have=$l1->xlate($voa->[0]->{value});


    # have array?
    if($have->{type} eq 'SCP'
    && $have->{spec} eq '[') {
      ($voa) = $voa->[0]->leafless_values();
      $voa   = $l1->xlate($voa)->{spec};

    # ^nope!
    } else {
      $value = $voa;
      $voa   = undef;

    };

  };


  # apply conversions
  $value  //= [];
  @$value   = map {


    # unpack
    my $have=$l1->xlate($ARG->{value});


    # string to bytes?
    if( $have->{type} eq 'STR'
    &&! Type->is_str($type) ) {


      # non-ascii encodings are a mess,
      # and so we're not in a hurry to
      # support them ;>

      $main->perr(
        'unsupported string width '
      . 'to non-string type conversion'

      ) if $type->{sizeof} > 1;


      # convert escape characters
      charcon \$have->{data};

      # ^then convert regular ones!
      $ARG->{value}=[
        map   {ord $ARG}
        split null,$have->{data}

      ];


    };


    $ARG;

  } @$value;


  # get [name=>value] array
  my $idex = 0;
  my @list = map {


    # ensure default value for each name
    $value->[$idex] //= $branch->inew(
      $l1->tag('NUM'=>0x00)

    );

    # get symbol name
    my $n=$ARG->{value};
       $n=$l1->untag($n)->{spec};

    # give [name=>value] and go next
    my $v=$value->[$idex++];
    [$n=>$v];


  } @$name;


  if(@list < @$value) {

    my $idex = int @$name;
    my $tail = ($idex)*2;

    push @list,
    map {['?'=>$ARG]}

    @$value[$idex..@$value-1];

  };


  # have array decl?
  if(defined $voa) {

    my @array=map {

      if(! defined $ARG) {
        $branch->inew($l1->tag('NUM'=>0x00));

      } else {
        $ARG->[1];

      };

    } @list[0..$voa-1];

    @list=[$list[0]->[0],\@array];

  };


  # prepare branch for ipret
  my $vref=$branch->{vref};

  $vref->{type} = 'DECL';
  $vref->{spec} = $type;
  $vref->{data} = \@list;

  $branch->clear();


  return;

};

# ---   *   ---   *   ---
# collapses width/specifier list
#
# mutates node:
#
# * (? exprbeg) [*type] -> [*data-decl]
# * (! exprbeg) [*type] -> [Ttype]

sub data_type($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};


  # rwalk specifier list
  return $self->rcollapse_list($branch,sub {


    # get hashref from flags
    # save it to branch
    my $vref=$branch->{vref};

    my @list=$vref->read_values('spec');
    my $type=$self->type_decode(@list);

    $vref->{type}='TYPE';
    $vref->{spec}=$type;


    # first token in expression?
    if($l2->is_exprtop($branch)) {


      # mutate into another command
      $branch->{value}=
        $l1->tag(CMD=>'data-decl')
      . "$type->{name}"
      ;


      $branch->{cmdkey}=undef;
      return $branch;


    # ^nope, last or middle
    } else {


      # look for next node!
      my $par    = $branch->{parent};
      my $anchor = $branch;
      my $ok     = 0;


      while(defined (
        $anchor=$anchor->next_leaf()

      )) {


        # stop at first non-list
        my $have  = $l1->xlate($anchor->{value});
        my $ahead = undef;

        if($have->{type} ne 'LIST') {

          $anchor->{vref} //= rd::vref->new();
          $anchor->{vref}->add({
            type=>'TYPE',
            spec=>$type,

          });

          $ok=1;
          last;

        };

      };


      # throw if nothing found
      $main->perr("redundant type specifier")
      if ! $ok;


      # merging ([LIST],type X) lists?
      if($branch eq $par->{leaves}->[-1]
      && $l1->typechk(LIST=>$par->{value})) {

        my $tail=$anchor->{parent};

        # have (type X,type Y) ?
        if($l1->typechk(LIST=>$tail->{value})) {
          $par->pushlv(@{$tail->{leaves}});
          $tail->discard();

        # ^nope, plain ;>
        } else {
          $par->pushlv($anchor);

        };


      };


      $branch->discard();
      return;

    };

  });

};

# ---   *   ---   *   ---
# ^fetch/errme

sub type_decode($self,@src) {

  # get type hashref from flags array
  my $main = $self->{frame}->{main};
  my $type = typefet @src;

  # ^catch invalid
  $main->perr(

    "invalid type '%s'",
    args=>[join ' ',@src],

  ) if ! defined $type;


  return $type;

};

# ---   *   ---   *   ---
# add entry points

cmdsub 'flag-type' => q(qlist src) => \&flag_type;
cmdsub 'seg-type'  => q(sym type)  => \&seg_type;


priority 2 => cmdsub 'clan' => q(
  sym name

) => \&clan;

priority 2 => cmdsub 'struc' => q(
  sym name

) => \&_struc;

priority 2 => cmdsub 'proc' => q(
  sym name

) => \&proc;


cmdsub 'data-decl' => q(
  qlist name;
  qlist value_or_size;
  qlist value=();

) => \&data_decl;

cmdsub 'data-type' => q(
  qlist any;

) => \&data_type;

w_cmdsub 'seg-type' =>q(
  sym type

) => qw(rom ram exe);

w_cmdsub 'data-type' => q(
  qlist any

) => @{Type::MAKE->ALL_FLAGS};

w_cmdsub 'csume-token' => q(
  any any;

) => qw(
  blk

);

w_cmdsub 'csume-list-mut' => q(
  any input;
  any value=0;

) => qw(io in out);

# ---   *   ---   *   ---
1; # ret
