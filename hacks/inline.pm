#!/usr/bin/perl
# ---   *   ---   *   ---
# INLINE
# None of you dared
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

package inline;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use Carp;
  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;
  use Arstd;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';

  use parent 'Lyfil';
  use Shwl;

# ---   *   ---   *   ---
# ROM

  Readonly our $CREATE_SCOPE=>0x01;

# ---   *   ---   *   ---
# global state

  my $TABLE={};
  my $PARENS_RE=shwl::delm(q[(],q[)]);

# ---   *   ---   *   ---

sub decl_args($rd,@args) {

  my $sigil=$rd->{lang}->{sigils};
  my $name=$rd->{lang}->{names};

  my $nd_frame=$rd->{program}->{node};
  my $block=$rd->{curblk};

  my $branch=$block->{tree};
  my $id=$block->{name};
  my $i=0;

# ---   *   ---   *   ---

  for my $argname(@args) {

    $argname=~ s/^($sigil+)//sg;
    my $original=$argname;

    if(!defined ${^CAPTURE[0]}) {

      Arstd::errout(
        "Can't match sigil for var %s\n",

        args=>[$original],
        lvl=>$AR_FATAL,

      );

    };

# ---   *   ---   *   ---

    $argname=~ s/^($name+)//sg;
    if(!defined ${^CAPTURE[0]}) {

      Arstd::errout(
        "Can't match ma,e for var %s\n",

        args=>[$original],
        lvl=>$AR_FATAL,

      );

    };

    $argname=${^CAPTURE[0]};

# ---   *   ---   *   ---

    my $arg=sprintf $shwl::ARG_FMAT,$i;
    my $nd=$nd_frame->nit(

      $branch,
      "my \$inlined_${id}_$argname=$arg;",

      unshift_leaves=>1,

    );

    $i++;

  };

};

# ---   *   ---   *   ---

sub repl_args($re,$order,@args) {

  my %tab;
  my @order=@$order;

# ---   *   ---   *   ---

  for my $node(@args) {

    my $key=$node->{value};
    next if !($key=~ $re);

    $key=${^CAPTURE[0]};

# ---   *   ---   *   ---

    if(!exists $tab{$key}) {
      $tab{$key}=[$node];

# ---   *   ---   *   ---

    } else {
      push @{$tab{$key}},$node;

    };

  };

# ---   *   ---   *   ---

  my $i=0;
  for my $arg(@order) {

    my $key=$arg->{name};

    goto TAIL if !exists$tab{$key};
    my @nodes=@{$tab{$key}};

# ---   *   ---   *   ---

    $key="\\$key";

    for my $node(@nodes) {
      my $str=":__ARG_${i}__:";

      $node->{value}=~ s{

        (?<= \$)${key}\b

      } {\{$str\}}sgx;

      $node->{value}=~ s/${key}\b/$str/sg;

    };

# ---   *   ---   *   ---

TAIL:
    $i++;

  };

};

# ---   *   ---   *   ---

sub rename_args($rd,@args) {

  my $block=$rd->{curblk};
  my $id=$block->{name};

  my $sigil=$rd->{lang}->{sigils};
  my $name=$rd->{lang}->{names};

# ---   *   ---   *   ---

  for my $mention(@args) {
    my $key=$mention->{value};

# ---   *   ---   *   ---

    $key=~ s/^($sigil+)//sg;

    if(!defined ${^CAPTURE[0]}) {
      Arstd::errout(
        "Can't match sigil for var %s\n",

        args=>[$key],
        lvl=>$AR_FATAL,

      );

    };

    my $var_sigil=${^CAPTURE[0]};

# ---   *   ---   *   ---

    $mention->{value}=$var_sigil.
      "inlined_${id}_$key";

  };

};

# ---   *   ---   *   ---

sub process_block($rd,$pkgname) {

  my $block=$rd->{curblk};
  my $branch=$block->{tree};
  my $nd_frame=$rd->{program}->{node};

# ---   *   ---   *   ---
# default strategy is plain paste the code

  $block->{inline_strat}=0;
  my $strat=\$block->{inline_strat};

  $rd->recurse($branch);

# ---   *   ---   *   ---
# find assignment operations

  my ($args_re,$order,@args)=$rd->find_args();
  my %args_asg=$rd->find_asg_ops(@args);

  $block->{argc}=int(@$order);
  $block->{ob_argc}=0;

# ---   *   ---   *   ---
# handle arg data

  for my $arg(@$order) {

    $block->{ob_argc}+=
      !defined $arg->{default};

  };

  $block->{args}=$order;

# ---   *   ---   *   ---
# assignment to args means we
# need to create a separate scope

  my @keys=keys %args_asg;
  if(@keys) {

    $$strat|=$inline::CREATE_SCOPE;
    decl_args($rd,@keys);

    rename_args(

      $rd,
      map {@{$ARG}} values %args_asg

    );

  };

  repl_args($args_re,$order,@args);

# ---   *   ---   *   ---
# handle return values

  my @rets=$branch->branches_in(qr{^return$});

  for my $ret(@rets) {

    if($$strat & $Inline::CREATE_SCOPE) {
      $ret->{value}=$Shwl::RET_STR;

      $nd_frame->nit(
        $ret,$Shwl::ASG_STR,
        unshift_leaves=>1,

      );

# ---   *   ---   *   ---

    } else {

      if($branch->leaf_value(-1) eq q{;}) {
        $branch->pluck($branch->{leaves}->[-1]);

      };

      $ret->flatten_branch();

    };

# ---   *   ---   *   ---

  };

  $rd->replstr($branch);

  $block->{inline_code}=$branch->to_str();
  $rd->tighten_ops(\$block->{inline_code});

  $TABLE->{$pkgname.q{::}.$block->{name}}=$block;

};
# ---   *   ---   *   ---

sub make_table_re() {

  if(exists $TABLE->{re_sbl}) {
    delete $TABLE->{re_sbl};

  };

  if(exists $TABLE->{re_full}) {
    delete $TABLE->{re_full};

  };

  my @names=sort {
    (length $a)<=(length $b)

  } keys %$TABLE;

  if(!@names) {
    Arstd::errout(
      "Empty inlined symbol table\n",
      lvl=>$AR_WARNING,

    );

  };

  my $re_sbl=q{\b(?<name>}.(join q{|},@names).q{)\b};

  my $re_full=$re_sbl.
    q{\s*\(\s* (?<args> .*?) \s*\)\s*};

  $TABLE->{re_full}=qr{$re_full}xs;
  $TABLE->{re_sbl}=qr{$re_sbl}xs;

};

# ---   *   ---   *   ---

sub find_args($branch) {

  state $re=qr{^\s*\(\s*|\s*\)\s*$}x;

  my $out=$NULLSTR;

  if(@{$branch->{leaves}}) {
    $out=$branch->to_string();
    $branch->{leaves}=[];

  } else {

    my $idex=$branch->{idex};
    my $node=$branch->{parent}->{leaves}->[$idex+1];

    $out=$node->{value};
    $branch->{parent}->pluck($node);

  };

  $out=~ s/$re//sg;

  return $out;

};

# ---   *   ---   *   ---

sub find_dst($sigil_re,$branch) {

  my ($dst,$asg)=($NULLSTR,$NULLSTR);

  my $parent=$branch->{parent};
  my $is_decl=$parent->{value}=~
    m/\b(my|our|state)\b/;

  if($is_decl) {
    $is_decl=${^CAPTURE[0]};

    my $dst_nd=$parent->{leaves}->[0];
    my $asg_nd=$parent->{leaves}->[1];

    $dst=$dst_nd->{value};
    $asg=$asg_nd->{value};

    $parent->{value}='#:cut_dst;>';
    $parent->pluck($dst_nd,$asg_nd);

  } else {

    $is_decl=$NULLSTR;
    $dst=$parent->{value};

    if($dst=~ m/^$sigil_re/) {

      $asg=$parent->leaf_value(0);

      $parent->{value}='#:cut_dst;>';
      $parent->pluck($parent->{leaves}->[0]);

    } else {
      $dst=$NULLSTR;

    };

  };

  return ($is_decl,$dst,$asg);

};

# ---   *   ---   *   ---

sub inspect($rd) {

  my $block=$rd->select_block('-ROOT');
  my $tree=$block->{tree};

  $rd->recurse($tree);
  $rd->replstr($tree);

# ---   *   ---   *   ---

#$tree->prich();

  while(

     ( my $full_mention=
       $tree->branch_in($TABLE->{re_full}) )

  || ( my $sbl_mention=
       $tree->branch_in($TABLE->{re_sbl})  )

  ) {

    my ($branch,$re);

    if($full_mention) {
      $branch=$full_mention;
      $re=$TABLE->{re_full};

    } else {
      $branch=$sbl_mention;
      $re=$TABLE->{re_sbl};

    };

# ---   *   ---   *   ---

    $branch->{value}=~ s/$re/#:cut_fn;>/;

    my $id=$+{name};
    my $args=$+{args};

    if(!defined $args) {
      $args=find_args($branch);

    };

    my $block=$TABLE->{$id};
    my $code=$block->{inline_code};

    my @args=solve_args($block,\$code,$args);
    my @dst=solve_dst($rd,$block,$branch);

    apply_strategy(

      $block,
      $branch,
      $code,

      args=>\@args,
      dst=>\@dst,

    );

  };

# ---   *   ---   *   ---

  my $s=$tree->to_string();
  my $out=arstd::tidyup(\$s);

  print "$out\n";
  print eval($out)."\n";

};

# ---   *   ---   *   ---

sub solve_args($block,$code,$args) {

  my @passed_args=();
  my $errme=$NULLSTR;

  if(length $args) {

    @passed_args=split m/\s*,\s*/,$args;

# ---   *   ---   *   ---
# errchk

    if(@passed_args<$block->{ob_argc}) {
      $errme='Insufficient arguments';
      goto ERR;

    } elsif(@passed_args>$block->{argc}) {
      $errme='Too many arguments';
      goto ERR;

    };

# ---   *   ---   *   ---
# put default values

    my $i=0;
    for my $arg(@{$block->{args}}) {

      if(!defined $passed_args[$i]) {
        push @passed_args,$arg->{default};

      };

      $i++;

    };

# ---   *   ---   *   ---
# errchk

  } elsif($block->{argc}) {
    $errme='Insufficient arguments';
    goto ERR;

  };

# ---   *   ---   *   ---
# replace mentions

  my $i=0;
  for my $arg(@passed_args) {

    my $arg_re=sprintf $Shwl::ARG_FMAT,$i;
    $arg_re=qr{$arg_re}x;

    $$code=~ s/$arg_re/$arg/sg;
    $i++;

  };

  return @passed_args;

# ---   *   ---   *   ---
# jump of utter failure

ERR:

  Arstd::errout(
    "$errme for %s\n",

    args=>[$block->{name}],
    lvl=>$AR_FATAL,

  );

};

# ---   *   ---   *   ---

sub solve_dst($rd,$block,$branch) {

  my $line=$branch->{value};
  my $dst_re=$rd->{lang}->{ptr_asg};

  my $decl=$NULLSTR;
  my $dst=$NULLSTR;
  my $asg=$NULLSTR;

# ---   *   ---   *   ---
# inside parens

  if($line=~ s/($dst_re)/#:cut_dst;>/) {

    if($+{is_decl}) {

      $decl=$+{keyw};

      $dst.=$+{sigil};
      $dst.=$+{name};

      $dst.=(defined $+{attrs})
        ? $+{attrs}
        : $NULLSTR
        ;

      $asg=$+{asg_op};

# ---   *   ---   *   ---

    } elsif($+{is_defn}) {

      $dst.=$+{sigil};
      $dst.=$+{name};

      $asg=$+{asg_op};

    } else {

      Arstd::errout(
        'Non-decl and non-defn'.q{ }.
        ' dst for inline sub %s'."\n",

        args=>[$block->{id}],
        lvl=>$AR_FATAL,

      );

    };

# ---   *   ---   *   ---

  } else {
    ($decl,$dst,$asg)=find_dst(

      $rd->{lang}->{sigils},
      $branch

    );

  };

  $branch->{value}=$line;
  return ($decl,$dst,$asg);

};

# ---   *   ---   *   ---

sub apply_strategy($block,$branch,$code,%data) {


  Readonly state $a_keys=>qr{
    (?: for|while)

  }x;

  Readonly state $b_keys=>qr{
    (?: elsif|if|unless)

  }x;

  my $parent=$branch->{parent};
  my $gran=$parent->{parent};

  my $b_idex=$branch->{idex};
  my $prev_lv=$parent->{leaves}->[
    $b_idex-(1*($b_idex>0))

  ];

  my $is_conditional=

     ($branch->{parent}->{value}=~ $b_keys)
  || ($prev_lv->{value}=~ $b_keys)

  ;

  my $is_loop=

     ($branch->{parent}->{value}=~ $a_keys)
  || ($prev_lv->{value}=~ $a_keys)

  ;

  my $tree=$branch->root;
  my $create_scope=
    ($block->{inline_strat} & $CREATE_SCOPE)!=0;

  my @args=@{$data{args}};
  my @dst=@{$data{dst}};

  my $is_decl=length $dst[0];

# ---   *   ---   *   ---

  if($is_conditional || $is_loop) {
    my $dst=join q{ },@dst[0..1];

# ---   *   ---   *   ---

    if($create_scope) {

      my $asg=q{;};
      my $idex=$parent->{idex};

      $gran->insert(
        $idex,
        '#:cut_dst;>#:cut_fn;>'

      );

      my $node=$gran->{leaves}->[$idex];

# ---   *   ---   *   ---

      my $create_ret=!length join $NULLSTR,@dst;

      if($create_ret) {

        $dst=

          '$inlined_'.
          $block->{name}.q{_}.
          $block->{cpyn}++

        ;

        $branch->{value}=~ s/\#\:cut_fn;>/$dst/;

        $dst[1]=$dst;

        $dst='my'.q{ }.$dst;
        $dst[2]='=';

        $is_decl=1;

        $code=~ s/$Shwl::RET_RE/$dst[1]/;

      } else {

        $code=~ s/$Shwl::RET_RE/$dst[1]/;
        $branch->{value}=~ s/\#\:cut_fn;>//;

      };


      $code=~ s/$Shwl::ASG_RE/$dst[2]/;
      $node->{value}=~ s/\#\:cut_fn;>/\{$code\}/;

# ---   *   ---   *   ---

      if($is_decl) {
        $node->{value}=~ s/\#\:cut_dst;>/$dst$asg/;
        $branch->{value}=~ s/\#\:cut_dst;>/$dst[1]/;

      } else {

        $node->{value}=~ s/\#\:cut_dst;>//;
        $branch->{value}=~ s/\#\:cut_dst;>/$dst/;

      };

# ---   *   ---   *   ---

      if($is_loop) {

        $idex=$branch->{idex}+2;

        $parent->insert(
          $idex,
          q[{].$code.q[}]

        );

        $node=$parent->{leaves}->[$idex];

      };

# ---   *   ---   *   ---

    } else {

      my $asg=$dst[2];

      $branch->{value}=~
        s/\#\:cut_fn;>/$code/;

      $branch->{value}=~
        s/\#\:cut_dst;>/$dst[1]$asg/;

    };

# ---   *   ---   *   ---

  } else {

    my $dst=join q{ },@dst[0..1];
    my $asg=$dst[2];

    if($create_scope) {
      my $asg=q{;};

      $code=~ s/$Shwl::RET_RE/$dst[1]/;
      $code=~ s/$Shwl::ASG_RE/$dst[2]/;

      my $fn_nd=
        $tree->branch_in(qr{\#:cut_fn;>}x);

      my $dst_nd=
        $tree->branch_in(qr{\#:cut_dst;>}x);

      $fn_nd->{value}=~
        s/\#\:cut_fn;>/\{$code\}/;

# ---   *   ---   *   ---

      if(defined $dst_nd) {

        if($is_decl) {
          $dst_nd->{value}=~ s/\#\:cut_dst;>/$dst$asg/

        } else {
          $dst_nd->{value}=~ s/\#\:cut_dst;>//;

        };

      };

# ---   *   ---   *   ---

    } else {

      $branch->{value}=~
        s/\#\:cut_fn;>/$code/;

      $branch->{parent}->{value}=~
        s/\#\:cut_dst;>/$dst$asg/;

    };

  };

};

# ---   *   ---   *   ---

#sub code_emit {
#
#  my ($self)=@_;
#
#  for my $fn(@{$self->{data}}) {
#
#    my $str=shwl::STRINGS->{$fn};
#
#    if(!($str=~ $TABLE->{re})) {
#      next;
#
#    };
#
#    my $symname=${^CAPTURE[0]};
#    my $sbl=$TABLE->{$symname};
#
## ---   *   ---   *   ---
## fetch args
#
#    my @args=();
#    if($str=~ m/($PARENS_RE)/s) {
#      @args=split m/,/,${^CAPTURE[0]};
#
#    };
#
## ---   *   ---   *   ---
## expand symbol and insert
#
#    my $code=$sbl->paste(@args);
#    $str=~ s/${symname}$PARENS_RE/$code/;
#
#    shwl::STRINGS->{$fn}=$str;
#
## ---   *   ---   *   ---
#
#  };
#
#};
#
## ---   *   ---   *   ---
#
#sub import {
#
#  my ($pkg,$fname,$lineno)=(caller);
#  my $self=lyfil::nit($fname,$lineno);
#
#  if($self!=$NULL) {
#    $TABLE=shwl::getlibs();
#    filter_add($self);
#
#  };
#
#};
#
## ---   *   ---   *   ---
#
#sub unimport {
#  filter_del();
#
#};
#
## ---   *   ---   *   ---
#
#sub filter {
#
#  my ($self)=@_;
#
#  my ($pkg,$fname,$lineno)=(caller);
#  my $status=filter_read();
#
#  $self->logline(\$_);
#
#  my $matches=shwl::cut(
#    \$self->{chain}->[0]->{raw},
#
#    "INLINE",
#
#    $TABLE->{re},
#
#  );
#
#  push @{$self->{data}},@$matches;
#  return $status;
#
#};

# ---   *   ---   *   ---
1; # ret
