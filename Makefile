#
#  vi:set filetype=make noet ai tw=0:
#

SHELL = /bin/sh

#
# These settings are what I would expect for most modern Linux distros, 
# and are what work for me unmodified on Ubuntu. -BEF-
# 
package		= hpc-goodies
DESTDIR		= 
prefix		= /usr
exec_prefix	= ${prefix}
sbindir 	= ${exec_prefix}/sbin
initdir 	= /etc/init.d
datadir		= ${prefix}/share
mandir		= ${datadir}/man
docdir 		= ${datadir}/doc/${package}
libdir  	= ${prefix}/lib
pkglibdir	= ${libdir}/${package}
rpmbuild    = ~/rpmbuild

VERSION = $(shell cat VERSION)

TOPDIR := $(CURDIR)


.PHONY: all
all:  $(TOPDIR)/bin/* $(TOPDIR)/etc/init.d/* $(TOPDIR)/bin/c1eutil $(TOPDIR)/bin/set_dma_latency

.PHONY: install
install:  all
	test -d $(DESTDIR)${sbindir} || install -d -m 755  $(DESTDIR)${sbindir}
	install -m 755 $(TOPDIR)/bin/*			$(DESTDIR)${sbindir}/

	test -d $(DESTDIR)${initdir} || install -d -m 755	$(DESTDIR)${initdir}
	install -m 755 $(TOPDIR)/etc/init.d/*	$(DESTDIR)${initdir}/

	#
	# Libs
	#
	test -d $(DESTDIR)${pkglibdir} || install -d -m 755 $(DESTDIR)${pkglibdir}
	install -m 644 $(TOPDIR)/usr/lib/functions.sh $(DESTDIR)${pkglibdir}/
	#
	test -d $(DESTDIR)${docdir} || install -d -m 755 $(DESTDIR)${docdir}
	install -m 644 $(TOPDIR)/CREDITS  	$(DESTDIR)${docdir}/
	install -m 644 $(TOPDIR)/README  	$(DESTDIR)${docdir}/
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
	perl -pi -e "s/^Version:.*/Version: $(VERSION)/" $(TOPDIR)/tmp/${package}-$(VERSION)/${package}.spec
	find  $(TOPDIR)/tmp/${package}-$(VERSION) -type f -exec chmod ug+r  {} \;
	find  $(TOPDIR)/tmp/${package}-$(VERSION) -type d -exec chmod ug+rx {} \;
	cd    $(TOPDIR)/tmp/ && tar -ch ${package}-$(VERSION) | bzip2 > ${package}-$(VERSION).tar.bz2
	ls -l $(TOPDIR)/tmp/

.PHONY: dist
dist:
	-rm -rf $(TOPDIR)/${package}-$(VERSION)
	mkdir -p $(TOPDIR)/${package}-$(VERSION)
	git clone . $(TOPDIR)/${package}-$(VERSION)/
	git log   > $(TOPDIR)/${package}-$(VERSION)/CHANGE.LOG
	rm -fr      $(TOPDIR)/${package}-$(VERSION)/.git
	perl -pi -e "s/^Version:.*/Version: $(VERSION)/" $(TOPDIR)/${package}-$(VERSION)/${package}.spec
	chmod -R u+w,a+rX $(TOPDIR)/${package}-$(VERSION)
	tar -C $(TOPDIR) -jchf ${package}-$(VERSION).tar.bz2 ${package}-$(VERSION)
	-tar -C $(TOPDIR) -achf ${package}-$(VERSION).tar.xz ${package}-$(VERSION) 2>/dev/null
	-rm -rf $(TOPDIR)/${package}-$(VERSION)

.PHONY: clean
clean:
	-rm -fr $(TOPDIR)/tmp/ $(TOPDIR)/${package}-$(VERSION)
	-rm -fr $(TOPDIR)/usr/share/man/
	-rm -f $(TOPDIR)/${package}-$(VERSION).tar.* $(TOPDIR)/${package}-*.rpm

.PHONY: distclean
distclean: clean
	-rm -f  $(TOPDIR)/configure-stamp
	-rm -f  $(TOPDIR)/build-stamp
	-rm -f  $(TOPDIR)/debian/files
	-rm -fr $(TOPDIR)/debian/${package}/

