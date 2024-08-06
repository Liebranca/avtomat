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

package ipret::cmdlib::dd;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;

  use rd::vref;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'ipret::cmd';
  BEGIN {ipret::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# shorthand: fetch flag table

sub flagtab($self) {

  my $main  = $self->{frame}->{main};
  my $mc    = $main->{mc};

  my $flags = $mc->{bk}->{flags};


  return $flags->ivtab();

};

# ---   *   ---   *   ---
# set/unset object flags

sub flag_type($self,$branch) {


  # get ctx
  my $main  = $self->{frame}->{main};

  my $tab   = $self->flagtab;
  my $flags = $branch->{vref};


  # get result of child branch
  my $ahead = $branch->next_leaf;
  my $obj   = $ahead->{vref};

  $branch->prich(),$main->perr(
    'cannot apply flags -- '
  . 'missing vref or result'

  ) if ! defined $obj
    || ! defined $obj->{res};

  $obj=$obj->{res};


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

      my $have=(length ref $obj)
        ? ref $obj : 'plain' ;

      $main->perr(
        "'%s' is invalid for <%s>",
        args=>[$ARG,$have]

      );

    };


  } $flags->read_values('spec');

  $branch->flatten_branch();

  return 1;

};

# ---   *   ---   *   ---
# step on segment

sub seg_type($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};
  my $ISA  = $mc->{ISA};
  my $enc  = $main->{encoder};

  # get segment name and type
  my $vref = $branch->{vref};
  my $name = $vref->{spec};
  my $type = $vref->{data};


  # scoping or making new?
  my $mem  = $mc->{cas};
  my $have = $mem->haslv($name);

  # ^making new, decl and set flags
  if(! $have) {

    $have=$mc->mkseg($type=>$name);
    $enc->binreq(

      $branch,[

        $ISA->align_t,

        'seg-decl',

        { id        => [$have->fullpath],

          type      => 'seg-decl',
          data      => $type,

        },

      ],

    );

    $have->{p3ptr}=$branch;

  };


  # make current and give
  my $out=sub {$mc->setseg($have);$have};
  $vref->{res}=$have;

  return $out;

};

# ---   *   ---   *   ---
# template:
#
# * prepend segment declaration
#   to current branch

sub segpre($self,$branch,$type,$name=null) {


  # get ctx
  my $frame = $self->{frame};
  my $main  = $frame->{main};
  my $mc    = $main->{mc};
  my $l1    = $main->{l1};


  # locate expression
  my $anchor = $branch;
#     $anchor = $anchor->{parent};
#
#  while $anchor->{parent}
#  &&    $anchor->{parent} ne $main->{tree};


  # get segment type
  $type={
    'executable' => 'exe',
    'readable'   => 'rom',
    'writeable'  => 'ram',

  }->{$type};

  # ^make segment node
  my ($nd) = $anchor->{parent}->insert(
    $anchor->{idex},

    $l1->tag(CMD=>'seg-type')
  . $type

  );


  $nd->{vref}=rd::vref->new(

    type => 'SYM',
    spec => (length $name)
      ? $name
      : $mc->{cas}->mklabel()
      ,


    data => $type,

  );


  # make segment and give
  $self->seg_type($nd);
  return;

};

# ---   *   ---   *   ---
# ^conditionally ;>

sub csegpre($self,$branch,@flags) {


  # get ctx
  my $frame = $self->{frame};
  my $main  = $frame->{main};
  my $mc    = $main->{mc};

  # ensure segment of the right type
  my $top = $mc->{segtop};
  my $ok  = @flags == grep {$top->{$ARG}} @flags;

  $ok &=~ ($top eq $mc->{cas});


  # no deal? then make new segment!
  $self->segpre($branch,shift @flags)
  if ! $ok;


  return;

};

# ---   *   ---   *   ---
# template:
#
# * if the current segment type
#   does not match flags, then
#   prepend one that does
#
# * slap a new label on it

sub csegpre_blk($self,$branch,@flags) {

  # get ctx
  my $main=$self->{frame}->{main};

  # ensure segment
  $self->csegpre($branch,@flags);

  # make label
  return $self->blk($branch);

};

# ---   *   ---   *   ---
# make/swap addressing space

sub clan($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};


  # lookup name
  my $name = $branch->{vref}->{spec};
  my $have = $mc->{astab}->{$name};

  # ^make new?
  $have=$mc->astab_push($name)
  if ! defined $have;


  # set and return setter!
  my $out=sub {

    my @path=split $mc->{pathsep},$name;
    $mc->{cas}=$mc->{astab}->{$name};

    $mc->setseg($mc->{cas});
    $mc->{cas};

  };


  $out->();
  $branch->{value} .= $name;

  return $out;

};

# ---   *   ---   *   ---
# template: begin hierarchical block

sub mkhier($self,$branch) {


  # get ctx
  my $main  = $self->{frame}->{main};
  my $mc    = $main->{mc};

  my $l1    = $main->{l1};
  my $vref  = $branch->{vref};


  # new block closes last!
  if(defined $mc->{hiertop}) {

    my $blk=$mc->{hiertop}->{p3ptr};
       $blk=$blk->{vref}->{data};

    $blk->ribbon();
    $mc->{hiertop}=undef;

  };


  # get type of hierarchical
  my $type = $branch->{cmdkey};
  my $tab  = {
    proc  => ['executable'],
    struc => ['readable'],

  };

  my $meta = $tab->{$type}
  or $main->perr(

    "invalid hierarchical '%s'",
    args=>[$type],

  );


  # generate segment and block
  my $fn=$self->csegpre_blk(
    $branch,$meta->[0]

  );


  # set hierarchical anchor!
  my $old=$fn;

  $fn=sub {
    my $have=$old->();
    $mc->{hiertop}=$have;

    return $have;

  };


  # make object representing block
  my $ptr = $fn->();

  $tab  = \$branch->{vref};
  $$tab = rd::vref->new(

    type => 'HIER',
    spec => $type,

    data => $mc->mkhier(
      type=>$type,
      node=>$branch,
      name=>$vref->{res}->{label},

    ),

    res  => $vref->{res},

  );


  # scope to this block
  my ($name,@path)=$ptr->fullpath;
  $mc->scope(@path,$name);


  $branch->{value} .= $name;
  return ($fn,$ptr);

};

# ---   *   ---   *   ---
# make new structure

sub _struc($self,$branch) {
  my ($fn,$ptr)=$self->mkhier($branch);
  return $fn;

};

# ---   *   ---   *   ---
# make new process

sub proc($self,$branch) {
  my ($fn,$ptr)=$self->mkhier($branch);
  return $fn;

};

# ---   *   ---   *   ---
# a label with extra steps

sub blk($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};
  my $enc  = $main->{encoder};

  my $ISA  = $mc->{ISA};
  my $top  = $mc->{segtop};
  my $hier = $mc->{hiertop};
  my $vref = $branch->{vref};


  # get name of symbol
  my $name = $vref->{spec};

  my @xp   = $top->{value};
  my @path = $top->ances_list;

  if(defined $hier && %$hier) {

    my ($par)=$hier->fullpath;

    push @path,$par;
    push @xp,$par;

  };


  my $full=join '::',@xp,$name;


  # make fake ptr
  my $align_t=$ISA->align_t;
  $mc->{cas}->brkfit($align_t->{sizeof});

  my $ptr=$mc->{cas}->lvalue(

    0x00,

    type  => $align_t,
    label => $full,

  );

  $ptr->{ptr_t}      = $align_t;
  $ptr->{addr}       = $mc->{cas}->{ptr};
  $ptr->{chan}       = $top->{iced};

  $mc->{cas}->{ptr} += $align_t->{sizeof};
  $ptr->{p3ptr}      = $branch;


  # add reference to current segment!
  my $alt=$top->{inner};
  $alt->force_set($ptr,$name);

  $alt->{'*fetch'}->{mem}=$ptr;
  $top->route_anon_ptr($ptr);


  # ^schedule for update ;>
  my $fn   = (ref $main) . '::cpos';
     $fn   = \&$fn;


  $enc->binreq(

    $branch,[

      $align_t,

      'data-decl',

      { id        => [$name,@path],

        type      => 'sym-decl',

        data      => $fn,
        data_args => [$main],

      },

    ],

  );


  # reset and give
  $fn=sub {$mc->{blktop}=$ptr;$ptr};

  $vref->{res}=$ptr;
  $fn->();

  return $fn;

};

# ---   *   ---   *   ---
# reserve memory and solve values
# re-run if not all values solved!

sub data_decl($self,$branch) {


  # get ctx
  my $main  = $self->{frame}->{main};
  my $mc    = $main->{mc};
  my $l1    = $main->{l1};
  my $enc   = $main->{encoder};
  my $eng   = $main->{engine};

  my $scope = $mc->{scope};
  my $path  = $mc->{path};


  # get pending values
  my $vref = $branch->{vref};
  my $type = $vref->{spec};
  my $list = $vref->{data};

  my $out  = $vref->{res} //= [];

  # are we inside a process?
  my $seg  = $mc->{segtop};
  my $hier = $mc->{hiertop};

  my $exe  = $seg->{executable};


  # walk values pending resolution
  my @have = map {


    # unpack
    my ($name,$value)=@$ARG;


    # *attempt* solving
    my ($x,$have)=
      $eng->value_flatten($value);


    # have ptr?
    my $ptr_t = undef;

    # ^sanity check
    my $ptrcls   = $mc->{bk}->{ptr};
    my $have_ptr = $ptrcls->is_valid($x);
    my $isptr    = Type->is_ptr($type);

    if($have_ptr &&! $isptr) {

      $main->perr(

        "'%s' is not a pointer type",
        args=>[$type->{name}]

      );


    # ^yes ptr!
    } elsif($isptr &&! Type->is_str($type)) {
      $ptr_t=$type;

    };


    # catch string datatype mismatch
    if($ptr_t && $have &&! is_hashref $x) {

      $main->perr(

        q[have non-string datatype ]
      . q[[err]:%s for string '%s'],

        args=>[$type->{name},$x],

      );

    };


    # separate datatype from pointer width
    $type=($ptr_t && $x)
      ? $x->{type}
      : $type
      ;

    $ptr_t=typefet $ptr_t if $ptr_t;


    # assume declaration on first pass
    my $oldname = $name;
    my $sym     = undef;

    if(! $main->{pass}) {


      # get current block + symbol name
      if($mc->{blktop}) {

        my $blk  = $mc->{blktop};
        my $root = $mc->{cas}->{inner};

        my ($xname,@xpath)=$blk->fullpath;


        shift @xpath

        if $xpath[0]
        && $xpath[0] eq $root->{value};

        $name=join '::',@xpath,$xname,$name;

      };


      # guard for redeclaration... and declare ;>
      $main->throw_redecl('value',$name)
      if $name ne '?' && $scope->has($name);

      $sym=$mc->decl($type,$name,$x);


      # update...
      my ($xname,@xpath)=$sym->fullpath;

      $ARG->[0] = $xname;
      $type     = ($ptr_t)
        ? $sym->{ptr_t}
        : $sym->{type}
        ;


      # make reasm params
      push @$out,{

        id   => [$xname,@xpath],

        type => 'sym-decl',
        data => $value,

      };


    # ^else we're retrying value resolution
    } elsif($have) {
      my $ref=$mc->valid_psearch($name,@$path);
      $sym=$$ref;

    };


    # overwrite meta
    $sym->{type}  = $type;
    $sym->{ptr_t} = $ptr_t;

    $sym->store($x,deref=>0);


    # making entry on hierarchical?
    if(defined $hier) {

      my $blk = $hier->{p3ptr}->{vref};
         $blk = $blk->{data};

      my $tmp = $blk->chkvar($oldname,-1);

      $tmp->{defv}=($have) ? $x : undef ;

    };


    # give unsolved!
    (! defined $have) ? $ARG : () ;

  } @$list;


  # wait for next pass if values pending
  if(@have) {
    @$list=@have;
    return $branch;

  # ^else save reasm params
  } else {

    $enc->binreq(

      $branch,[

        $type,
        'data-decl',

        @$out

      ],

    ) if ! $exe;

    return;

  };

};

# ---   *   ---   *   ---
# decls inputs and outputs to a process

sub io($self,$branch) {


  # get ctx
  my $frame = $self->{frame};
  my $main  = $frame->{main};
  my $l1    = $main->{l1};
  my $mc    = $main->{mc};
  my $vref  = $branch->{vref};
  my $anima = $mc->{anima};


  # get process
  my $hier = $mc->{hiertop};
  my $tab  = $hier->{p3ptr}->{vref};

  my $dst  = $tab->{data};


  # unpack args
  my ($type,$sym,$value)=$vref->flatten();


  # alloc and give
  $dst->addio(
    $branch->{cmdkey},
    $sym->{spec},

  );


  # add var dummy to namespace
  $value=(defined $value)

    ? $l1->tag(
        $value->{type},
        $value->{spec},

      ) . $value->{data}

    : $l1->tag(NUM=>0)
    ;

  $vref->{spec} = typefet $type->{spec};
  $vref->{data} = [[$sym->{spec}=>$value]];


  # mutate into decl and give
  $branch->{value}=$l1->tag(
    CMD=>'data-decl'

  ) . $branch->{cmdkey};


  return $self->data_decl($branch);

};

# ---   *   ---   *   ---
# add entry points

cmdsub 'flag-type' => q(
  qlist src;

) => \&flag_type;

cmdsub   'seg-type'   => q() => \&seg_type;

cmdsub   'clan'       => q() => \&clan;
cmdsub   'struc'      => q() => \&_struc;
cmdsub   'proc'       => q() => \&proc;
cmdsub   'blk'        => q() => \&blk;

cmdsub   'data-decl'  => q() => \&data_decl;

cmdsub   'io'         => q() => \&io;
w_cmdsub 'io'         => q() => qw(in out);

# ---   *   ---   *   ---
1; # ret
