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

VERSION = $(shell cat VERSION)
RELEASE = $(shell cat RELEASE)

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
COMMON_PKG_FILES = Makefile README.bin-files-by-package VERSION RELEASE
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
	test -e ${d}/${sbindir}/set-cpu-state || ln -s  ${d}/${initdir}/set-cpu-state ${d}/${sbindir}/set-cpu-state
	
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
	@echo "Please try 'make rpms' or 'make upload'"

.PHONY: upload_rpms
upload_rpms:  rpms
	@echo 
	@echo "I'm about to upload the following files to bintray:"
	@echo "-----------------------------------------------------------------------"
	@/bin/ls -1 $(TOPDIR)/tmp/${package}[-_]*$(VERSION)-$(RELEASE)*.*
	@echo
	@echo "Hit <Enter> to continue..."
	@read i
	bintray-upload-rpms.sh el7 $(TOPDIR)/tmp/${package}*[-_]$(VERSION)-$(RELEASE)*.rpm
	@echo
	@echo "Now visit https://bintray.com/beta/#/systemimager/rpms?tab=packages to publish"
	@echo


.PHONY: rpm
rpm:  rpms

.PHONY: rpms
rpms:  tarball
	@echo Bake them cookies, grandma!
	rpmbuild -ta --sign $(TOPDIR)/tmp/${package}-$(VERSION)-$(RELEASE).tar.xz
	/bin/cp -i ${rpmbuild}/RPMS/*/${package}-*$(VERSION)-$(RELEASE)*.rpm 	$(TOPDIR)/tmp/
	/bin/cp -i ${rpmbuild}/SRPMS/${package}-*$(VERSION)-$(RELEASE)*.rpm	$(TOPDIR)/tmp/
	/bin/ls -1 $(TOPDIR)/tmp/${package}[-_]*$(VERSION)*.*
	@echo
	@echo "Try 'make upload_rpms' to upload for distribution."
	@echo

.PHONY: deb
deb:  debs

.PHONY: debs
debs:  tarball
	ln $(TOPDIR)/tmp/${package}-$(VERSION)-$(RELEASE).tar.xz $(TOPDIR)/tmp/${package}_$(VERSION)-$(RELEASE).orig.tar.xz
	cd $(TOPDIR)/tmp/${package}-$(VERSION) && debuild -us -uc
	/bin/ls -1 $(TOPDIR)/tmp/${package}[-_]*$(VERSION)*.*
	@echo
	@echo "Try 'make upload_debs' to upload for distribution."
	@echo

.PHONY: tarball
tarball:  $(TOPDIR)/tmp/${package}-$(VERSION)-$(RELEASE).tar.xz.sign
$(TOPDIR)/tmp/${package}-$(VERSION)-$(RELEASE).tar.xz.sign:  $(TOPDIR)/tmp/${package}-$(VERSION)-$(RELEASE).tar.xz  
	cd $(TOPDIR)/tmp && gpg --detach-sign -a --output ${package}-$(VERSION)-$(RELEASE).tar.xz.sign ${package}-$(VERSION)-$(RELEASE).tar.xz
	cd $(TOPDIR)/tmp && gpg --verify ${package}-$(VERSION)-$(RELEASE).tar.xz.sign

$(TOPDIR)/tmp/${package}-$(VERSION)-$(RELEASE).tar.xz:	 $(ALL_FILES)
	make distclean
	
	@ echo ; echo "git stat . | egrep '^\s+modified:\s+'"
	@git stat . | egrep '^\s+modified:\s+' \
		&& (echo "WARN:  There are uncommitted changes to this repo."; echo "       Do you want cancel this build and commit them?"; read i ) \
		|| true
	
	@(echo ; echo "WARN:  Did you update the version in VERSION (currently set to $(VERSION))?"; read i )
	
	@git tag | grep -qw v$(VERSION) \
		|| (echo "WARN:  Do you want to cancel to tag this repo as v$(VERSION)?"; read i )
	
	mkdir -p    $(TOPDIR)/tmp/
	git clone . $(TOPDIR)/tmp/${package}-$(VERSION)/
	#
	# Use the latest Makefile and specfile always
	@echo "WARN: Including the following files from this directory in the tarball, whether"
	@echo "      they are committed to the repo or not."
	@echo 
	@ $(foreach file, $(COMMON_PKG_FILES) $(RPM_PKG_FILES) $(DEB_PKG_FILES) , \
		echo "    /bin/cp -a ${file} $(TOPDIR)/tmp/${package}-$(VERSION)/${file}";\
			 /bin/cp -a ${file} $(TOPDIR)/tmp/${package}-$(VERSION)/${file}; )
	
	@echo 
	git log   > $(TOPDIR)/tmp/${package}-$(VERSION)/CHANGE.LOG
	rm -fr      $(TOPDIR)/tmp/${package}-$(VERSION)/.git
	rm -fr      $(TOPDIR)/tmp/${package}-$(VERSION)/.gitignore
	
	perl -pi -e "s/^Version:.*/Version: $(VERSION)/"	$(TOPDIR)/tmp/${package}-$(VERSION)/${package}.spec
	perl -pi -e "s/^Release:\s+\d+/Release: $(RELEASE)/" 	$(TOPDIR)/tmp/${package}-$(VERSION)/${package}.spec
	find  $(TOPDIR)/tmp/${package}-$(VERSION) -type f -exec chmod ug+r  {} \;
	find  $(TOPDIR)/tmp/${package}-$(VERSION) -type d -exec chmod ug+rx {} \;
	cd    $(TOPDIR)/tmp/ && tar -ch ${package}-$(VERSION) | xz > ${package}-$(VERSION)-$(RELEASE).tar.xz
	ls -l $(TOPDIR)/tmp/


.PHONY: clean
clean:	c1eutil_clean
	-rm -fr $(TOPDIR)/tmp/ $(TOPDIR)/${package}-$(VERSION)
	-rm -fr $(TOPDIR)/usr/share/man/
	-rm -f  $(TOPDIR)/${package}-$(VERSION)-$(RELEASE).tar.* $(TOPDIR)/${package}-*.rpm
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


