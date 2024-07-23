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

  our $VERSION = v0.00.8;#a
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
# ^~

sub _struc($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};


  # get struc name
  $branch->{vref}->{type}='rom';
  $branch->{vref}->{name}=$l1->xlate(
    $branch->{vref}->{name}

  )->{spec};


  # generate new ROM block
  my $out=$self->seg_type($branch);
  my $seg=$mc->{segtop};

  # ^set attrs and give step F
  $seg->{virtual}=1;

  return $out;

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
  return $out;

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
    if($ptr_t &&! is_hashref $x) {

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

        my $blk=$mc->{blktop};
        my ($xname,@xpath)=$blk->fullpath;


        # shorten path!
        my @cur=@{$mc->{path}};
        my @old=grep {
          $xpath[$ARG] eq $mc->{path}->[$ARG]

        } 0..$#cur;

        if(@old == @cur) {
          @xpath=@xpath[@old..$#xpath];

        };

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


    # making tmp var for proc?
    if($exe) {

      my $proc = $hier->{p3ptr}->{vref};
         $proc = $proc->{data};

      my $tmp  = $proc->chkvar($oldname,-1);

      $tmp->{defv}=$x;

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
# add entry points

cmdsub 'flag-type' => q(
  qlist src;

) => \&flag_type;

cmdsub 'seg-type' => q() => \&seg_type;
cmdsub 'clan' => q() => \&clan;
cmdsub 'data-decl' => q() => \&data_decl;
cmdsub 'struc' => q() => \&_struc;

# ---   *   ---   *   ---
1; # ret
