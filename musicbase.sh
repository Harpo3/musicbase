#!/bin/bash
set -e
print_help(){
cat << 'EOF'

A kid3-based utility to build a complete music library database. Requires both kid3-cli and kid3-qt.

Usage: musicbase.sh DIRPATH [option]

options:
-h display this help file
-k user-defined header string with delimiters
-l user-defined format codes with delimiters
-m minimum subdirectory depth from top directory of music library to music files (default: 1)
-n no database header
-o specify output file name and path (default: $HOME/.musiclib.dsv)
-q quiet - hide terminal output

Generates a music library database using music file tag data with kid3-cli/kid3-qt export tools.
Processes data from music files at the DIRPATH specified. Default output filetype is data separated 
values (DSV) with carat (^) as the delimiter. Database records include the path to each music file.

Default header and format codes can be overridden using -k and -l options. 

Defaults:
"Artist^Album^AlbumArtist^SongTitle^SongPath^Genre^SongLength^Rating"
"%{artist}^%{album}^%{albumartist}^%{title}^%{filepath}^%{genre}^%{seconds}000^%{rating}"

Time to complete varies by processor and can take >10 minutes for large libraries. Check output 
quality more quickly by testing on a subdirectory.

EOF
}

kid3qtrunning(){
# Determine whether kid3-qt is running, prompt user to close and continue processing
local kidrunning="$(ps aux | grep "kid3-qt" | grep -v "grep")"
if ! [ -z "$kidrunning" ]
then
    # prompt user to kill kid3-qt or exit program
    echo -n "Kid3-qt cannot be running for this utility to work. Close kid3-qt now ([Y]/n)?"
    read -r proceed
    if [ "$proceed" == "${proceed#[Yn]}" ] 
    then
        local PID="$(pidof kid3-qt)"
        kill -s HUP $PID
    else
        printf 'Goodbye, then.\n'
        exit 0
    fi
fi
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
kid3confpath=$"$HOME/.config/Kid3/Kid3.conf"
dirdepth=1
outpath="$HOME/.musiclib.dsv"
showdisplay=1
inclheader=1
defheader="Artist^Album^AlbumArtist^SongTitle^SongPath^Genre^SongLength^Rating"
exportcodes="%{artist}^%{album}^%{albumartist}^%{title}^%{filepath}^%{genre}^%{seconds}000^%{rating}"

# Use getops to set any user-assigned options
while getopts ":hk:l:m:no:q" opt; do
  case $opt in
    h) # display Help
      print_help
      exit 0;;
    k)
      defheader=$OPTARG            
      ;;
    l)
      exportcodes=$OPTARG      
      shift
      ;;
    m)
      dirdepth=$OPTARG
      shift
      ;;
    n)
      inclheader=0 >&2
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

# Verify kid3-qt is not running
kid3qtrunning

# Get list of music subdirectories, using first variable $libpath for library folder, e.g. /mnt/vboxfiles/music
find "$libpath" -mindepth "$dirdepth" -type d > /tmp/albumdirs;
if [ $showdisplay == 0 ] 
then
     printf '%s\n' "Locating all subdirectories under this path..." > /dev/null 2>&1
else 
    printf '%s\n' "Locating all subdirectories under this path..."
fi

# Backup kid3-qt config-> $HOME/.config/Kid3/Kid3.conf to /tmp
cp $HOME/.config/Kid3/Kid3.conf /tmp

# Add musicbase export format to $HOME/.config/Kid3/Kid3.conf
exportformatidx="$(grep -oP '(?<=ExportFormatIdx=)[0-9]+' "$kid3confpath")"
# add comma and space to end of ExportFormatHeaders string
sed -in '/^ExportFormatHeaders/ s/$/, /' "$kid3confpath"
# add count of 1 to existing value of ExportFormatIdx
(( exportformatidx++ ))
sed -i '/ExportFormatIdx.*/c\ExportFormatIdx='"$exportformatidx" "$kid3confpath"
# add comma, space and value 'musicbase' to end of ExportFormatNames string
sed -in '/^ExportFormatNames/ s/$/, musicbase/' "$kid3confpath"
# add comma, space and format string to end of ExportFormatTracks string
sed -in '/^ExportFormatTracks/ s/$/, '"$exportcodes"'/' "$kid3confpath"
# add comma and space to the end of ExportFormatTrailers string
sed -in '/^ExportFormatTrailers/ s/$/, /' "$kid3confpath"

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
if [ $inclheader == 1 ]
then
    echo  "$defheader" > "$outpath"
else
    rm "$outpath"
fi
# Loop through the albumdirs file using kid3-cli to read the tag info and add it to the database file, 
# while running the spinner to show operation
while IFS= read -r line; do   
    kid3-cli -c "export /tmp/musiclib.dsv musicbase "$exportcodes"" "$line"
    cat /tmp/musiclib.dsv >> "$outpath"
    if [ $showdisplay == 0 ] 
    then
        printf '' > /dev/null 2>&1
    else 
        printf '\b%s' "${sp:i++%${#sp}:1}"
    fi
done < /tmp/albumdirs

# Sort library order using file path column, preserving position of header, and replace library file
if [ $inclheader == 1 ]
then
    (head -n 1 "$outpath" && tail -n +2 "$outpath"  | sort -k7 -t '^') > /tmp/musiclib.dsv
else # do not preserve header, not used
    (tail -n +2 "$outpath"  | sort -k7 -t '^') > /tmp/musiclib.dsv
fi
cp /tmp/musiclib.dsv "$outpath"
if [ $showdisplay == 0 ] 
then
     printf '%s\n' "Finished! Output: $outpath" > /dev/null 2>&1
else 
    printf '%s\n' "Finished! Output: $outpath"
fi
rm /tmp/musiclib.dsv
# Replace $HOME/.config/Kid3/Kid3.conf with backed up tmp copy
rm $HOME/.config/Kid3/Kid3.conf
cp /tmp/Kid3.conf $HOME/.config/Kid3
#EOF
