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
all:  $(TOPDIR)/bin/* $(TOPDIR)/etc/init.d/*

.PHONY: install
install:  all
	test -d ${bindir} || install -d -m 755  ${bindir}
	install -m 755 $(TOPDIR)/bin/*			${bindir}
	
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
test_release:  tarball debs rpms
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
stable_release:  tarball debs rpms
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
	# Quick hack to get rpmbuild to work on Lucid -- was failing w/bzip2 archive
	# Turn it into a gz archive instead of just tar to avoid confusion about canonical archive -BEF-
	bzcat $(TOPDIR)/tmp/${package}-$(VERSION).tar.bz2 | gzip > $(TOPDIR)/tmp/${package}-$(VERSION).tar.gz 
	rpmbuild -ta $(TOPDIR)/tmp/${package}-$(VERSION).tar.gz
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

$(TOPDIR)/tmp/${package}-$(VERSION).tar.bz2:  clean
	@echo "Did you update the version and changelog info in?:"
	@echo 
	@echo '# Scrape-n-paste'
	@echo 'vim VERSION'
	@echo 'ver=$$(cat VERSION)'
	@echo 
	@echo '## deb pkg bits first'
	@echo '#git log `git describe --tags --abbrev=0`..HEAD --oneline > /tmp/${package}.gitlog'
	@echo '#while read line; do dch --newversion $$ver "$$line"; done < /tmp/${package}.gitlog'
	@echo '#dch --release "" --distribution stable --no-force-save-on-release'
	@echo '#head debian/changelog'
	@echo
	@echo '# RPM bits next'
	@echo 'perl -pi -e "s/^Version:.*/Version:      $$ver/" rpm/${package}.spec'
	@echo 'head rpm/${package}.spec'
	@echo '# dont worry about changelog entries in spec file for now...  #vim rpm/${package}.spec'
	@echo
	@echo '# commit changes and go'
	@echo 'git commit -m "prep for v$$ver" -a'
	@echo 'git tag v$$ver'
	@echo 
	@echo "If 'yes', then hit <Enter> to continue..."; \
	read i
	mkdir -p    $(TOPDIR)/tmp/
	git clone . $(TOPDIR)/tmp/${package}-$(VERSION)/
	git log   > $(TOPDIR)/tmp/${package}-$(VERSION)/CHANGE.LOG
	rm -fr      $(TOPDIR)/tmp/${package}-$(VERSION)/.git
	perl -pi -e "s/^Version:.*/Version:      $(VERSION)/" $(TOPDIR)/tmp/rpm/${package}.spec
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

