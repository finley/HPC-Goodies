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

%description
Brian Finley's HPC Goodies


%prep
%setup -q


%build


%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/
make -f Makefile install DESTDIR=$RPM_BUILD_ROOT \
    sbindir=%{_sbindir} initdir=%{_initrddir} \
    datadir=%{_datadir}


%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root)
%{_initrddir}/*
%{_sbindir}/*
%{_datadir}/*
%{_prefix}/lib/%{name}


%changelog
* Fri Sep 20 2013 Brian Elliott Finley <bfinley@lenovo.com>
- created this spec file

