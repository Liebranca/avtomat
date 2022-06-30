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

sub import {

  my ($self,$pkg)=@_;
  shadowlib::take($pkg);



#  filter_add(sub {
#
#  my $caller=caller;
#  my ($status,$no_seen,$data);
#
#  while ($status=filter_read()) {
#    if (/^\s*no\s+$caller\s*;\s*?$/) {
#      $no_seen=1;
#      last;
#
#    };
#
#    $data .= $_;
#    $_ = "";
#
#  };
#
#  $_ = $data;
#  s/BANG\s+BANG/die 'BANG' if \$BANG/g
#      unless $status < 0;
#
#  $_ .= "no $caller;\n" if $no_seen;
#  return 1;
#
#  });
};

#sub unimport {
#  filter_del();
#
#};

# ---   *   ---   *   ---
1; # ret
