#!/bin/bash
set -e
# Help                                                     #
############################################################
Help()
{
   # Display Help
   printf  '\n'
   printf  'Musicbase - A kid3-based music library database creation utility.\n'
   printf  'syntax: musicbase.sh DIRPATH [-a] [-h] [-m MINDEPTH] [-o OUTPUTPATH] [q]\n\n'
   printf  'Generate a music library database using music file tag data with formatting using Kid3-qt where DIRPATH is top of music library directory\n\n'
   printf  'options:\n'
   printf  ' -a use Archsimian-generated database (MediaMonkey)\n'
   printf  ' -h display this help file\n'
   printf  ' -m minimum subdirectory depth from top directory of music library to music files (default: 2)\n'
   printf  ' -o specify output file name and path. Default is %s\n' "$HOME/.musiclib.dsv"
   printf  ' -q quiet - hide terminal output\n'
   printf  '\n'
}
if [ -z "$1" ]
  then
    printf  '\nMissing required argument: path to music directory.\n'
    Help
    exit 1
fi
if [ -d  "$1" ]; then
    libpath=$1
    shift
else
    if [ "$1" == "-h" ]; then
        Help
        exit 1
    fi
    printf 'This directory does not exist: '
    printf '%s\n' "$1"    
    exit 1
fi
archsimiandb=0
dirdepth=2
outpath="$HOME/.musiclib.dsv"
showdisplay=1
while getopts ":ahm:o:q" opt; do
  case $opt in
    a)
      archsimiandb=1 >&2
      ;;
    h) # display Help
      Help
      exit;;
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
      printf 'Invalid option: -%s\n' "$OPTARG"
      exit 1
      ;;
    :)
      printf 'Option -%s requires an argument.\n' "$OPTARG"
      exit 1
      ;;
  esac
done
# Get list of music subdirectories containing music files, using first variable $0 for library folder, e.g. /mnt/vboxfiles/music

find "$libpath" -mindepth "$dirdepth" -type d > "$HOME"/.albumdirs;
if [ $showdisplay == 0 ] 
then
     printf 'Locating all subdirectories under this path...\n' > /dev/null 2>&1
else 
    printf 'Locating all subdirectories under this path...\n'
fi

# Add code to verify kid3-qt 'musicbase' export format exists in $HOME/.config/Kid3/Kid3.conf
# If exists is false, add export format to $HOME/.config/Kid3/Kid3.conf; otherwise skip and proceed
kid3confpath=$"$HOME/.config/Kid3/Kid3.conf"

# Check for existing musicbase export format in kid3-qt configration file, and create if missing
if grep -q "musicbase" "$kid3confpath"
then 
    if grep -q "%{catalognumber}^%{artist}^%{grouping}^%{album}^%{albumartist}^%{title}^%{filepath}^%{genre}^%{seconds}000^%{rating}^^%{songs-db_custom2}^%{work}" "$kid3confpath"
    then
        printf ''
    else
       printf 'A kid3-qt export format was found with the musicbase name, but its format is not a match. Delete this format in kid3-qt, then run musicbase again.\n'
       exit               
    fi
else
    if [ $showdisplay == 0 ] 
    then
        printf 'Adding the musicbase export format to kid3-qt configuration.\n' > /dev/null 2>&1
    else 
        printf 'Adding the musicbase export format to kid3-qt configuration.\n'
    fi
    exportformatidx="$(grep -oP '(?<=ExportFormatIdx=)[0-9]+' "$kid3confpath")"
    # add comma and space to end of ExportFormatHeaders string
    sed -in '/^ExportFormatHeaders/ s/$/, /' "$kid3confpath"
    # add count of 1 to existing value of ExportFormatIdx
    exportformatidx=$((exportformatidx+1))
    sed -i '/ExportFormatIdx.*/c\ExportFormatIdx='"$exportformatidx" "$kid3confpath"
    # add comma, space and value 'musicbase' to end of ExportFormatNames string
    sed -in '/^ExportFormatNames/ s/$/, musicbase/' "$kid3confpath"
    # add comma, space and format string to end of ExportFormatTracks string
    sed -in '/^ExportFormatTracks/ s/$/, %{catalognumber}^%{artist}^%{grouping}^%{album}^%{albumartist}^%{title}^%{filepath}^%{genre}^%{seconds}000^%{rating}^^%{songs-db_custom2}^%{work}/' "$kid3confpath"
    # add comma and space to the end of ExportFormatTrailers string
    sed -in '/^ExportFormatTrailers/ s/$/, /' "$kid3confpath"
fi
# Start database creation
if [ $showdisplay == 0 ] 
then
     printf 'Building database. This can take time for kid3-cli to process, especially for large music libraries...\n' > /dev/null 2>&1
else 
    printf 'Building database. This can take time for kid3-cli to process, especially for large music libraries...\n'
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
        printf "\b${sp:i++%${#sp}:1}"
    fi
done < "$HOME"/.albumdirs

# Sort library using file path column, preserving position of header, and replace library file
(head -n 1 "$outpath" && tail -n +2 "$outpath"  | sort -k7 -t '^') > /tmp/musiclib.dsv
cp /tmp/musiclib.dsv "$outpath"
if [ $showdisplay == 0 ] 
then
     printf 'Finished! Output: %s\n\n' > /dev/null 2>&1"$outpath"
else 
    printf 'Finished! Output: %s\n\n' "$outpath"
fi
#EOF
