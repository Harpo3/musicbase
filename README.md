# Musicbase - A kid3-based music library database creation utility.

Kid3-cli and kid3-qt based utility to build a complete music library database at once. 

The script uses the kid3-qt configuration file ($HOME/.config/Kid3/Kid3.conf) to set default format codes to establish record values and applies the format using kid3-cli. Users can specify their own format codes and headers.

Usage: musicbase.sh DIRPATH [option]

options:
-h display this help file

-k user-defined header string with delimiters

-l user-defined format codes with delimiters

-m minimum subdirectory depth from top directory of music library to music files (default: 1)

-n no database header

-o specify output file name and path (default: $HOME/.musiclib.dsv)

-q quiet - hide terminal output

-s sort database output by specified column number

Generates a music library database using music file tag data with kid3-cli/kid3-qt export tools.
Processes data from music files at the DIRPATH specified. Default output filetype is data separated 
values (DSV) with carat (^) as the delimiter. Database records include the path to each music file.

Default header and format codes can be overridden using -k and -l options. 

Defaults:
"Artist^Album^AlbumArtist^SongTitle^SongPath^Genre^SongLength^Rating"
"%{artist}^%{album}^%{albumartist}^%{title}^%{filepath}^%{genre}^%{seconds}000^%{rating}"

Time to complete varies by processor and can take >10 minutes for large libraries. Check output 
quality more quickly by testing on a subdirectory.
