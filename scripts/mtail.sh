#!/usr/bin/env bash
#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Tails log lines from multiple pods (selected by label selector).
# Requires:
# - kubectl

set -eo pipefail

# Argument parsing generated online by https://argbash.io/generate
die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "$1" >&2
	exit "${_ret}"
}

begins_with_short_option()
{
	local first_option all_short_options='ckh'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_container=
_arg_colored_pods="on"
_arg_numberlines="10"

print_help ()
{
	printf '%s\n' "The general script's help msg"
	printf 'Usage: %s [-c|--container <arg>] [-k|--(no-)colored-pods] [-h|--help] <label-selector>\n' "$0"
	printf '\t%s\n' "<label-selector>: Label selector to use, comma separated, i.e. app=prometheus,tier=system"
	printf '\t%s\n' "-c,--container: specify container (no default)"
	printf '\t%s\n' "-k,--colored-pods,--no-colored-pods: use colored output for pod names (off by default)"
	printf '\t%s\n' "-h,--help: Prints help"
}

parse_commandline ()
{
	_positionals_count=0
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-c|--container)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_container="$2"
				shift
				;;
			--container=*)
				_arg_container="${_key##--container=}"
				;;
			-c*)
				_arg_container="${_key##-c}"
				;;
			-n*)
				_arg_numberlines="${_key##-n=}"
				;;
			-k|--no-colored-pods|--colored-pods)
				_arg_colored_pods="on"
				test "${1:0:5}" = "--no-" && _arg_colored_pods="off"
				;;
			-k*)
				_arg_colored_pods="on"
				_next="${_key##-k}"
				if test -n "$_next" -a "$_next" != "$_key"
				then
					{ begins_with_short_option "$_next" && shift && set -- "-k" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
				fi
				;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_last_positional="$1"
				_positionals+=("$_last_positional")
				_positionals_count=$((_positionals_count + 1))
				;;
		esac
		shift
	done
}

handle_passed_args_count ()
{
	local _required_args_string="'label-selector'"
	test "${_positionals_count}" -ge 1 || _PRINT_HELP=yes die "FATAL ERROR: Not enough positional arguments - we require exactly 1 (namely: $_required_args_string), but got only ${_positionals_count}." 1
	test "${_positionals_count}" -le 1 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect exactly 1 (namely: $_required_args_string), but got ${_positionals_count} (the last one was: '${_last_positional}')." 1
}

assign_positional_args ()
{
	local _positional_name _shift_for=$1
	_positional_names="_arg_label_selector "

	shift "$_shift_for"
	for _positional_name in ${_positional_names}
	do
		test $# -gt 0 || break
		eval "$_positional_name=\${1}" || die "Error during argument parsing, possibly an Argbash bug." 1
		shift
	done
}

parse_commandline "$@"
handle_passed_args_count
assign_positional_args 1 "${_positionals[@]}"

label_selector=${_positionals[0]}

# Set default color
pod_color=3

# Support more colors, for tailing a lot of pods
if [ ${_arg_colored_pods} == "on" ]; then
	export TERM=xterm-256color
fi

while IFS= read -r line; do
	pods+=("$line")
done < <(kubectl get pods -l="${label_selector}" -o=jsonpath='{range .items[*].metadata.name}{@}{"\n"}{end}')

for i in "${!pods[@]}"; do
	[ ${_arg_colored_pods} == "on" ] && pod_color=${i}
	(
		set -ex
		kubectl logs --follow "${pods[i]}" "${_arg_container}" --tail="${_arg_numberlines}" \
	) | sed "s/^/$(tput setaf "${pod_color}")[${pods[i]}] $(tput sgr0)/" &
done

trap "exit" INT TERM ERR
trap "kill 0" EXIT
wait
