#
#  vi:set filetype=make noet ai tw=0:
#

SHELL 		= /bin/sh
rpmbuild    = ~/rpmbuild

#
# These settings are what I would expect for most modern Linux distros, 
# and are what work for me unmodified on Ubuntu. -BEF-
# 
package		= hpc-goodies

initdir 	= /etc/init.d
prefix		= /usr
bindir 		= ${prefix}/bin
sbindir 	= ${prefix}/sbin

libdir  	= ${prefix}/lib
pkglibdir	= ${libdir}/${package}

datadir		= ${prefix}/share
mandir		= ${datadir}/man
docdir 		= ${datadir}/doc/${package}

d			= $(DESTDIR)

VERSION = $(shell cat VERSION | sed -e 's/-.*//')
MINOR = $(shell cat VERSION   | sed -e 's/.*-//')

TOPDIR := $(CURDIR)

# bin-cpu
# bin-gpfs
# bin-ib
# bin-misc
# bin-uefi
# bin-xcat
# bin-libs

BINCOMPILED    	 = c1eutil/c1eutil  set_dma_latency/set_dma_latency
BINSCRIPTS    	 = $(shell find $(TOPDIR)/bin/*)
SBINFILES    	 = $(BINSCRIPTS) $(BINCOMPILED)
PKGLIBFILES 	 = $(shell find $(TOPDIR)/usr/lib/*)
INIT_SCRIPTS	 = $(shell find $(TOPDIR)/etc/init.d/*)
HALF_BAKED_FILES = $(shell find $(TOPDIR)/half-baked/*)
DOC_FILES   	 = CREDITS LICENSE README TODO

RPM_PKG_FILES 	 = hpc-goodies.spec
DEB_PKG_FILES 	 = $(shell find debian/*)
COMMON_PKG_FILES = Makefile README.bin-files-by-package VERSION
ALL_FILES		 = $(BINSCRIPTS) $(PKGLIBFILES) $(INIT_SCRIPTS) $(DOC_FILES) $(HALF_BAKED_FILES) $(COMMON_PKG_FILES) $(RPM_PKG_FILES) $(DEB_PKG_FILES)


.PHONY: all
all:  $(SBINFILES) $(INIT_SCRIPTS)


.PHONY: set_dma_latency
set_dma_latency: set_dma_latency/set_dma_latency
set_dma_latency/set_dma_latency:

.PHONY: set_dma_latency_clean
set_dma_latency_clean:
	-rm -f  set_dma_latency/set_dma_latency


.PHONY: c1eutil
c1eutil: c1eutil/c1eutil
c1eutil/c1eutil:

.PHONY: c1eutil_clean
c1eutil_clean:
	-rm -f  c1eutil/c1eutil


.PHONY: install
install:  all
	#
	# sbinaries	
	#
	test -d ${d}/${sbindir} || install -d -m 755  ${d}/${sbindir}
	@ $(foreach file, $(SBINFILES), \
		echo install -m 755 ${file} ${d}/${sbindir}/;\
  		install -m 755 ${file} ${d}/${sbindir}/; )
	
	#
	# init scripts
	#
	test -d ${d}/${initdir} || install -d -m 755	${d}/${initdir}
	@ $(foreach file, $(INIT_SCRIPTS), \
		echo install -m 755 ${file} ${d}/${initdir}/;\
  		install -m 755 ${file} ${d}/${initdir}/; )
	
	#
	# Libs
	#
	test -d ${d}/${pkglibdir} || install -d -m 755 ${d}/${pkglibdir}
	@ $(foreach file, $(PKGLIBFILES), \
		echo install -m 644 ${file} ${d}/${pkglibdir}/;\
  		install -m 644 ${file} ${d}/${pkglibdir}/; )
	
	#
	# Docs
	#
	test -d ${d}/${docdir} || install -d -m 755 ${d}/${docdir}
	@ $(foreach file, $(DOCFILES), \
		echo install -m 644 ${file} ${d}/${docdir}/;\
  		install -m 644 ${file} ${d}/${docdir}/; )
	
	#
	# half baked
	#
	test -d ${d}/${docdir}/half-baked || install -d -m 755 ${d}/${docdir}/half-baked
	@ $(foreach file, $(HALF_BAKED_FILES), \
  		echo install -m 644 ${file} ${d}/${docdir}/half-baked/;\
  		install -m 644 ${file} ${d}/${docdir}/half-baked/; )
		

.PHONY: release
release:
	@echo "Please try 'make test_release' or 'make stable_release'"

.PHONY: test_release
#test_release:  tarball debs rpms
test_release:  tarball rpms
	@echo 
	@echo "I'm about to upload the following files to bintray:"
	@echo "-----------------------------------------------------------------------"
	@/bin/ls -1 $(TOPDIR)/tmp/${package}[-_]*$(VERSION)-$(MINOR)*.*
	@echo
	@echo "Hit <Enter> to continue..."
	@read i
	bintray-upload-rpms.sh el7 $(TOPDIR)/tmp/${package}*[-_]$(VERSION)-$(MINOR)*.rpm

.PHONY: stable_release
#stable_release:  tarball debs rpms
stable_release:  tarball rpms
	@echo 
	@echo "I'm about to upload the following files to:"
	@echo "  ~/src/www.systemimager.org/stable/${package}/"
	@echo "-----------------------------------------------------------------------"
	@/bin/ls -1 $(TOPDIR)/tmp/${package}[-_]*$(VERSION)-$(MINOR)*.*
	@echo
	@echo "Hit <Enter> to continue..."
	@read i
	bintray-upload-rpms.sh el7 $(TOPDIR)/tmp/${package}*[-_]$(VERSION)-$(MINOR)*.rpm

.PHONY: rpm
rpm:  rpms

.PHONY: rpms
rpms:  tarball
	@echo Bake them cookies, grandma!
	rpmbuild -ta --sign $(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR).tar.xz
	/bin/cp -i ${rpmbuild}/RPMS/*/${package}-*$(VERSION)-$(MINOR)*.rpm 	$(TOPDIR)/tmp/
	/bin/cp -i ${rpmbuild}/SRPMS/${package}-*$(VERSION)-$(MINOR)*.rpm	$(TOPDIR)/tmp/
	/bin/ls -1 $(TOPDIR)/tmp/${package}[-_]*$(VERSION)-$(MINOR)*.*

.PHONY: deb
deb:  debs

.PHONY: debs
debs:  tarball
	ln $(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR).tar.xz $(TOPDIR)/tmp/${package}_$(VERSION)-$(MINOR).orig.tar.xz
	cd $(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR) && debuild -us -uc
	/bin/ls -1 $(TOPDIR)/tmp/${package}[-_]*$(VERSION)-$(MINOR)*.*

.PHONY: tarball
tarball:  $(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR).tar.xz.sign
$(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR).tar.xz.sign:  $(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR).tar.xz  
	cd $(TOPDIR)/tmp && gpg --detach-sign -a --output ${package}-$(VERSION)-$(MINOR).tar.xz.sign ${package}-$(VERSION)-$(MINOR).tar.xz
	cd $(TOPDIR)/tmp && gpg --verify ${package}-$(VERSION)-$(MINOR).tar.xz.sign

$(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR).tar.xz:	 $(ALL_FILES)
	make distclean
	
	@ echo ; echo "git stat . | egrep '^\s+modified:\s+'"
	@git stat . | egrep '^\s+modified:\s+' \
		&& (echo "WARN:  There are uncommitted changes to this repo."; echo "       Do you want cancel this build and commit them?"; read i ) \
		|| true
	
	@(echo ; echo "WARN:  Did you update the version in VERSION (currently set to $(VERSION)-$(MINOR))?"; read i )
	
	@git tag | grep -qw v$(VERSION)-$(MINOR) \
		|| (echo "WARN:  Do you want to cancel to tag this repo as v$(VERSION)-$(MINOR)?"; read i )
	
	mkdir -p    $(TOPDIR)/tmp/
	git clone . $(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR)/
	#
	# Use the latest Makefile and specfile for pre-release package testing
	
	@echo '# deb pkg bits first'
	@echo 'git log `git describe --tags --abbrev=0`..HEAD --oneline > /tmp/${package}.gitlog'
	@echo 'while read line; do dch --newversion $(VERSION)-$(MINOR) "$$line"; done < /tmp/hpc-goodies.gitlog'
	@echo 'dch --release "" --distribution stable --no-force-save-on-release'
	@echo 'head debian/changelog'
	@echo
	@echo '# RPM bits next'
	@echo 'perl -pi -e "s/^Version:.*/Version:      $(VERSION)/" hpc-goodies.spec'
	@echo 'perl -pi -e "s/^Release:\s+\d+/Release: $(MINOR)/" 	$(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR)/${package}.spec'
	@echo 'head hpc-goodies.spec'
	@echo '# dont worry about changelog entries in spec file for now...  #vim hpc-goodies.spec'
	@read i

	@echo "WARN: Including the following files from this directory in the tarball, whether"
	@echo "      they are committed to the repo or not.  So be sure that these files are "
	@echo "      committed before doing a release!"
	@echo 
	@echo "      $(COMMON_PKG_FILES)"
	@echo "      $(RPM_PKG_FILES)"
	@echo "      $(DEB_PKG_FILES)"
	@echo 
	@rsync -av $(COMMON_PKG_FILES) $(RPM_PKG_FILES) $(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR)
	@rsync -av $(DEB_PKG_FILES)                     $(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR)/debian/
	@echo "done..."
	@read i

	git log   > $(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR)/CHANGE.LOG
	rm -fr      $(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR)/.git
	perl -pi -e "s/^Version:.*/Version: $(VERSION)/" 			$(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR)/${package}.spec
	perl -pi -e "s/^Release:\s+\d+/Release: $(MINOR)/" 	$(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR)/${package}.spec
	find  $(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR) -type f -exec chmod ug+r  {} \;
	find  $(TOPDIR)/tmp/${package}-$(VERSION)-$(MINOR) -type d -exec chmod ug+rx {} \;
	cd    $(TOPDIR)/tmp/ && tar -ch ${package}-$(VERSION)-$(MINOR) | xz > ${package}-$(VERSION)-$(MINOR).tar.xz
	ls -l $(TOPDIR)/tmp/


.PHONY: clean
clean:	c1eutil_clean
	-rm -fr $(TOPDIR)/tmp/ $(TOPDIR)/${package}-$(VERSION)-$(MINOR)
	-rm -fr $(TOPDIR)/usr/share/man/
	-rm -f  $(TOPDIR)/${package}-$(VERSION)-$(MINOR).tar.* $(TOPDIR)/${package}-*.rpm
	-rm -f  set_dma_latency/set_dma_latency

.PHONY: distclean
distclean: clean
	-rm -f  $(TOPDIR)/configure-stamp
	-rm -f  $(TOPDIR)/build-stamp
	-rm -f  $(TOPDIR)/debian/files
	-rm -fr $(TOPDIR)/debian/${package}/

.PHONY: help
help:
	@echo All Available Targets Include:
	@echo ---------------------------------------------------------------------
	@cat Makefile | egrep '^[a-zA-Z0-9_]+:' | sed 's/:.*//' | sort -u
	@echo


