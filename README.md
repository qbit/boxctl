BOXCTL(8) - System Manager's Manual

# NAME

**boxctl** - tool to manage remote
OpenBSD
machines

# SYNOPSIS

**boxctl**
\[**-cfmnsv**]
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

**-c**

> Copy managed files from server into local directory.

**-h** *host*

> Remote host to be managed.

**-u** *user*

> User to connect to
> *host*
> with.
> Defaults to
> *root*.

**-f**

> Force installation of all packages and restarting of all services
> This skips the 'intelligent' diff and service restart mode.

**-m**

> Run maintenance tasks.
> This includes deleting unused dependencies using
> pkg\_delete(1).
> And installing / updating packages and firmware using
> fw\_update(1)
> and
> pkg\_add(1).

**-n**

> Dry run.
> This will only print the commands that will be run.

**-s**

> Force
> pkg\_add(1)
> to run with '-Dsnap'.
> This is useful when
> OpenBSD
> is in -beta.

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
> Each line in the file should contain "name:path".
> Where "name" is the name of a service (httpd for example) and "path" is the
> full path to a file that when modified, should trigger a restart of the named
> service.
> For example, the entry "httpd:/etc/httpd.conf" would restart
> httpd(8)
> if the mtime on "/etc/httpd.conf" is less than 100 seconds from the current
> time.

*$CWD/groups*

> A ":" delimited list of groups to be added to the remote host.
> Entries should follow a "group:gid" pattern.

*$CWD/users*

> A ":" delimited list of users to be added to the remote host.
> Entries should follow the pattern: "user:uid:gid:comment:home:shell:password".
> The "comment" filed should not contain white space for the time being.
> "password" is expected to be an encrypted string produced via
> encrypt(1).

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

*$CWD/commands*

> An optional file that contains a script that will be executed at the end of
> the run.

# SEE ALSO

chmod(1),
diff(1),
encrypt(1),
fw\_update(1),
ksh(1),
openrsync(1),
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

OpenBSD 6.7 - September 23, 2019
