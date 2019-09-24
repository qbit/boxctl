#	$OpenBSD$

PREFIX ?=	/usr/local
SCRIPT =	boxctl.sh
MAN =		man/boxctl.8
MANDIR ?=	${PREFIX}/man/man
BINDIR ?=	${PREFIX}/bin

README.md: man/boxctl.8
	mandoc -T lint man/boxctl.8
	mandoc -T markdown man/boxctl.8 >$@

sign:
	@sha256 boxctl.sh > SHA256
	@signify -S -s ~/signify/boxctl.sec -m SHA256 -x SHA256.sig
	@cat SHA256 >> SHA256.sig

verify:
	@signify -C -p /etc/signify/boxctl.pub -x SHA256.sig boxctl.sh

realinstall:
	${INSTALL} ${INSTALL_COPY} -o ${BINOWN} -g ${BINGRP} -m ${BINMODE} \
		${.CURDIR}/${SCRIPT} ${DESTDIR}${BINDIR}/boxctl

.PHONY: verify sign

.include <bsd.prog.mk>
