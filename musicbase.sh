#!/bin/bash
set -e
print_help(){
cat << 'EOF'
A kid3-based utility to build a complete music library database. Requires both kid3-cli and kid3-qt.

Usage: musicbase.sh DIRPATH [option]

options:
-h display this help file
-m minimum subdirectory depth from top directory of music library to music files (default: 1)
-o specify output file name and path (default: $HOME/.musiclib.dsv)
-q quiet - hide terminal output

Generates a music library database using music file tag data with kid3-cli/kid3-qt export tools.
Processes data from music files at the DIRPATH specified. Filetype is data separated values (DSV)
with carat (^) as the delimiter. Database records include the path to each music file.

Time to complete varies by processor and can take >10 minutes for large libraries. Check output 
quality more quickly by testing on a subdirectory.

EOF
}

# Verify user provided required, valid path
if [ -z "$1" ]
  then
    printf  '%s\n' "Missing required argument: path to music directory."
    print_help
    exit 1
fi
if [ -d  "$1" ]; then
    libpath=$1
    shift
else
    if [ "$1" == "-h" ]; then
        print_help
        exit 1
    fi
    printf 'This directory does not exist: '
    printf '%s\n' "$1"    
    exit 1
fi

# Set default variables
dirdepth=1
outpath="$HOME/.musiclib.dsv"
showdisplay=1

# Use getops to set any user-assigned options
while getopts ":hm:o:q" opt; do
  case $opt in
    h) # display Help
      print_help
      exit 0;;
    m)
      dirdepth=$OPTARG
      shift
      ;;
    o)
      outpath=$OPTARG      
      ;;
    q)      
      showdisplay=0 >&2
      ;;
    \?)
      printf 'Invalid option: -%s' "$OPTARG\n"
      exit 1
      ;;
    :)
      printf 'Option requires an argument: %s' "$OPTARG\n"
      exit 1
      ;;
  esac
done

# Get list of music subdirectories, using first variable $libpath for library folder, e.g. /mnt/vboxfiles/music
find "$libpath" -mindepth "$dirdepth" -type d > /tmp/albumdirs;
if [ $showdisplay == 0 ] 
then
     printf '%s\n' "Locating all subdirectories under this path..." > /dev/null 2>&1
else 
    printf '%s\n' "Locating all subdirectories under this path..."
fi

# Verify kid3-qt 'musicbase' export format exists-> $HOME/.config/Kid3/Kid3.conf
# If exists is false, add export format to $HOME/.config/Kid3/Kid3.conf; otherwise skip and proceed
kid3confpath=$"$HOME/.config/Kid3/Kid3.conf"
exportcodes="%{catalognumber}^%{artist}^%{grouping}^%{album}^%{albumartist}^%{title}^%{filepath}^%{genre}^%{seconds}000^%{rating}^^%{songs-db_custom2}^%{work}"
if grep -q "musicbase" "$kid3confpath"
then 
    if grep -q "$exportcodes" "$kid3confpath"
    then
        printf ''
    else
       printf '%s\n' "A kid3-qt export format was found with the musicbase name, but its format is not a match. Delete this format in kid3-qt, then run musicbase again."
       exit               
    fi
else
    if [ $showdisplay == 0 ] 
    then
        printf '%s\n' "Adding the musicbase export format to kid3-qt configuration." > /dev/null 2>&1
    else 
        printf '%s\n' "Adding the musicbase export format to kid3-qt configuration."
    fi
    exportformatidx="$(grep -oP '(?<=ExportFormatIdx=)[0-9]+' "$kid3confpath")"
    # add comma and space to end of ExportFormatHeaders string
    sed -in '/^ExportFormatHeaders/ s/$/, /' "$kid3confpath"
    # add count of 1 to existing value of ExportFormatIdx
    (( exportformatidx++ ))
    sed -i '/ExportFormatIdx.*/c\ExportFormatIdx='"$exportformatidx" "$kid3confpath"
    # add comma, space and value 'musicbase' to end of ExportFormatNames string
    sed -in '/^ExportFormatNames/ s/$/, musicbase/' "$kid3confpath"
    # add comma, space and format string to end of ExportFormatTracks string
    sed -in '/^ExportFormatTracks/ s/$/, %{catalognumber}^%{artist}^%{grouping}^%{album}^%{albumartist}^%{title}^%{filepath}^%{genre}^%{seconds}000^%{rating}^^%{songs-db_custom2}^%{work}/' "$kid3confpath"
    # add comma and space to the end of ExportFormatTrailers string
    sed -in '/^ExportFormatTrailers/ s/$/, /' "$kid3confpath"
fi

# Build music library database
if [ $showdisplay == 0 ] 
then
     printf '%s\n' "Building database. This can take time for kid3-cli to process, especially for large music libraries..." > /dev/null 2>&1
else 
    printf '%s\n' "Building database. This can take time for kid3-cli to process, especially for large music libraries..."
fi
# This is for the spinner, to show the program is working
if [ $showdisplay == 1 ]
then
    i=1
    sp="/-\|"
    echo -n ' '
else 
    printf ''
fi
# Add header to the database file
echo  "ID^Artist^IDAlbum^Album^AlbumArtist^SongTitle^SongPath^Genre^SongLength^Rating^LastTimePlayed^Custom2^GroupDesc" > "$outpath"
# Loop through the albumdirs file using kid3-cli to read the tag info and add it to the database file, 
# while running the spinner to show operation
while IFS= read -r line; do   
    kid3-cli -c "export /tmp/musiclib.dsv musicbase '%{catalognumber}^%{artist}^%{grouping}^%{album}^%{albumartist}^%{title}^%{filepath}^%{genre}^%{seconds}000^%{rating}^^%{songs-db_custom2}^%{work}'" "$line"
    cat /tmp/musiclib.dsv >> "$outpath"
    if [ $showdisplay == 0 ] 
    then
        printf '' > /dev/null 2>&1
    else 
        printf '\b%s' "${sp:i++%${#sp}:1}"
    fi
done < /tmp/albumdirs

# Sort library order using file path column, preserving position of header, and replace library file
(head -n 1 "$outpath" && tail -n +2 "$outpath"  | sort -k7 -t '^') > /tmp/musiclib.dsv
cp /tmp/musiclib.dsv "$outpath"
if [ $showdisplay == 0 ] 
then
     printf '%s\n' "Finished! Output: $outpath" > /dev/null 2>&1
else 
    printf '%s\n' "Finished! Output: $outpath"
fi
#EOF
