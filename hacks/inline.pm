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

# ---   *   ---   *   ---

sub import {

  my ($self,$pkg)=@_;
  my $table=shadowlib::take($pkg);

  filter_add(bless {

    table=>$table,

  });
};

sub unimport {
  filter_del();

};

sub filter {

  my ($self)=@_;

  my $caller=caller;
  my $status=filter_read();

# ---   *   ---   *   ---

  my $s=$_;
  if($s=~ $self->{table}->{re}) {

    my $symname=${^CAPTURE[0]};
    my $sbl=$self->{table}->{$symname};

# ---   *   ---   *   ---

    my @args=();
    if($s=~ m/${symname}\s*\((.*?)\)/) {
      @args=split m/,/,${^CAPTURE[0]};

    };

# ---   *   ---   *   ---

    my $code=$sbl->paste(@args);
    $s=~ s/${symname}\s*\((.*?)\)/$code/;

    print "$s\n";
    $_=$s;

  };

  return $status;

};

# ---   *   ---   *   ---
1; # ret
