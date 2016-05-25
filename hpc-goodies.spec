Summary: HPC Goodies
Name: hpc-goodies
Version: 4.10
Release: 1%{?dist}
License: EPL
Group: Applications/System
URL: https://github.com/finley/HPC-Goodies
Source: %{name}-%{version}.tar.xz
Packager: Brian Finley <brian@thefinleys.com>
Vendor: Brian Finley <brian@thefinleys.com>
Prefix: %{_prefix}
BuildRoot: %{?_tmppath}%{!?_tmppath:/tmp}/%{name}-%{version}-%{release}-root
Requires: %{name}-cpu  = %{version}-%{release}
Requires: %{name}-gpfs = %{version}-%{release}
Requires: %{name}-uefi = %{version}-%{release}
Requires: %{name}-xcat = %{version}-%{release}
Requires: %{name}-ib   = %{version}-%{release}
Requires: %{name}-misc = %{version}-%{release}


%description
ALL of Brian Finley's HPC Goodies (installs all the other goodie bags).

%package cpu
Summary: HPC Goodies for CPUs
Group: Applications/System
Requires: %{name}-libs = %{version}-%{release}

%description cpu
Brian Finley's HPC Goodies for CPUs


%package gpfs
Summary: HPC Goodies for GPFS
Group: Applications/System
Requires: %{name}-libs = %{version}-%{release}

%description gpfs
Brian Finley's HPC Goodies for GPFS


%package ib
Summary: HPC Goodies for InfiniBand
Group: Applications/System
Requires: %{name}-libs = %{version}-%{release}

%description ib
Brian Finley's HPC Goodies for InfiniBand


%package misc
Summary: Miscellaneous HPC Goodies
Group: Applications/System
Requires: %{name}-libs = %{version}-%{release}

%description misc
Brian Finley's HPC Goodies (miscellaneous)


%package uefi
Summary: HPC Goodies for UEFI
Group: Applications/System
Requires: %{name}-libs = %{version}-%{release}

%description uefi
Brian Finley's HPC Goodies for UEFI


%package xcat
Summary: HPC Goodies for xCAT
Group: Applications/System
Requires: %{name}-libs = %{version}-%{release}

%description xcat
Brian Finley's HPC Goodies for xCAT


%package libs
Summary: HPC Goodies shared library files
Group: Applications/System

%description libs
Brian Finley's HPC Goodies library files


%prep
%setup -q


%build


%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/
make -f Makefile install DESTDIR=$RPM_BUILD_ROOT \
    sbindir=%{_sbindir} initdir=%{_initrddir} \
    datadir=%{_datadir}
rm -rf $RPM_BUILD_ROOT%{_datadir}/doc


%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-, root, root)
%doc CREDITS LICENSE README TODO

%files cpu
%defattr(-, root, root)
%{_initrddir}/set-cpu-state
%(grep -w ^cpu README.bin-files-by-package | perl -pe 's|^\S+\s+|%{_sbindir}/|')

%files gpfs
%defattr(-, root, root)
%{_initrddir}/gpfs_syslogging
%(grep -w ^gpfs README.bin-files-by-package | perl -pe 's|^\S+\s+|%{_sbindir}/|')

%files ib
%defattr(-, root, root)
%doc usr/share/doc/ib_arch_diags/*.pdf
%(grep -w ^ib README.bin-files-by-package | perl -pe 's|^\S+\s+|%{_sbindir}/|')

%files misc
%defattr(-, root, root)
%(grep -w ^misc README.bin-files-by-package | perl -pe 's|^\S+\s+|%{_sbindir}/|')

%files uefi
%defattr(-, root, root)
%(grep -w ^uefi README.bin-files-by-package | perl -pe 's|^\S+\s+|%{_sbindir}/|')

%files xcat
%defattr(-, root, root)
%(grep -w ^xcat README.bin-files-by-package | perl -pe 's|^\S+\s+|%{_sbindir}/|')

%files libs
%defattr(-, root, root)
%{_prefix}/lib/%{name}/


%changelog
* Fri Sep 20 2013 Brian Elliott Finley <bfinley@lenovo.com>
- created this spec file

# vim:set tw=0 et ai ts=4:

