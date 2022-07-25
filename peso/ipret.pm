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
package peso::ipret;
  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/avtomat/';

  use style;
  use arstd;

  use langdefs::peso;

  use peso::rd;
  use peso::st;

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
      peso::st::regpad(\@names,\@values);

    peso::st::regfmat($data,$names,$values);

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
  my $rd=peso::rd::new_parser(
    lang->peso,$fname,
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

# ---   *   ---   *   ---

};

# ---   *   ---   *   ---
1; # ret