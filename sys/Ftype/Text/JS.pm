#!/usr/bin/perl
# ---   *   ---   *   ---
# JAVASCRIPT
# It's OK
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text::JS;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);
  use parent 'Ftype::Text';

  use Arstd::strtok qw(strtok unstrtok);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v1.00.2';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# make ice

sub classattr {return {
  name  => 'JS',
  ext   => '\.js$',
  hed   => '#!.*node',

  mag   => 'JavaScript script',
  com   => '//',
  lcom  => '//',

  specifier=>[qw(
    async await export
  )],

  intrinsic=>[qw(
    extends typeof void
    new delete in with
  )],

  directive=>[qw(
    import function class
  )],

  fctl=>[qw(
    each of yield finally

    if else for while do switch
    case default try throw catch
    break continue return
  )],

  resname=>[qw(
    true false null undefined this
    var let const
  )],
}};


# ---   *   ---   *   ---
# syntax definitions for strtok

sub strtok_syx {
  return [
    # comments
    Arstd::seq::com()->{cline},
    Arstd::seq::com()->{cmulti},

    # strings
    Arstd::seq::str()->{squote},
    Arstd::seq::str()->{dquote},
    backtick_seq(),

    # vanilla Javascript doesn't have a
    # preprocessor (to my knowledge), but
    # i already have it implemented, so why not?
    Arstd::seq::pproc()->{c},
  ];
};


# ---   *   ---   *   ---
# ^ we add in this bit to ensure that
#   template literals can be tokenized
#   whenever there's a `${...}` placeholder
#   within them, as those expressions can
#   contain a nested literal

sub backtick_seq {
  return {
    %{Arstd::seq::str()->{backtick}},
    inner=>[Arstd::seq::delim()->{curly}],
  },
};


# ---   *   ---   *   ---
# effectively implements "public" :D

sub package_close {
  my ($class,$dst,$sref,$name,$flg)=@_;

  # generate footer with symbol data
  my $sym   = symrd($dst,$sref);
  my @allow = grep {
    ! ($ARG->{flg}=~ qr{\bprivate\b})

  } @$sym;
  my @pub=(! $flg->{public})
    ? grep {
        ($ARG->{flg}=~ qr{\bpublic\b})

    } @allow : @allow ;

  my $pkg=join("\n",
    map {"  $ARG->{name},"} @allow
  );
  my $pub=join("\n",
    map {"window.$ARG->{name}=$ARG->{name};"} @pub
  );
  # ^give back the generated footer!
  return (
    qq[window["/YESPKG"].push("$name");],
    qq[window["$name"]={]
      . (! is_null($pkg) ? "\n$pkg\n" : null )
    . "};",
    $pub,
  );
};


# ---   *   ---   *   ---
# grabs symbols from codestring

sub symrd {
  my ($strar,$sref)=@_;

  # tokenize the code so that only top-level
  # symbols remain visible!
  #
  # saves us from writing a full-blown parser
  # just for this bit ^^
  my ($lang,$syx)=Ftype::getlang(__PACKAGE__);
  $syx=[
    @$syx,
    Arstd::seq::delim()->{curly},
  ];
  unstrtok($$sref,$strar,"vpproc");
  strtok($strar,$$sref,syx=>$syx);

  # grab each symbol;
  # we wrap each visited one with " :: "
  # so as to make this simpler...
  my $re  = sym_re();
  my $sym = [];
  while($$sref=~ s[$re][ :: $+{pure} :: ]) {
    push @$sym,{
      flg  => $+{flg} // null,
      name => $+{name},
      type => $+{type},
      post => $+{post} // null,
    };
  };
  # ^remove the wraps!
  $re=qr{\h::\h};
  $$sref=~ s[$re][]sxmg;

  # give symbols
  return $sym;
};


# ---   *   ---   *   ---
# ^for symbol detection

sub sym_re {
  my ($pre)=@_;

  return qr{(?<! \h::\h) (?<full>
    (?<flg> (?:
      public
    | private)+ \s+
    )*

    (?<pure>
      (?<type> (?:
        const
      | function
      | async \s+ function
      )) \s+

      (?<name> [[:alnum:]_]+)\s*
      (?<post> [^\;]*?;)
    )

  ) (?! \h::\h)}x;
};


# ---   *   ---   *   ---
1; # ret
