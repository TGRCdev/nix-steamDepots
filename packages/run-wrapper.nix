{ pkgs, dedicated-server }: ''
DATADIR="$PWD"

printUsage() {
echo "Usage: $0 -d /path/to/garrysmod-server-data -- <srcds_run args>"
echo "Flags:"
printf "\t--help || -h : Print usage and flags"
printf "\t--data-dir || -d : Path to a writable data folder of a Garry's Mod server"
exit 127
}

try_command() {
    if ! $@; then
        echo "ERROR: Failed to run command. Please check that the data directory is write-able".
        exit 1
    fi
}

try_mkdir() {
    try_command mkdir -p $DATADIR/$1
}

try_if_not_exist_mkdir() {
    if [ ! -d $DATADIR/$1 ]; then
        echo "Creating $1 dir"
        try_mkdir $1
    fi
}

try_if_not_exist_mkdir_and_link_contents() {
    if [ ! -d $DATADIR/$1 ]; then
        echo "Creating $1 dir"
        try_mkdir $1
        echo "Checking for ${dedicated-server}/garrysmod/$1"
        if [ -d ${dedicated-server}/garrysmod/$1 -a ! -z "$(ls -A ${dedicated-server}/garrysmod/$1)" ]; then
            echo "Linking contents of $1"
            ln -s ${dedicated-server}/garrysmod/$1/* $DATADIR/$1
        fi
    fi
}

deep_link() {
    oldmask=$(umask)
    umask 077
    cp --no-preserve=mode,ownership -r -s "$1"/* "$2" 2>/dev/null
    umask $oldmask
}

while true; do
case $1 in
    -h | --help)
        printUsage
        shift
    ;;
    -d | --data-dir)
        DATADIR=$(realpath "$2")
        shift 2
    ;;
    --)
        shift
        break;
    ;;
    *)
        if [ -z "$1" ]; then shift; break; fi
        echo "Unknown argument \"$1\""
        printUsage
    ;;
esac
done

umask 077

echo "Data dir: $DATADIR"
echo "Setting up data dir. We will make required directories and, if needed, copy default configuration files."
try_if_not_exist_mkdir_and_link_contents maps
try_if_not_exist_mkdir_and_link_contents backgrounds
try_if_not_exist_mkdir_and_link_contents gamemodes
try_if_not_exist_mkdir_and_link_contents materials
try_if_not_exist_mkdir_and_link_contents lua
try_if_not_exist_mkdir_and_link_contents scenes
try_if_not_exist_mkdir_and_link_contents models
try_if_not_exist_mkdir_and_link_contents scripts/vehicles
try_if_not_exist_mkdir_and_link_contents particles
try_if_not_exist_mkdir_and_link_contents sound
try_if_not_exist_mkdir_and_link_contents resource/fonts
try_if_not_exist_mkdir_and_link_contents resource/localization
try_if_not_exist_mkdir addons
try_if_not_exist_mkdir cache
try_if_not_exist_mkdir steam_cache

try_if_not_exist_mkdir cfg
echo "Checking for missing configurations"
for cfg in ${dedicated-server}/garrysmod/cfg/*; do
    if [ ! -e "$DATADIR/cfg/$(basename $cfg)" ]; then
        try_command cp --no-preserve=mode,ownership -Lv --no-clobber $cfg $DATADIR/cfg/
    fi
done

FAKEDIR=$(mktemp -d)
echo "Fake directory at $FAKEDIR. We will trick srcds into believing this is the write-able Garry's Mod dedicated server folder."

mkdir $FAKEDIR/garrysmod

echo "Linking data directory contents"
ln -s $DATADIR/steam_cache $FAKEDIR/
ln -s $DATADIR/addons $DATADIR/cache $DATADIR/data $FAKEDIR/garrysmod/
deep_link $DATADIR $FAKEDIR/garrysmod

echo "Linking dedicated server contents"
deep_link ${dedicated-server} $FAKEDIR/

echo "Running srcds_run"

$FAKEDIR/srcds_run "$@"
''