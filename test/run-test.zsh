#!/bin/zsh

if [[ "${1}" == "build" ]]; then
	docker build -t localpkg-test -f test/Dockerfile ${0:A:h}/..

	exit
fi

docker run -it --rm localpkg-test "${@}"
