#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

use Cwd qw/abs_path/;
use Getopt::Long;
use File::Basename qw/basename/;
use IPC::Cmd qw/can_run/;
use File::Temp qw/tempfile/;

#--------------------------------------------------------------------------#
# Process and validate command line options
#--------------------------------------------------------------------------#

Getopt::Long::Configure("bundling");

my $parsed_ok = GetOptions(
  'iso|i=s'     => \(my $iso),
  'name|n=s'    => \(my $name),
  'ostype:s'    => \(my $ostype = "Ubuntu_64"),
  'memory:s'    => \(my $memory = 512),
  'hdsize:s'    => \(my $hdsize = 8192),
);

# confirm there is an ISO
die "ISO '$iso' not found\n" unless -f $iso;

my $vdi = "$name.vdi";

#--------------------------------------------------------------------------#
# Confirm command line tools are available
#--------------------------------------------------------------------------#

my %cmd_path;

my @required_commands = qw(
  VBoxManage
  VBoxHeadless
  chmod
  cp
  mkdir
  mkisofs
  mount
  patch
  rm
  rsync
  umount
);


for my $cmd ( @required_commands ) {
  $cmd_path{$cmd} = can_run($cmd)
    or die "Could not find '$cmd' in PATH";
}

#--------------------------------------------------------------------------#
# Main program
#--------------------------------------------------------------------------#

_system("VBoxManage",
  'createvm', '--name', $name, '--ostype', $ostype, '--register'
);

_system("VBoxManage",
  'modifyvm', $name, '--memory', $memory, qw/--acpi on --boot1 dvd --nic1 nat/
);

_system("VBoxManage",
  'createhd', '--filename', $vdi, '--size', $hdsize
);

_system("VBoxManage",
  'storagectl', $name,
  '--name', "IDE Controller", '--add', 'ide', '--controller', 'PIIX4'
);

_system("VBoxManage",
  'storageattach', $name, '--storagectl', "IDE Controller",
  qw/--port 0 --device 0 --type hdd --medium/, $vdi
);

_system("VBoxManage",
  'storageattach', $name, '--storagectl', "IDE Controller",
  qw/--port 0 --device 1 --type dvddrive --medium/, $iso
);

#_system("VBoxHeadless", '--startvm', $name);

exit 0;

#--------------------------------------------------------------------------#
# Utility subroutines
#--------------------------------------------------------------------------#

sub _system {
  my ($cmd, @args) = @_;
  $cmd = $cmd_path{$cmd} or die "Unrecognized command '$cmd'";
  system($cmd, @args)
    and die "Error running $cmd @args" . ( $! ? "$!\n" : "\n" );
  return;
}


exit;

__END__

=head1 NAME

vbox-vm-creator.pl - Create a VirtualBox VM from an ISO

=head1 SYNOPSIS

  $ vbox-vm-creator.pl \
    --iso /path/to/ubuntu.iso

=head1 DESCRIPTION


=head1 OPTIONS

=over

=item *

C<--iso PATH>: path to the install ISO

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2011 by David Golden.

This is free software, licensed under The Apache License, Version 2.0, January
2004.
