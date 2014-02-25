#
# 	2013.10.11 Brian Finley <bfinley@us.ibm.com>
#	- improve version handling
# 	2013.11.07 Brian Finley <bfinley@us.ibm.com>
#	- include ./var/*
#   - better handling of version setting in included progs
#   - put user docs, etc all in one place
#

PKG_NAME 	:= hpc_goodies
RELEASE_ARCHIVE := ~/src/release_archive

MAJOR_VER 	:= $(shell git describe --tags | sed -e 's/^v//' -e 's/-.*//')
MAJOR_VER   ?= 0

MINOR_VER	:= $(shell git describe --tags | sed -e 's/^v[0-9]*-//' -e 's/-.*//')
MINOR_VER   ?= 0

PATCH_VER	:= $(shell git describe --tags | sed -e 's/^v[0-9]*-[0-9]*-//' -e 's/-.*//')
PATCH_VER   ?= 0

AUTO_VER	:= $(shell git describe --tags | sed -e 's/^v[0-9]*-[0-9]*-[0-9]*-//' -e 's/-.*//')
AUTO_VER    ?= 0

# In case we have made commits (AUTO_VER) since updating a PATCH_VER in
# the tag. -BEF-
PATCH_VER	:= $(shell echo "$$(( $(PATCH_VER) + $(AUTO_VER) ))" )

VERSION     := ${MAJOR_VER}.${MINOR_VER}.${PATCH_VER}

TMPDIR 		:= $(shell mktemp -d)
SPECFILE 	:= $(shell mktemp)
PKG_DIR     := ${PKG_NAME}-${VERSION}
TARBALL		:= /tmp/${PKG_DIR}.tar.bz2

.PHONY += all
all: c1eutil

c1eutil: c1eutil/c1eutil.c

.PHONY += install
install:
	mkdir -p             				${PREFIX}/usr/sbin/
	install -m 755 sbin/*				${PREFIX}/usr/sbin/
	
	#mkdir -p            				${PREFIX}/usr/share/${PKG_NAME}/
	#install -m 644 doc/*				${PREFIX}/usr/share/${PKG_NAME}/
	
	#mkdir -p ${PREFIX}/usr/share/doc/${PKG_DIR}/
	#echo "See the files in /usr/share/${PKG_NAME}/" > ${PREFIX}/usr/share/doc/${PKG_DIR}/README

.PHONY += tarball
tarball:
	
	#
	# Make a copy of the repo
	git clone . ${TMPDIR}/${PKG_DIR}
	/bin/rm -fr ${TMPDIR}/${PKG_DIR}/.git

	#
	# Copy this file over (for testing only)
	/bin/cp Makefile ${TMPDIR}/${PKG_DIR}/
	
	#
	# Create an RPM appropriate Makefile
	cp ${TMPDIR}/${PKG_DIR}/Makefile 								${TMPDIR}/${PKG_DIR}/Makefile.rpm
	perl -pi -e "s/^MAJOR_VER\s+.*/MAJOR_VER := ${MAJOR_VER}/g" 	${TMPDIR}/${PKG_DIR}/Makefile.rpm
	perl -pi -e "s/^MINOR_VER\s+.*/MINOR_VER := ${MINOR_VER}/g" 	${TMPDIR}/${PKG_DIR}/Makefile.rpm
	perl -pi -e "s/^PATCH_VER\s+.*/PATCH_VER := ${PATCH_VER}/g" 	${TMPDIR}/${PKG_DIR}/Makefile.rpm
	
	#
	# Version the Files
	perl -pi -e "s/__VERSION__/${VERSION}/g"  					        ${TMPDIR}/${PKG_DIR}/${PKG_NAME}.spec
	
	#
	# Tar it up
	cd ${TMPDIR} && tar -cvjf ${TARBALL} ${PKG_DIR}

.PHONY += rpm
rpm:	tarball
	rpmbuild -ta ${TARBALL}

.PHONY += release
release:	rpm
	mkdir -p ${RELEASE_ARCHIVE}
	cp -i ~/rpmbuild/RPMS/noarch/${PKG_NAME}-${VERSION}-1.noarch.rpm    ${RELEASE_ARCHIVE}
	cp -i ~/rpmbuild/SRPMS/${PKG_NAME}-${VERSION}-1.src.rpm             ${RELEASE_ARCHIVE}
	cp -i ${TARBALL}                                                    ${RELEASE_ARCHIVE}
	@echo
	@echo "Results:"
	@/bin/ls -1 ${RELEASE_ARCHIVE}/${PKG_NAME}-${VERSION}* | sed 's/^/  /'

.PHONY += help
help:
	@echo "Targets include:"
	@echo "  help"
	@echo "  rpm"
	@echo "  tarball"
	@echo "  all"
	@echo "  install"
