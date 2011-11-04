#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

use Cwd qw/abs_path/;
use Getopt::Long;
use File::Basename qw/basename dirname/;
use IPC::Cmd qw/can_run/;
use File::Temp qw/tempfile/;

#--------------------------------------------------------------------------#
# Process and validate command line options
#--------------------------------------------------------------------------#

#Getopt::Long::Configure("bundling");

my $parsed_ok = GetOptions(
  'iso=s'       => \(my $iso = ''),
  'name=s'      => \(my $name = ''),
  'ostype=s'    => \(my $ostype = "Ubuntu_64"),
  'memory=s'    => \(my $memory = 512),
  'hdsize=s'    => \(my $hdsize = 8192),
  'network=s'   => \(my $network = 'bridged'),
  'start'       => \(my $start),
  'headless'    => \(my $headless),
);

# confirm required options
die "--iso required" unless $iso;
die "--name required" unless $name;

# confirm valid data
die "--iso '$iso' not found\n" unless -f $iso;
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

die "Virtual machine '$name' already exists\n"
  if grep { /"$name"/ } _backtick("VBoxManage", "list", "vms");

_system("VBoxManage",
  'createvm', '--name', $name, '--ostype', $ostype, '--register'
);

# Find path to store virtual disk image
my $info = _backtick("VBoxManage", 'showvminfo', $name);
my ($vmpath) = $info =~ m{^Config file:\s+(.*)$}m;
$vmpath //= '';
die "Could not find VM config '$vmpath'\n" unless -f $vmpath;
my $vdi = dirname($vmpath) . "/$name.vdi";

_system("VBoxManage",
  'modifyvm', $name, '--memory', $memory, '--nic1', $network,
  qw/--acpi on --boot1 dvd/
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

if ( $start ) {
  _system('VBoxManage', 'startvm', $name,
    $headless ? (qw/--type headless/) : ()
  );
}

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

sub _backtick {
  my ($cmd, @args) = @_;
  $cmd = $cmd_path{$cmd} or die "Unrecognized command '$cmd'";
  return qx/$cmd @args/;
}

exit;

__END__

=head1 NAME

vbox-vm-creator.pl - Create a VirtualBox VM from an ISO

=head1 SYNOPSIS

  $ vbox-vm-creator.pl \
    --iso /path/to/ubuntu.iso \
    --name MyNewVM \
    --ostype Ubuntu_64 \
    --memory 512 \
    --hdsize 8192 \
    --network bridged \
    --start

=head1 DESCRIPTION

This program automates the creation of a new VirtualBox virtual machine
from a ISO image.

=head1 OPTIONS

=over

=item *

C<--iso PATH>: path to the install ISO

=item *

C<--name NAME>: name of the new VM.  It must not have whitespace.

=item *

C<--ostype TYPE>: OS type to set VM defaults. See C<VBoxManage list ostypes>
for valid types.  Default is "Ubuntu_64".

=item *

C<--memory MEGABYTES>: size of VM RAM. Default is 512.

=item *

C<--hdsize MEGABYTES>: size of VM hard drive. Default is 8192.

=item *

C<--network TYPE>: defines the type of network the VM is connected to.
Defaults to 'bridged'.  Other common choices are 'nat', 'intnet' or 'hostonly'.
See the VirtualBox manual for more esoteric options.

=item *

C<--start>: indicates that the VM should be booted after it is created so
that the ISO can install the operating system.  If not used, the VM can
be started manually with C<VBoxManage startvm NAME>.

=item *

C<--headless>: When C<--start> is given, this option has the VM booted in
"headless" mode.

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2011 by David Golden.

This is free software, licensed under The Apache License, Version 2.0, January
2004.
