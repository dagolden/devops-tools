#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

use IPC::Cmd qw/can_run/;
use Getopt::Long;

#--------------------------------------------------------------------------#
# Process and validate command line options
#--------------------------------------------------------------------------#

#Getopt::Long::Configure("bundling");

my $parsed_ok = GetOptions(
  'name=s'      => \(my $name = ''),
);

# confirm required options
die "--name required" unless $name;

# confirm valid data
die "--name '$name' must not have whitespace\n" if $name =~ /\s/;

#--------------------------------------------------------------------------#
# Confirm command line tools are available
#--------------------------------------------------------------------------#

my %cmd_path;

my @required_commands = qw(
  VBoxManage
);

for my $cmd ( @required_commands ) {
  $cmd_path{$cmd} = can_run($cmd)
    or die "Could not find '$cmd' in PATH";
}

#--------------------------------------------------------------------------#
# Main program
#--------------------------------------------------------------------------#

die "Virtual machine '$name' does not exists\n"
  unless grep { /"$name"/ } _backtick("VBoxManage", "list", "vms");

die "Virtual machine '$name' not running\n"
  unless grep { /"$name"/ } _backtick("VBoxManage", "list", "runningvms");

my $ip = _has_ip($name);

say $ip if defined $ip;

exit 0;

#--------------------------------------------------------------------------#
# Utility subroutines
#--------------------------------------------------------------------------#

sub _vm_uuid {
  my ($vm) = @_;
  my $res = _backtick("VBoxManage", qw/showvminfo/, $vm);
  my ($uuid) = $res =~ /^UUID:\s+(\S+)/m;
  return $uuid;
}

sub _has_ip {
  my ($vm) = @_;
  # get IP by UUID in case old data by name is there and stale
  my $res = _backtick("VBoxManage", qw/guestproperty get/, _vm_uuid($vm),
    '/VirtualBox/GuestInfo/Net/0/V4/IP'
  );
  if ( $res =~ /^Value:\s+(\d+(?:\.\d+){3})/ ) {
    return $1;
  }
  return;
}

sub _system {
  my ($cmd, @args) = @_;
  $cmd = $cmd_path{$cmd} or die "Unrecognized command '$cmd'";
  system($cmd, @args)
    and die "Error running $cmd @args" . ( $! ? ": $!\n" : "\n" );
  return;
}

sub _backtick {
  my ($cmd, @args) = @_;
  $cmd = $cmd_path{$cmd} or die "Unrecognized command '$cmd'";
  return qx/$cmd @args/;
}

exit;

__END__

=head1 NAME

vbox-find-ip.pl - Find IP address of a running VirtualBox VM

=head1 SYNOPSIS

  $ vbox-find-ip --name MyNewVM

=head1 DESCRIPTION

This program is shorthand for getting the IP address from VirtualBox
VM Guest Properties.

=head1 OPTIONS

=over

=item *

C<--name NAME>: name of a VM.  It must not have whitespace.

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2011 by David Golden.

This is free software, licensed under The Apache License, Version 2.0, January
2004.
