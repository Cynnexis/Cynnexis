#!/bin/bash

# Convert SVG images to PNG using either Inkscape (if installed), or a Docker
# image that contains Inkscape.

set -euo pipefail

print_help() {
	echo 'svg2png - Convert SVG images to PNG using Inkscape'
	echo
	echo "usage: $0 [-i/--input=FILE...] [-o/--output=FILE...]"
	echo 'Arguments:'
	echo '  -h/--help   - Print this message and exits.'
	echo '  -i/--input  - Path to a SVG file or a folder containing SVG files. The given'
	echo '                SVG will be converted into PNG files. This arguments can be'
	echo '                given multiple times. Note that if a folder is given, it will'
	echo '                not search the images recursively.'
	echo '  -o/--output - File that will contain the converted image. Not that if multiple'
	echo '                input has been given, or the input if a folder containing'
	echo '                multiple SVG images, the output will be a directory.'
	echo '  -f/--force  - If given and the destination file already exists, it will be'
	echo '                overwritten. By default, and error is thrown.'
	echo '  --verbose   - Activate verbose.'
	echo
}

# List of possible environment variable that can contain the Inkscape executable
possible_inkscape_envs=(INKSCAPE_HOME INKSCAPE_DIR INKSCAPE_PATH)

inputs_arg=()
output_arg=''
force=
verbose=
for arg in "$@"; do
	case "$arg" in
		--help|-h)
			print_help
			;;
		-i=*|--input=*)
			inputs_arg+=("${arg#*=}")
			;;
		-o=*|--output=*)
			output_arg="${arg#*=}"
			;;
		-f|--force)
			force="true"
			;;
		--verbose)
			verbose="true"
			;;
		*)
			echo "Invalid argument: $arg" 1>&2
			print_help 1>&2
			exit 1
	esac
done

# Get SVG files
# TODO: DEBUG
#PS4=' ${BASH_SOURCE}:${LINENO} $ '
#set -x

input_files=()
for input_arg in "${inputs_arg[@]}"; do
	if [[ -r "$input_arg" ]]; then
		input_files+=("$input_arg")
	elif [[ -d "$input_arg" ]]; then
		while read -r svg_file; do
			if [[ -r "$svg_file" ]]; then
				input_files+=("$svg_file")
			elif [[ "$verbose" = 'true' ]]; then
				echo "WARNING: File \"$svg_file\" is not readable:" 1>&2
				ls -lha "$svg_file" 1>&2
			fi
		done < <(find . -type f -name '*.svg')
	elif [[ "$verbose" = 'true' ]]; then
		echo "WARNING: \"$input_arg\" is neither a readable file nor a directory:" 1>&2
		ls -lha "$svg_file" 1>&2
	fi
done

if [[ ${#input_files[@]} -eq 0 ]]; then
	if [[ "$verbose" = 'true' ]]; then
		echo "Nothing to do."
	fi
	exit 0
fi

# Detect Inkscape
INKSCAPE=()
# Check if in PATH
if command -v inkscape &> /dev/null; then
	INKSCAPE=(inkscape)
else
	# If not, try other environment variables
	for possible_env in "${possible_inkscape_envs[@]}"; do
		if [[ -v "$possible_env" && -n ${!possible_env} && -d ${!possible_env} ]]; then
			if [[ -x "${!possible_env}/inkscape" ]]; then
				INKSCAPE=("${!possible_env}/inkscape")
				break
			elif [[ "$verbose" = 'true' ]]; then
				echo "WARNING: Found the environment variable $possible_env=\"${!possible_env}\", but the directory doesn't contain a \"inkscape\" executable:" 1>&2
				ls -lha "${!possible_env}" 1>&2
			fi
		fi
	done
fi

# If still nothing, try with docker
if [[ ${#INKSCAPE[@]} -eq 0 ]]; then
	if command -v docker &> /dev/null && docker version &> /dev/null; then
		docker pull cynnexis/inkscape
		INKSCAPE=(docker run --name="inkscape-generate-png" --rm -iv "$(pwd):/root/cynnexis/" cynnexis/inkscape)
	fi
fi

# If still nothing, report error
if [[ ${#INKSCAPE[@]} -eq 0 ]]; then
	IFS=', ' echo "ERROR: Couldn't locate the inkscape executable, nor Docker. Please make sure that inkscape is either in your path, or in the following enviornment variable: [${possible_inkscape_envs[*]}]. You can also use Docker, but the daemon must be running before calling this script." 1>&2
	exit 1
fi

# If multiple inputs files, create the output folder
if [[ ${#input_files[@]} -gt 1 && -n $output_arg && ! -d $output_arg ]]; then
	mkdir -p "$output_arg"
fi

for input_file in "${input_files[@]}"; do
	# Get exported filepath
	exported_file_path=
	exported_file_name="${input_file%.svg}.png"
	if [[ -z $output_arg ]]; then
		exported_file_path=$exported_file_name
	elif [[ -d $output_arg ]]; then
		exported_file_path="$output_arg/$(basename "$exported_file_name")"
	else
		exported_file_path="$output_arg"
	fi

	if [[ $force != 'true' && -f $exported_file_path ]]; then
		echo "ERROR: Cannot export \"$input_file\" to \"$exported_file_path\" because file already exists." 1>&2
		exit 1
	fi

	# Export file
	[[ $verbose = 'true' ]]; set -x
	"${INKSCAPE[@]}" --export-overwrite -C --export-filename "/root/cynnexis/$exported_file_path" -w 1024 "/root/cynnexis/$input_file"
	{ set +x; } 2> /dev/null
done

if [[ $verbose = 'true' ]]; then
	echo "Done."
fi
