#
#  vi:set filetype=make noet ai tw=0:
#

SHELL = /bin/sh

#
# These settings are what I would expect for most modern Linux distros, 
# and are what work for me unmodified on Ubuntu. -BEF-
# 
package		= hpc-goodies
prefix		= /usr
exec_prefix = ${prefix}
bindir 		= ${PREFIX}${exec_prefix}/sbin
initdir 	= ${PREFIX}/etc/init.d
mandir		= ${PREFIX}${prefix}/share/man
docdir 		= ${PREFIX}/usr/share/doc/${package}
libdir  	= ${PREFIX}/usr/share/${package}
rpmbuild    = ~/rpmbuild

VERSION = $(shell cat VERSION)

TOPDIR := $(CURDIR)


.PHONY: all
all:  $(TOPDIR)/bin/* $(TOPDIR)/etc/init.d/* $(TOPDIR)/bin/c1eutil $(TOPDIR)/bin/set_dma_latency

.PHONY: install
install:  all
	test -d ${bindir} || install -d -m 755  ${bindir}
	install -m 755 $(TOPDIR)/bin/*			${bindir}
	
	test -d ${initdir} || install -d -m 755	${initdir}
	install -m 755 $(TOPDIR)/etc/init.d/*	${initdir}
	
	#
	# Libs
	#
	test -d ${libdir} || install -d -m 755 ${libdir}
	install -m 644 $(TOPDIR)/usr/share/functions.sh ${libdir}/
	#
	test -d ${docdir} || install -d -m 755 ${docdir}
	install -m 644 $(TOPDIR)/CREDITS  	${docdir}
	install -m 644 $(TOPDIR)/README  	${docdir}
	#	
	

.PHONY: release
release:
	@echo "Please try 'make test_release' or 'make stable_release'"

.PHONY: test_release
test_release:  tarball rpms
#test_release:  tarball debs rpms
	@echo 
	@echo "I'm about to upload the following files to:"
	@echo "  ~/src/www.systemimager.org/testing/${package}/"
	@echo "-----------------------------------------------------------------------"
	@/bin/ls -1 $(TOPDIR)/tmp/${package}[-_]$(VERSION)*.*
	@echo
	@echo "Hit <Enter> to continue..."
	@read i
	rsync -av --progress $(TOPDIR)/tmp/${package}[-_]$(VERSION)*.* ~/src/www.systemimager.org/testing/${package}/
	@echo
	@echo "Now run:   cd ~/src/www.systemimager.org/ && make upload"
	@echo

.PHONY: stable_release
stable_release:  tarball rpms
#stable_release:  tarball debs rpms
	@echo 
	@echo "I'm about to upload the following files to:"
	@echo "  ~/src/www.systemimager.org/stable/${package}/"
	@echo "-----------------------------------------------------------------------"
	@/bin/ls -1 $(TOPDIR)/tmp/${package}[-_]$(VERSION)*.*
	@echo
	@echo "Hit <Enter> to continue..."
	@read i
	rsync -av --progress $(TOPDIR)/tmp/${package}[-_]$(VERSION)*.* ~/src/www.systemimager.org/stable/${package}/
	@echo
	@echo "Now run:   cd ~/src/www.systemimager.org/ && make upload"
	@echo

.PHONY: rpm
rpm:  rpms

.PHONY: rpms
rpms:  tarball
	@echo Bake them cookies, grandma!
	rpmbuild -ta $(TOPDIR)/tmp/${package}-$(VERSION).tar.bz2
	/bin/cp -i ${rpmbuild}/RPMS/*/${package}-$(VERSION)-*.rpm $(TOPDIR)/tmp/
	/bin/cp -i ${rpmbuild}/SRPMS/${package}-$(VERSION)-*.rpm	$(TOPDIR)/tmp/
	/bin/ls -1 $(TOPDIR)/tmp/${package}[-_]$(VERSION)*.*

.PHONY: deb
deb:  debs

.PHONY: debs
debs:  tarball
	ln $(TOPDIR)/tmp/${package}-$(VERSION).tar.bz2 $(TOPDIR)/tmp/${package}_$(VERSION).orig.tar.bz2
	cd $(TOPDIR)/tmp/${package}-$(VERSION) && debuild -us -uc
	/bin/ls -1 $(TOPDIR)/tmp/${package}[-_]$(VERSION)*.*

.PHONY: tarball
tarball:  $(TOPDIR)/tmp/${package}-$(VERSION).tar.bz2.sign
$(TOPDIR)/tmp/${package}-$(VERSION).tar.bz2.sign: $(TOPDIR)/tmp/${package}-$(VERSION).tar.bz2
	cd $(TOPDIR)/tmp && gpg --detach-sign -a --output ${package}-$(VERSION).tar.bz2.sign ${package}-$(VERSION).tar.bz2
	cd $(TOPDIR)/tmp && gpg --verify ${package}-$(VERSION).tar.bz2.sign

$(TOPDIR)/tmp/${package}-$(VERSION).tar.bz2:  clean all
	@echo "Did you update the version in VERSION?"
	@echo 
	@echo "  Here's what it's currently set to: $(VERSION)"
	@echo 
	@echo "If 'yes', then hit <Enter> to continue..."; \
	read i
	@echo 
	
	-git commit -m "prep for v$(VERSION)" -a
	-git tag v$(VERSION)
	mkdir -p    $(TOPDIR)/tmp/
	git clone . $(TOPDIR)/tmp/${package}-$(VERSION)/
	git log   > $(TOPDIR)/tmp/${package}-$(VERSION)/CHANGE.LOG
	rm -fr      $(TOPDIR)/tmp/${package}-$(VERSION)/.git
	perl -pi -e "s/^Version:.*/Version:      $(VERSION)/" $(TOPDIR)/tmp/${package}-$(VERSION)/rpm/${package}.spec
	find  $(TOPDIR)/tmp/${package}-$(VERSION) -type f -exec chmod ug+r  {} \;
	find  $(TOPDIR)/tmp/${package}-$(VERSION) -type d -exec chmod ug+rx {} \;
	cd    $(TOPDIR)/tmp/ && tar -ch ${package}-$(VERSION) | bzip2 > ${package}-$(VERSION).tar.bz2
	ls -l $(TOPDIR)/tmp/

.PHONY: clean
clean:
	rm -fr $(TOPDIR)/tmp/
	rm -fr $(TOPDIR)/usr/share/man/

.PHONY: distclean
distclean: clean
	rm -f  $(TOPDIR)/configure-stamp
	rm -f  $(TOPDIR)/build-stamp
	rm -f  $(TOPDIR)/debian/files
	rm -fr $(TOPDIR)/debian/${package}/

