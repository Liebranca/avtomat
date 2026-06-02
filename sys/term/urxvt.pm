#!/usr/bin/perl
# ---   *   ---   *   ---
# URXVT
# i cannot spell it
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package term::urxvt;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);
  use term qw(
    ttysz
    lycon_data
    fullscreen
    zoom
    scroll
  );


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter "import";
  our @EXPORT_OK=qw(on_start on_user_command);


# ---   *   ---   *   ---
# info

  my $AUTHOR  = "IBN-3DILA";
  my $VERSION = "v0.00.2a";


# ---   *   ---   *   ---
# entry point
#
# attached to each terminal window we spawn,
# so it doubles as cstruc

sub on_start {
  my ($self)=@_;
  lycon_data($self);

  # find this window's IDs...
  my $re=qr{
    (?:0x[a-fA-F\d]+) \s+
    (?:[^\s]+) \s+
    (?<pid> \d+) \s+
    (?:[^\s]+) \s+
    (?<title> .+)
  }x;
  my @ar=map {
    if($ARG=~ $re) {
      {pid=>$+{pid},title=>$+{title}};

    } else {()};

  } split(qr"\n+",`wmctrl -lp`);

  # ^set title!
  $self->{title} //= "urxvt";
  for(@ar) {
    if($ARG->{pid} eq $$) {
      $self->{title}=$ARG->{title};
      last;
    };
  };
  # this is hacky, but there doesn't
  # seem to be an event after
  # window creation
  if(! ($self->{title}=~ qr{^\[W\] })) {
    $self->{timer}=urxvt::timer->new;
    $self->{timer}->after(0.1)->cb(
      sub {fullscreen($self)}
    );
  };
  return;
};


# ---   *   ---   *   ---
# ^ and each uses this jumptable
#   so second entry point
#
# here we don't construct, and simply
# branch out accto input

sub on_user_command {
  my $tab={
    fullscreen => \&fullscreen,
    zoomin     => \&zoom,
    zoomout    => \&zoom,
    pageup     => \&scroll,
    pagedown   => \&scroll,
  };
  my ($self,$cmd) = @_;
  my $re  =  qr{^lycon:};
     $cmd =~ s[$re][];

  my $fn=$tab->{$cmd};
  $fn->($self,$cmd) if defined $fn;

  return;
};


# ---   *   ---   *   ---
1; # ret
