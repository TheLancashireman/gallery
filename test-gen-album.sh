#!/bin/sh

export REQUEST_METHOD="GET"
export QUERY_STRING="ancient&image=0"
export SCRIPT_NAME="gen-album.pl"
export DOCUMENT_ROOT="/data/mirror/thelancashireman.org/"

./gen-album.pl
