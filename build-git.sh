#! /bin/bash
set -e
set -x
project_root="$(realpath "${BASH_SOURCE%/*}")"
cpus=$(sysctl -n hw.ncpu)

source "${project_root}/build-props.sh"

if [[ -f "${project_root}/build-props-local.sh" ]]; then
	source "${project_root}/build-props-local.sh"
fi

if [[ ! -d "${project_root}/src/git/.git" ]]; then
	mkdir -p "${project_root}/src"
	git clone "${GIT_REPO}" "${project_root}/src/git"
else
	git -C "${project_root}/src/git" reset --hard HEAD
fi

if [[ -n "${GIT_VERSION}" ]]; then
	if ! git -C "${project_root}/src/git" checkout "v${GIT_VERSION}"; then
		git -C "${project_root}/src/git" pull
		git -C "${project_root}/src/git" checkout "v${GIT_VERSION}"
	fi
else
	git -C "${project_root}/src/git" checkout master
	git -C "${project_root}/src/git" pull
fi

version="$(git -C "${project_root}/src/git" describe)"

build_git() {
	local arch="${1}"

	export CFLAGS="-arch ${arch} -mmacosx-version-min=13"
	export LDFLAGS="-arch ${arch} -mmacosx-version-min=13"

	cd "${project_root}/src/git"
	make clean
	make configure
	./configure --prefix=/usr/local --without-tcltk --without-python --with-gitconfig="/usr/local/etc/gitconfig"
	make -j ${cpus} -l ${cpus} NO_PERL=1
	make -j ${cpus} -l ${cpus} strip
	make DESTDIR="${project_root}/build/${arch}" install
	mv "${project_root}/build/${arch}"/usr/local/* "${project_root}/build/${arch}/"
	rm -rf "${project_root}/build/${arch}/usr"
	cd contrib/credential/osxkeychain
	make clean
	make
	strip -x git-credential-osxkeychain
	cp git-credential-osxkeychain "${project_root}/build/${arch}/libexec/git-core/"
}

rm -rf "${project_root}/build"

build_git arm64
build_git x86_64

cd "${project_root}"

mkdir -p build/scripts

cat <<EOF > build/scripts/postinstall
#!/bin/bash
echo Installing git
EOF

tar_root="build/tar/git-${version}"

echo 'INSTALL_PREFIX="${INSTALL_PREFIX:=/usr/local}"' >> build/scripts/postinstall

find build/arm64 -type d -mindepth 1 | while read dir; do
	base_dir="${dir#build/arm64/}"
	mkdir -p "build/pkg/${base_dir}"
	mkdir -p "${tar_root}/${base_dir}"
	echo mkdir -p '"${INSTALL_PREFIX}/'${base_dir}'"' >> build/scripts/postinstall
done

prev_inode=""
src_file=""

export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

find build/arm64 -type f -exec stat -f "%i %N" {} \; |
awk '{print $1, length($2), $2}' |
sort -n -k1,1 -k2,2 -k3,3 | while read inode length path; do
	base_path="${path#build/arm64/}"

	if [[ "${inode}" != "${prev_inode}" ]]; then
		prev_inode="${inode}"
		src_file="${base_path}"
		x86_file="build/x86_64/${base_path}"
		if [[ "$(file -b --mime-type "$path")" == "application/x-mach-binary" ]]; then
			lipo -create -output "build/pkg/${base_path}" "${path}" "${x86_file}"

			if [[ -n "${CODE_SIGNING_IDENTITY}" ]]; then
				codesign --options runtime --force --sign "${CODE_SIGNING_IDENTITY}" "build/pkg/${base_path}"
			fi

			cp -la "build/pkg/${base_path}" "${tar_root}/${base_path}"
		else
			cp -la "${path}" "build/pkg/${base_path}"
			cp -la "${path}" "${tar_root}/${base_path}"
		fi
	else
		echo ln -f '"${INSTALL_PREFIX}/'${src_file}'"' '"${INSTALL_PREFIX}/'${base_path}'"' >> build/scripts/postinstall
		cp -la "build/arm64/${src_file}" "${tar_root}/${base_path}"
	fi
done 

mkdir -p "${project_root}/build/pkg/etc"
cp "${project_root}/gitconfig" "${project_root}/build/pkg/etc/gitconfig"

chmod +x build/scripts/postinstall

cd "${project_root}"

pkgbuild --root build/pkg --install-location /usr/local --scripts build/scripts --identifier org.git --version "${version}" --min-os-version 13.0 build/git-component.pkg

sed 's/VERSION/'"${version}"'/' < distribution.xml > build/distribution.xml

mkdir -p build/resources

cp "${project_root}/src/git/LGPL-2.1" build/resources/License

mkdir -p "${project_root}/dist"

sign_args=()

if [[ -n "${PKG_SIGNING_IDENTITY}" ]]; then
	sign_args+=("--sign" "${PKG_SIGNING_IDENTITY}")
fi

productbuild --distribution build/distribution.xml --package-path build --resources build/resources \
	"${sign_args[@]}" dist/git.pkg

if [[ -n "${APPLE_TEAM_ID}" && -n "${APPLE_ID}" && -n "${APPLE_ID_PASSWORD}" ]]; then
	echo "Submitting to Apple notarization service"
	xcrun notarytool submit dist/git.pkg \
  --apple-id "${APPLE_ID}" \
  --team-id "${APPLE_TEAM_ID}" \
  --password "${APPLE_ID_PASSWORD}" \
  --wait

	xcrun stapler staple dist/git.pkg
fi


cp "${project_root}/src/git/LGPL-2.1" build/tar/git-${version}/LICENSE

bsdtar --options xz:compression-level=9 -C build/tar -cJf dist/git.tar.xz git-${version}
