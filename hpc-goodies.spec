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
%{_initrddir}/set_cpu_state
%{_sbindir}/c1eutil
%{_sbindir}/set_dma_latency

%files gpfs
%defattr(-, root, root)
%{_initrddir}/gpfs_syslogging
%{_sbindir}/test_gpfs_state

%files ib
%defattr(-, root, root)
%doc usr/share/doc/ib_arch_diags/*
$(grep hpc-goodies-ib README.bin-files-by-package | sed 's/^hpc-goodies-ib/%{_sbindir}\//')
    #XXX how to include a shell command within an rpm specfile %files
    location

%files misc
%defattr(-, root, root)
%{_sbindir}/p2p_label_maker_input_maker
%{_sbindir}/vnc.setup_ssh_tunnel
%{_sbindir}/hpc_system_size_calculator
%{_sbindir}/mac_to_ipv6

%files uefi
%defattr(-, root, root)
%{_sbindir}/get_uefi_settings
%{_sbindir}/set_uefi_to_best_recipe

%files xcat
%defattr(-, root, root)
%{_sbindir}/backup_lenovo-ethernet-switch
%{_sbindir}/backup_xcatdb

%files libs
%defattr(-, root, root)
%{_prefix}/lib/%{name}/

%files all
%defattr(-, root, root)
%doc CREDITS LICENSE README TODO


%changelog
* Fri Sep 20 2013 Brian Elliott Finley <bfinley@lenovo.com>
- created this spec file

