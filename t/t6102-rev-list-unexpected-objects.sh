#!/bin/sh

test_description='git rev-list should handle unexpected object types'

. ./test-lib.sh

test_expect_success 'setup well-formed objects' '
	blob="$(printf "foo" | git hash-object -w --stdin)" &&
	tree="$(printf "100644 blob $blob\tfoo" | git mktree)" &&
	commit="$(git commit-tree $tree -m "first commit")" &&
	git cat-file commit $commit >good-commit
'

test_expect_success 'setup unexpected non-blob entry' '
	printf "100644 foo\0$(echo $tree | hex2oct)" >broken-tree &&
	broken_tree="$(git hash-object -w --literally -t tree broken-tree)"
'

test_expect_failure 'traverse unexpected non-blob entry (lone)' '
	test_must_fail git rev-list --objects $broken_tree
'

test_expect_success 'traverse unexpected non-blob entry (seen)' '
	test_must_fail git rev-list --objects $tree $broken_tree >output 2>&1 &&
	test_i18ngrep "is not a blob" output
'

test_expect_success 'setup unexpected non-tree entry' '
	printf "40000 foo\0$(echo $blob | hex2oct)" >broken-tree &&
	broken_tree="$(git hash-object -w --literally -t tree broken-tree)"
'

test_expect_success 'traverse unexpected non-tree entry (lone)' '
	test_must_fail git rev-list --objects $broken_tree >output 2>&1 &&
	test_i18ngrep "not a tree" output
'

test_expect_success 'traverse unexpected non-tree entry (seen)' '
	test_must_fail git rev-list --objects $blob $broken_tree >output 2>&1 &&
	test_i18ngrep "is not a tree" output
'

test_expect_success 'setup unexpected non-commit parent' '
	sed "/^author/ { h; s/.*/parent $blob/; G; }" <good-commit \
		>broken-commit &&
	broken_commit="$(git hash-object -w --literally -t commit \
		broken-commit)"
'

test_expect_success 'traverse unexpected non-commit parent (lone)' '
	test_must_fail git rev-list --objects $broken_commit >output 2>&1 &&
	test_i18ngrep "not a commit" output
'

test_expect_success 'traverse unexpected non-commit parent (seen)' '
	test_must_fail git rev-list --objects $blob $broken_commit \
		>output 2>&1 &&
	test_i18ngrep "not a commit" output
'

test_expect_success 'setup unexpected non-tree root' '
	sed -e "s/$tree/$blob/" <good-commit >broken-commit &&
	broken_commit="$(git hash-object -w --literally -t commit \
		broken-commit)"
'

test_expect_success 'traverse unexpected non-tree root (lone)' '
	test_must_fail git rev-list --objects $broken_commit
'

test_expect_success 'traverse unexpected non-tree root (seen)' '
	test_must_fail git rev-list --objects $blob $broken_commit \
		>output 2>&1 &&
	test_i18ngrep "not a tree" output
'

test_expect_success 'setup unexpected non-commit tag' '
	git tag -a -m "tagged commit" tag $commit &&
	git cat-file tag tag >good-tag &&
	test_when_finished "git tag -d tag" &&
	sed -e "s/$commit/$blob/" <good-tag >broken-tag &&
	tag=$(git hash-object -w --literally -t tag broken-tag)
'

test_expect_success 'traverse unexpected non-commit tag (lone)' '
	test_must_fail git rev-list --objects $tag
'

test_expect_success 'traverse unexpected non-commit tag (seen)' '
	test_must_fail git rev-list --objects $blob $tag >output 2>&1 &&
	test_i18ngrep "not a commit" output
'

test_expect_success 'setup unexpected non-tree tag' '
	git tag -a -m "tagged tree" tag $tree &&
	git cat-file tag tag >good-tag &&
	test_when_finished "git tag -d tag" &&
	sed -e "s/$tree/$blob/" <good-tag >broken-tag &&
	tag=$(git hash-object -w --literally -t tag broken-tag)
'

test_expect_success 'traverse unexpected non-tree tag (lone)' '
	test_must_fail git rev-list --objects $tag
'

test_expect_success 'traverse unexpected non-tree tag (seen)' '
	test_must_fail git rev-list --objects $blob $tag >output 2>&1 &&
	test_i18ngrep "not a tree" output
'

test_expect_success 'setup unexpected non-blob tag' '
	git tag -a -m "tagged blob" tag $blob &&
	git cat-file tag tag >good-tag &&
	test_when_finished "git tag -d tag" &&
	sed -e "s/$blob/$commit/" <good-tag >broken-tag &&
	tag=$(git hash-object -w --literally -t tag broken-tag)
'

test_expect_failure 'traverse unexpected non-blob tag (lone)' '
	test_must_fail git rev-list --objects $tag
'

test_expect_success 'traverse unexpected non-blob tag (seen)' '
	test_must_fail git rev-list --objects $commit $tag >output 2>&1 &&
	test_i18ngrep "not a blob" output
'

test_expect_success 'setup unexpected non-tag tag' '
	test_when_finished "git tag -d tag-commit tag-tag" &&

	git tag -a -m"tagged commit" tag-commit $commit &&
	tag_commit=$(git rev-parse tag-commit) &&
	git tag -a -m"tagged tag" tag-tag tag-commit &&
	tag_tag=$(git rev-parse tag-tag) &&

	git cat-file tag tag-tag >good-tag-tag &&
	git cat-file tag tag-commit >good-commit-tag &&

	sed -e "s/$tag_commit/$commit/" <good-tag-tag >broken-tag-tag-commit &&
	sed -e "s/$tag_commit/$tree/" <good-tag-tag >broken-tag-tag-tree &&
	sed -e "s/$tag_commit/$blob/" <good-tag-tag >broken-tag-tag-blob &&

	sed -e "s/$commit/$tag_commit/" <good-commit-tag >broken-commit-tag-tag &&
	sed -e "s/$commit/$tree/" <good-commit-tag >broken-commit-tag-tree &&
	sed -e "s/$commit/$blob/" <good-commit-tag >broken-commit-tag-blob &&

	tag_tag_commit=$(git hash-object -w -t tag broken-tag-tag-commit) &&
	tag_tag_tree=$(git hash-object -w -t tag broken-tag-tag-tree) &&
	tag_tag_blob=$(git hash-object -w -t tag broken-tag-tag-blob) &&

	commit_tag_tag=$(git hash-object -w -t tag broken-commit-tag-tag) &&
	commit_tag_tree=$(git hash-object -w -t tag broken-commit-tag-tree) &&
	commit_tag_blob=$(git hash-object -w -t tag broken-commit-tag-blob)
'

test_expect_success 'traverse unexpected incorrectly typed tag (to commit & tag)' '
	test_must_fail git rev-list --objects $tag_tag_commit 2>err &&
	cat >expected <<-EOF &&
	error: object $commit is a tag, not a commit
	fatal: bad object $commit
	EOF
	test_cmp expected err &&

	test_must_fail git rev-list --objects $commit_tag_tag 2>err &&
	cat >expected <<-EOF &&
	error: object $tag_commit is a commit, not a tag
	fatal: bad object $tag_commit
	EOF
	test_cmp expected err
'

test_expect_success 'traverse unexpected incorrectly typed tag (to tree)' '
	test_must_fail git rev-list --objects $tag_tag_tree 2>err &&
	cat >expected <<-EOF &&
	error: object $tree is a tag, not a tree
	fatal: bad object $tree
	EOF
	test_cmp expected err &&

	test_must_fail git rev-list --objects $commit_tag_tree 2>err &&
	cat >expected <<-EOF &&
	error: object $tree is a commit, not a tree
	fatal: bad object $tree
	EOF
	test_cmp expected err
'

test_expect_success 'traverse unexpected incorrectly typed tag (to blob)' '
	test_must_fail git rev-list --objects $tag_tag_blob 2>err &&
	cat >expected <<-EOF &&
	error: object $blob is a tag, not a blob
	fatal: bad object $blob
	EOF
	test_cmp expected err &&

	test_must_fail git rev-list --objects $commit_tag_blob 2>err &&
	cat >expected <<-EOF &&
	error: object $blob is a commit, not a blob
	fatal: bad object $blob
	EOF
	test_cmp expected err
'

test_expect_success 'traverse unexpected non-tag tag (tree seen to blob)' '
	test_must_fail git rev-list --objects $tree $commit_tag_blob 2>err &&
	cat >expected <<-EOF &&
	error: object $blob is a commit, not a blob
	fatal: bad object $blob
	EOF
	test_cmp expected err &&

	test_must_fail git rev-list --objects $tree $tag_tag_blob 2>err &&
	cat >expected <<-EOF &&
	error: object $blob is a tag, not a blob
	fatal: bad object $blob
	EOF
	test_cmp expected err
'

test_expect_success 'traverse unexpected non-tag tag (blob seen to blob)' '
	test_must_fail git rev-list --objects $blob $commit_tag_blob 2>err &&
	cat >expected <<-EOF &&
	error: object $blob is a blob, not a commit
	error: bad tag pointer to $blob in $commit_tag_blob
	fatal: bad object $commit_tag_blob
	EOF
	test_cmp expected err &&

	test_must_fail git rev-list --objects $blob $tag_tag_blob 2>err &&
	cat >expected <<-EOF &&
	error: object $blob is a blob, not a tag
	error: bad tag pointer to $blob in $tag_tag_blob
	fatal: bad object $tag_tag_blob
	EOF
	test_cmp expected err
'

test_done
