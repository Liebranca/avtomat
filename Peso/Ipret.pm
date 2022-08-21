#!/usr/bin/perl
# ---   *   ---   *   ---
# IPRET
# Interprets peso code for
# later transpiling
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Peso::Ipret;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd;
  use Arstd::Array;
  use Arstd::Hash;
  use Arstd::IO;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang::Peso;

  use Peso::Rd;
  use Peso::St;

# ---   *   ---   *   ---
# ROM

  my $PE_COM_A={ map {$ARG=>1} qw(

    iter

  )};

  my $PE_COM_B={ map {$ARG=>1} qw(

    col

  )};

  my $PARENS_ARGS_RE=qr{

    (\([^\)]*\))\s+

  }x;

  my $CSLIST_ARGS_RE=qr{

    \s*([^,\s]+)\s*,?\s*

  }x;

# ---   *   ---   *   ---

sub args_in_parens($args,$esc,$command) {

  $$esc=~ s/$PARENS_ARGS_RE//xm;
  $$args=${^CAPTURE[0]};

  return ${^CAPTURE[0]} ne $$command;

};

sub args_in_cslist($args,$esc,$command) {

  while($$esc=~ s/$CSLIST_ARGS_RE//xm) {
    push @$args,${^CAPTURE[0]};

  };

  return 1;

};

# ---   *   ---   *   ---

sub pesc_iter($class,$sref,$esc,$args,%O) {

  my $cut=$Shwl::PL_CUT;
  my $cut_re=$Shwl::PL_CUT_RE;

  my %ht=eval("$args;");
  my $run=$esc;

  my $repl=$NULLSTR;

  my $ar_cnt=int(keys %ht);

  my $loop_cond='while(';
  my $loop_head=$NULLSTR;
  my $loop_body='$repl.=eval($run);};';

# ---   *   ---   *   ---

  my $i=0;
  for my $key(keys %ht) {

    my $elem=q[@{].'$ht{'.$key.'}'.q[}];

    $loop_cond.=$elem;

    $i++;
    if($i<$ar_cnt) {
      $loop_cond.=q{&&};

    };

    $loop_head.=q{my $}."$key".q{=}.
      'shift '.$elem.';';

  };

  $loop_cond.=q[) {];

# ---   *   ---   *   ---

  eval($loop_cond.$loop_head.$loop_body);
  $$sref=~ s/${cut}/$repl/s;

};

# ---   *   ---   *   ---

sub pesc_col($class,$sref,$esc,$args,%O) {

  my $cut=$Shwl::PL_CUT;
  my $cut_re=$Shwl::PL_CUT_RE;

  my $gd=$O{gd};

  my $c=$gd->color(map {

    $ARG=hex('0x'.$ARG)

  } @$args);

  $$sref=~ s/${cut}/$c/s;

};

# ---   *   ---   *   ---

sub pesc($s,%O) {

  my $cut=$Shwl::PL_CUT;
  my $cut_re=$Shwl::PL_CUT_RE;

  my $pesc=Lang->Peso->{pesc};

# ---   *   ---   *   ---

  while($s=~ s/$pesc/$cut/sm) {

    my $esc=$+{body};

    if(!($esc=~ s/^([^;\s]+)\s*//)) {

      errout(
        "Empty peso escape '%s'",

        args=>[$esc],
        lvl=>$AR_FATAL,

      );

    };

    my $command=${^CAPTURE[0]};

# ---   *   ---   *   ---

    if(@{lfind($PE_COM_A,[$command])}) {

      my $args=$NULLSTR;

      next if !args_in_parens(
        \$args,\$esc,\$command,

      );

      $command="pesc_$command";

      Peso::Ipret->$command(
        \$s,$esc,$args,%O

      );

# ---   *   ---   *   ---

    } elsif(@{lfind($PE_COM_B,[$command])}) {

      my $args=[];

      next if !args_in_cslist(
        $args,\$esc,\$command,

      );

      $command="pesc_$command";

      Peso::Ipret->$command(
        \$s,$esc,$args,%O

      );

# ---   *   ---   *   ---

    } else {

      my $var=eval(q[$O{].$command.q[}]);
      $s=~ s/${cut}/$var/;

    };

# ---   *   ---   *   ---

  };

  $s=~ s[$cut_re][]sxgm;
  return $s;

};

# ---   *   ---   *   ---

sub ptr_decl($rd,$branch) {

  my $lang=$rd->{lang};

  my $name_re=$lang->{names};
  my $spec_re=$lang->{specifiers}->{re};
  my $separator=$lang->{sep_ops};

  my $stage=0;

  my %attrs=(size=>1);
  my @names=();
  my @values=();

  $rd->group_lists($branch);

# ---   *   ---   *   ---

  while(@{$branch->{leaves}}) {
    my $n=shift @{$branch->{leaves}};

# ---   *   ---   *   ---
# check attrs

    if($stage==0) {

      if($n->{value}=~ m/^\(|\)$/sg) {
        my $mult=$n->{value};
        $mult=~ s/^\(|\)$//sg;

        $attrs{size}=$mult;

      } elsif($n->{value}=~ m/^$spec_re/) {
        $attrs{$n->{value}}=1;

      } else {$stage++};

    };

# ---   *   ---   *   ---
# check name

    if($stage==1) {

      if($n->{value}=~ m{list\:}) {

        push @names,map
          {$ARG->{value}}
          @{$n->{leaves}}

        ;

      } else {
        push @names,$n->{value};

      };

      $stage++;
      next;

    };

# ---   *   ---   *   ---
# get values

    if($stage==2) {

      if($n->{value}=~ m{list\:}) {

        push @values,map
          {$ARG->{value}}
          @{$n->{leaves}}

        ;

      } else {
        push @values,$n->{value};

      };

      $stage++;
      next;

    };

# ---   *   ---   *   ---

  };

  my $data=[];

  { my ($names,$values)=
      Peso::St::regpad(\@names,\@values);

    Peso::St::regfmat($data,$names,$values);

  };

# ---   *   ---   *   ---
# type,attrs,[name,value]

  return $branch->{value},\%attrs,$data;

};

# ---   *   ---   *   ---

sub clan($rd,$tree) {
  my $lang=$rd->{lang};

# ---   *   ---   *   ---
# get writable data blocks

  my @regs=();
  for my $branch(@{$tree->{leaves}}) {
    if(my $lv=$branch->{leaves}->[0]) {

      push @regs,$branch
      if $lv->{value} eq 'reg';

    };

  };

# ---   *   ---   *   ---
# walk the declarations

  my $type_re=$lang->{types}->{re};
  my @entries=();

  for my $reg(@regs) {

    my $name=$reg->branch_in(qr{^reg$});
    $name=$name->leaf_value(0);

    my @decls=$reg->branches_in($type_re);

# ---   *   ---   *   ---
# build array with declaration details

    for my $decl(@decls) {
      my ($type,$attrs,$data)=
        ptr_decl($rd,$decl);

      push @entries,[$type,$attrs,$data];

    };

# ---   *   ---   *   ---
# execute

    $rd->{program}->reg($name,@entries);

  };

};

# ---   *   ---   *   ---

sub run($fname,%args) {

  # defaults
  $args{-f}//=1;

  # parse the code
  my $rd=peso::rd::parse(
    Lang::Peso,$fname,
    %args

  );

# ---   *   ---   *   ---
# post-parse setup stuff

  my $bframe=$rd->{program}->{blk};

  my $blk=$rd->select_block('-ROOT');
  my $tree=$blk->{tree};

  $rd->hier_sort();
  $rd->recurse($tree);

# ---   *   ---   *   ---

  clan($rd,$tree);
  $bframe->resolve_ptrs();

  return $rd;

};

# ---   *   ---   *   ---

sub xpile_c($rd) {

  my $m=$rd->{program};
  my $types=$m->{lang}->{types};
  my $non=$m->{blk}->{non};

# ---   *   ---   *   ---

  my @blocks=($non);
  while(@blocks) {

    my $blk=shift @blocks;
    if($blk->{attrs}!=($O_RD|$O_WR)) {
      goto TAIL;

    };

    $m->{blk}->setscope($blk);

# ---   *   ---   *   ---

    my @elems=();
    my $entries=$blk->{elems_i};

    for my $idex(sort {$a<=>$b} keys %$entries) {

      my @names=@{$entries->{$idex}};
      my $ptr=$m->{ptr}->fetch($names[0]);

      push @elems,[

        $idex,
        $ptr->{type},
        \@names

      ];

    };

# ---   *   ---   *   ---

    my @result=();
    my $cnt=$#elems;

    my ($idex,$type,$names)=@{(pop @elems)};
    $idex=$idex-$blk->{idex_base};
    $idex*=8;

    my $sz=$blk->{size}-$idex;
    my $top=$idex;

    my $elem_sz=$types->{$type}->{size};

    push @result,

      "$type entry$cnt\[".
      int($sz/$elem_sz).
      "]\n";

# ---   *   ---   *   ---

    for my $elem(reverse @elems) {

      $cnt--;

      ($idex,$type,$names)=@$elem;
      $idex=$idex-$blk->{idex_base};
      $idex*=8;

      $sz=$top-$idex;
      $top=$idex;

      $elem_sz=$types->{$type}->{size};

      push @result,

        "$type entry$cnt\[".
        int($sz/$elem_sz).
        "];\n";

    };

# ---   *   ---   *   ---

    print "typedef struct {\n";
    for my $field(reverse @result) {
      print q{ }x2,$field;

    };

    print "\n} $blk->{name};\n";

# ---   *   ---   *   ---

TAIL:
    unshift @blocks,@{$blk->{children}};

  };

};

# ---   *   ---   *   ---
1; # ret
