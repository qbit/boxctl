BOXCTL(8) - System Manager's Manual

# NAME

**boxctl** - tool to manage remote
OpenBSD
machines

# SYNOPSIS

**boxctl**
\[**-mnv**]
\[**-h**&nbsp;*host*]
\[**-u**&nbsp;*user*]

# DESCRIPTION

**boxctl**
is a
ksh(1)
script designed to help manage
OpenBSD
machines.
It uses only tools contained in
OpenBSD
base.

The options are as follows:

**-h** *host*

> Remote host to be managed.

**-u** *user*

> User to connect to
> *host*
> with.
> Defaults to
> *root*.

**-m**

> Run maintenance tasks.
> This includes deleting unused dependencies using
> pkg\_delete(1).
> And installing / updating firmware using
> fw\_update(1).

**-n**

> Dry run.
> This will only print the commands that will be run.

**-v**

> Increase verbosity.
> More v's can be specified to increase information output.
> The number of v's are passed to tools used by
> **boxctl**.

# FILES

*$CWD/files*

> Is a ":" delimited index of source file, owner, group, mode and destination.
> Each source will be copied to the specified destination, then chown/chmod will
> be run with the values specified.
> If this file does not exist, no files are copied.

*$CWD/services*

> An optional file that contains a list of services to enable on the remote
> host.
> If a service is already enabled, it will be restarted each run of
> **boxctl**.

*$CWD/packages*

> When this file exists,
> **boxctl**
> will install the packages contained therewithin on the remote host.
> A list is cached on the remote host under /etc/packages.
> This list (if it exists) will be compared using
> diff(1)
> and only missing packages will be installed.
> Package names should be listed by their fuzzy names.
> See
> pkg\_info(1)
> for more information on fuzzy names.

# SEE ALSO

chmod(1),
diff(1),
fw\_update(1),
pkg\_add(1),
pkg\_delete(1),
pkg\_info(1),
scp(1),
ssh(1),
chown(8),
rcctl(8)

# HISTORY

The first version of
**boxctl**
was released in September of 2019.

# AUTHORS

**boxctl**
was written by
Aaron Bieber &lt;[aaron@bolddaemon.com](mailto:aaron@bolddaemon.com)&gt;.

OpenBSD 6.6 - September 23, 2019
