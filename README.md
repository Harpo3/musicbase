# Musicbase - A kid3-based music library database creation utility.

Kid3-cli and kid3-qt based utility to build a complete music library database at once. 

The script uses the kid3-qt configuration file ($HOME/.config/Kid3/Kid3.conf) to set some albeit arbitrary format codes to establish record values and applies the format using kid3-cli. I plan to add user-level ability to set format codes according to need.

Requires both kid3-cli and kid3-qt.

syntax: musicbase.sh DIRPATH [-h] [-m MINDEPTH] [-o FILE] [q]

Generates a music library database using music file tag data and kid3-cli/Kid3-qt export tools.
Processes data from music files at the DIRPATH specified. File type is data separated values (DSV)\nwith carat (^) as the delimiter. Database records include the path to each music file.

Time to complete varies by processor and can take >10 minutes for large libraries. Check
output quality more quickly by testing on a subdirectory.

options:
 -h display this help file\n'
 -m minimum subdirectory depth from top directory of music library to music files (default: 1)\n'
 -o specify output file name and path (default: %s)\n' "\$HOME/.musiclib.dsv"
 -q quiet - hide terminal output\n'
