Summary: HPC Goodies
Name: hpc-goodies
Version:      4.9
Release: 1
Source: %{name}-%{version}.tar.bz2
BuildRoot: /tmp/%{name}-buildroot
BuildArchitectures: noarch
License: GPLv2


%description
HPC Goodies



%prep
%setup -q

%build

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/
make -f Makefile PREFIX=$RPM_BUILD_ROOT install

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
/etc/init.d/*
%{_prefix}/sbin/*
%{_prefix}/share/*

%changelog
* Fri Sep 20 2013 Brian Elliott Finley <bfinley@us.ibm.com>
- created this spec file

