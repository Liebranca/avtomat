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
  my $non=$bframe->{non};

  my $blk=$rd->select_block('-ROOT');
  my $tree=$blk->{tree};

  $rd->hier_sort();
  $rd->recurse($tree);

# ---   *   ---   *   ---

  clan($rd,$tree);

  $bframe->resolve_ptrs();

  $non->prich();
#  $tree->prich();

};

# ---   *   ---   *   ---
1; # ret
