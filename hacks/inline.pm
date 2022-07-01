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

  use lib $ENV{'ARPATH'}.'/lib/hacks/';
  use shadowlib;

  use Filter::Util::Call;
  our $TABLE={};

# ---   *   ---   *   ---

sub import {

  $TABLE=shadowlib::take;
  filter_add(bless []);
};

# ---   *   ---   *   ---

sub unimport {
  filter_del();

};

# ---   *   ---   *   ---

sub filter {

  my ($self)=@_;

  my $caller=caller;
  my $status=filter_read();

# ---   *   ---   *   ---
# look for symbols

  my $s=$_;
  while($s=~ $TABLE->{re}) {

    my $symname=${^CAPTURE[0]};
    my $sbl=$TABLE->{$symname};

# ---   *   ---   *   ---
# fetch args

    my @args=();
    if($s=~ m/${symname}\s*\((.*?)\)/) {
      @args=split m/,/,${^CAPTURE[0]};

    };

# ---   *   ---   *   ---
# expand symbol and insert

    my $code=$sbl->paste(@args);
    $s=~ s/${symname}\s*\((.*?)\)/$code/;
    $_=$s;

# ---   *   ---   *   ---

  };

  return $status;

};

# ---   *   ---   *   ---
1; # ret
