# $ vimgit             # open all files with differences to HEAD
# $ vimgit 30ca7d10d3  # open all files of commit 30ca7d10d3
vimgit() {
	GITROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
	if [[ $? -ne 0 ]]; then
		$EDITOR "$@"
		return $?
	fi

	if [[ $# -eq 0 ]]; then
		$EDITOR $(git status --short | awk '$1 ~ /^M|A|U/ {print $2}')
	else
		(cd "$GITROOT"; $EDITOR $(git diff-tree --no-commit-id --name-only -r "$1"))
	fi
}
