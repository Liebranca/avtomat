#!/usr/bin/perl
# ---   *   ---   *   ---
# TERM
# bash it
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package term;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);
  use Arstd::String qw(gstrip gsplit);
  use Arstd::Bin qw(deepcpy);
  use Arstd::throw;
  use Vault;
  use St;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter "import";
  our @EXPORT_OK=qw(
    cmdchain
    ttysz
    lycon_data
    fullscreen
    zoom
    scroll
  );


# ---   *   ---   *   ---
# info

  my $AUTHOR  = "IBN-3DILA";
  my $VERSION = "v0.00.2a";


# ---   *   ---   *   ---
# cstruc

sub lycon_data {
  $_[0]->{font} //= {
    name => "lycon",
    lvl  => 0,
    base => $_[0]->fwidth,
  };
  $_[0]->{gf} //= {
    flg  => 0x00,
    scr  => ttysz($_[0]),
  };
  return;
};


# ---   *   ---   *   ---
# window size

sub ttysz {
  my ($self)=@_;
  return [$self->nrow,$self->ncol];
#  return [gsplit(`stty size`,q{\s+})];
};
sub ttysz_to_pixel {
  my ($self) = @_;
  my $scr    = $_[1] // ttysz($self);
  my $pixel  = fontsize($self);

  return [
    $scr->[0] * $pixel,
    $scr->[1] * $pixel,
  ];
};
sub ttysz_to_char {
  my ($self) = @_;
  my $scr    = $_[1] // ttysz($self);
  my $pixel  = fontsize($self);

  return [
    int($scr->[0] / $pixel),
    int($scr->[1] / $pixel),
  ];
};
sub fontsize {
  my ($self)=@_;
  return (
    $self->{font}->{base}
  + $self->{font}->{lvl}
  );
};


# ---   *   ---   *   ---
# selfex

sub fullscreen($self,@slurp) {
  if(exists $self->{timer}) {
    my $wid = $self->parent;
    my $err = `wmctrl -i -r $wid -b add,fullscreen`;

    warn   "Error maximizing: $err\n"
    unless $? == 0;

    $self->{timer}->stop;
    delete $self->{timer};
    $self->{gf}->{flg} |= is_fullscreen();

  } else {
    `wmctrl -r :ACTIVE: -b toggle,fullscreen`;
    $self->{gf}->{flg} ^= is_fullscreen();
  };
  return;
};

sub is_fullscreen {
  my $flg=0x0001;
  if(exists $_[0]) {
    return $_[0]->{gf}->{flg} & $flg;
  };
  return $flg;
};


# ---   *   ---   *   ---
# go up or down a page

sub scroll($self,$cmd) {
  my $me=($cmd eq 'pageup')
    ? "\033]720"
    : "\033]721"
    ;
  my $x=$self->{gf}->{scr}->[0];
  $self->cmd_parse("$me;$x\007");
  return;
};


# ---   *   ---   *   ---
# make font bigger or smaller

sub zoom($self,$cmd) {
  # remember the old window size
  my $scrpx=ttysz_to_pixel($self);

  # mutate based on command
  if ($cmd eq 'zoomin') {
    my $allow=$self->{font}->{lvl} < 64;
    $self->{font}->{lvl} += 4*$allow;

  } elsif ($cmd eq 'zoomout') {
    my $allow=(
      $self->{font}->{lvl}
    > -($self->{font}->{base}-8)
    );
    $self->{font}->{lvl} -= 4*$allow;
  };
  # build the full *internal* command
  my $name=  $self->{font}->{name};
  my $size = fontsize($self);
  my $aa   = ($size >= $self->{font}->{base})
    ? 'false'
    : 'true'
    ;
  my $paste=
    "xft:${name}:"
  . "pixelsize=${size}:"
  . "antialias=$aa:"
  . "autohint=$aa"
  . "\007"
  ;
  $self->cmd_parse(
    "\033]50;$paste"
  . "\033]51;$paste"
  . "\033[8;0;0t"
  );
  # lazy auto-adjust for fullscreen
  if(is_fullscreen($self)) {
    fullscreen($self);
    fullscreen($self);

  # window auto-adjust
  } else {
    my $scr=ttysz_to_char($self,$scrpx);
    if($scr->[0] <= 0) {
      $scr->[0]=1;
    };
    if($scr->[1] <= 0) {
      $scr->[1]=1;
    };
    $self->cmd_parse(
      "\e[8;$scr->[0];$scr->[1]t"
    );
  };
  # ~~
  $self->{gf}->{scr}=ttysz($self);
  return;
};


# ---   *   ---   *   ---
# this is for when you want to land on a final
# command from a series of calls, but you want
# to let the user configure which commands to use!

sub cmdchain {
  my $data = shift;
  my $cmd  = shift;
  my $proc = St::cf(2);

  my $tab=Vault->cached($proc,sub {$data});
  my ($out,$update)=cmdlink($cmd,$tab,@_);

  Vault->schedup($proc,deepcpy($tab))
  if! is_null($update);

  return $out;
};


# ---   *   ---   *   ---
# ^reads each command

sub cmdlink {
  my $cmd = shift // null;
  my $tab = shift // {};
  my $O   = (int(@_) & 1)
    ? {value=>pop // null,@_}
    : {@_}
    ;
  my $proc   = St::cf(3);
  my $update = null;
  if($cmd=~ qr{^(?:set|be)$}) {
    # validate
    my $req=$O->{value};
    my $def=$tab->{$req}
    or throw "$proc cannot $cmd $req";

    # set: hard overwrite default
    $update=1 if $cmd eq "set";

    # be: soft overwrite
    $tab->{default}=$def;
  };
  my $pre=(defined $tab->{default})
    ? $tab->{ $O->{be} // $tab->{default} }
    : null
    ;
  # the prefix may indicate that it will contain
  # it's input rather than placing it on another
  # token!
  my $re=qr[\$\{cmd\}];
  if($pre=~ s[$re][$cmd]g) {
    $cmd=null;
  };
  return (join(" ",gstrip($pre,$cmd)),$update);
};


# ---   *   ---   *   ---
1; # ret
