#!/usr/bin/perl
# ---   *   ---   *   ---
# LIBRE BOILERPASTE
# GENERATED BY AR/AVTOMAT
#
# LICENSED UNDER GNU GPL3
# BE A BRO AND INHERIT
#
# COPYLEFT IBN-3DILA 2022
# ---   *   ---   *   ---

# deps
package test;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/avtomat/';
  use lang;



sub new {

  my %kwargs=@_;
  my %h=(


    -NAME=>(

       exists $kwargs{name}
    && __name_argchk($kwargs{name})

    ) ? $kwargs{name}
      : default_name(),


  );return bless \%h,"test";

};



my $TEST_CACHE={};sub CACHE {
  return $TEST_CACHE;

};


if(!exists CACHE->{-SYMS}) {
  CACHE->{-SYMS}={-KEY=>0};

};


sub __syms_argchk {


### VALUE CHECK
  my $value=shift;
  if( !(sub {return 1;}->($value)) ) {

    print

      "Value '$value' is invalid ".
      "for attr 'syms' ".
      "of class <"."test".">\n";

    exit;

  };return 1;
### VALUE CHECK


};

sub syms() {

  return $TEST_CACHE->{-SYMS};

};

sub __name_argchk {


### VALUE CHECK
  my $value=shift;
  if( !(lang::valid_name($value)) ) {

    print

      "Value '$value' is invalid ".
      "for attr 'name' ".
      "of class <"."test".">\n";

    exit;

  };return 1;
### VALUE CHECK


};

sub name($;$) {

  my $self=shift;
  my $value=shift;

  if(defined $value) {
    __name_argchk($value);
    $self->{-NAME}=$value;

  };return $self->{-NAME};

};

1;
