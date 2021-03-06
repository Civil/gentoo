# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="6"

# repoman gives LIVEVCS.unmasked even with EGIT_COMMIT, so create snapshot
inherit eutils java-pkg-2 # git-r3

L_PN="sbt-launch"
L_P="${L_PN}-${PV}"

SV="2.11"

DESCRIPTION="sbt is a build tool for Scala and Java projects that aims to do the basics well"
HOMEPAGE="https://www.scala-sbt.org/"
EGIT_COMMIT="v${PV}"
EGIT_REPO_URI="https://github.com/sbt/sbt.git"
SRC_URI="
	!binary? (
		https://dev.gentoo.org/~gienah/snapshots/${P}-src.tar.xz
		https://dev.gentoo.org/~gienah/snapshots/${P}-ivy2-deps.tar.xz
		https://dev.gentoo.org/~gienah/snapshots/${P}-sbt-deps.tar.xz
		http://repo.typesafe.com/typesafe/ivy-releases/org.scala-sbt/${L_PN}/${PV}/${L_PN}.jar -> ${L_P}.jar
	)
	binary? (
		https://dev.gentoo.org/~gienah/files/dist/${P}-gentoo-binary.tar.xz
	)"
LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="binary"

DEPEND=">=virtual/jdk-1.8
	>=dev-lang/scala-2.11.8:${SV}"
RDEPEND=">=virtual/jre-1.8
	>=dev-lang/scala-2.11.8:${SV}"

# test hangs or fails
RESTRICT="test"

JAVA_GENTOO_CLASSPATH="scala-${SV}"

# Note: to bump sbt, some things to try are:
# 1. Create the sbt src snapshot:
# git clone https://github.com/sbt/sbt.git ${P}
# cd ${P}
# git checkout v${PV}
# cd ..
# XZ_OPT=-9 tar --owner=portage --group=portage \
# -cJf /usr/portage/distfiles/${P}-src.tar.xz ${P}
# 2. remove the https://dev.gentoo.org/~gienah/snapshots/${P}-ivy2-deps.tar.xz
# https://dev.gentoo.org/~gienah/snapshots/${P}-sbt-deps.tar.xz and
# binary? ( https://dev.gentoo.org/~gienah/files/dist/${P}-gentoo-binary.tar.xz )
# from SRC_URI
# 3. Comment the sbt publishLocal line in src_compile.
# 4. try:
# FEATURES='noclean -test' emerge -v -1 dev-java/sbt
# It should fail in src_install since the sbt publishLocal is not done.
# Check if it downloads more stuff in
# src_compile to ${WORKDIR}/.ivy2 and ${WORKDIR}/.sbt.
# 5. If some of the downloads fail, it might be necessary to run the sbt compile
# again manually to obtain all the dependencies, if so:
# cd to ${S}
# export EROOT=/
# export WORKDIR='/var/tmp/portage/dev-java/${P}/work'
# export SV="2.11"
# export L_P=${P}
# export PATH="/usr/share/scala-${SV}/bin:${WORKDIR}/${L_P}:${PATH}"
# sbt compile
# cd ${WORKDIR}
# find .ivy2 .sbt -uid 0 -exec chown portage:portage {} \;
# 6. cd ${WORKDIR}
# XZ_OPT=-9 tar --owner=portage --group=portage \
# -cJf /usr/portage/distfiles/${P}-ivy2-deps.tar.xz .ivy2/cache
# XZ_OPT=-9 tar --owner=portage --group=portage \
# -cJf /usr/portage/distfiles/${P}-sbt-deps.tar.xz .sbt
# Uncomment the sbt publishLocal line in src_compile.
# 7. It *might* download more dependencies for src_test, however the presence
# of some of these may cause the src_compile to fail.  So download them
# seperately as root so we can identify the
# additional files.  As root:
# cd ${S}
# ${S}/${P} test
# cd ${WORKDIR}
# XZ_OPT=-9 tar --owner=portage --group=portage \
# -cJf /usr/portage/distfiles/${P}-test-deps.tar.xz \
# $(find .ivy2/cache .sbt -uid 0 -type f -print)
# Note: It might not download anything in src_test, in which case
# ${P}-test-deps.tar.xz is not required.
# 8. Create the binary
# cd $WORDKIR
# XZ_OPT=-9 tar --owner=portage --group=portage \
# -cJf /usr/portage/distfiles/${P}-gentoo-binary.tar.xz ${P} .ivy2/local
# 9. Undo the earlier temporary edits to the ebuild.

src_unpack() {
	# if ! use binary; then
	# 	git-r3_src_unpack
	# fi
	# Unpack tar files only.
	for f in ${A} ; do
		[[ ${f} == *".tar."* ]] && unpack ${f}
	done
}

src_prepare() {
	default
	if ! use binary; then
		mkdir "${WORKDIR}/${L_P}" || die
		cp -p "${DISTDIR}/${L_P}.jar" "${WORKDIR}/${L_P}/${L_PN}.jar" || die
		cat <<- EOF > "${WORKDIR}/${L_P}/sbt"
			#!/bin/sh
			SBT_OPTS="-Xms512M -Xmx1536M -Xss1M -XX:+CMSClassUnloadingEnabled"
			java -Djavac.args="-encoding UTF-8" -Duser.home="${WORKDIR}" \${SBT_OPTS} -jar "${WORKDIR}/${L_P}/sbt-launch.jar" "\$@"
		EOF
		cat <<- EOF > "${S}/${P}"
			#!/bin/sh
			SBT_OPTS="-Xms512M -Xmx1536M -Xss1M -XX:+CMSClassUnloadingEnabled"
			java -Djavac.args="-encoding UTF-8" -Duser.home="${WORKDIR}" \${SBT_OPTS} -jar "${S}/launch/target/sbt-launch.jar" "\$@"
		EOF
		chmod u+x "${WORKDIR}/${L_P}/sbt" "${S}/${P}" || die
		sed -e "s@scalaVersion := scala210,@scalaVersion := scala${SV/./},\n  scalaHome := Some(file(\"${EROOT}usr/share/scala-${SV}\")),@" \
			-i "${S}/build.sbt" || die

		# suppress this warning in build.log:
		# [warn] Credentials file /var/tmp/portage/dev-java/${P}/work/.bintray/.credentials does not exist
		mkdir -p "${WORKDIR}/.bintray" || die
		cat <<- EOF > "${WORKDIR}/.bintray/.credentials"
			realm = Bintray API Realm
			host = api.bintray.com
			user =
			password =
		EOF
	fi
}

src_compile() {
	if ! use binary; then
		export PATH="${EROOT}usr/share/scala-${SV}/bin:${WORKDIR}/${L_P}:${PATH}"
		einfo "=== sbt compile ..."
		"${WORKDIR}/${L_P}/sbt" -Dsbt.log.noformat=true compile || die
		einfo "=== sbt publishLocal with jdk $(java-pkg_get-vm-version) ..."
		cat <<- EOF | "${WORKDIR}/${L_P}/sbt" -Dsbt.log.noformat=true || die
			set every javaVersionPrefix in javaVersionCheck := Some("$(java-pkg_get-vm-version)")
			publishLocal
		EOF
	fi
}

src_test() {
	export PATH="${EROOT}usr/share/scala-${SV}/bin:${S}:${PATH}"
	"${S}/${P}" -Dsbt.log.noformat=true test || die
}

src_install() {
	# Place sbt-launch.jar at the end of the CLASSPATH
	java-pkg_dojar $(find "${WORKDIR}"/.ivy2/local -name \*.jar -print | grep -v sbt-launch.jar) \
				   $(find "${WORKDIR}"/.ivy2/local -name sbt-launch.jar -print)
	local ja="-Dsbt.version=${PV} -Xms512M -Xmx1536M -Xss1M -XX:+CMSClassUnloadingEnabled"
	java-pkg_dolauncher sbt --jar sbt-launch.jar --java_args "${ja}"
}
