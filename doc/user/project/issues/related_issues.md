# Related issues

> [Introduced][ee-1797] in [GitLab Enterprise Edition Starter][ee] 9.4.

Related issues are a bi-directional relationship between any two issues
and appear in a block below the issue description. Issues can be across groups
and projects.

The relationship only shows up in the UI if the user has write [permissions]
to see both issues (`> Guest`).

## Adding a related issue

You can relate one issue to the other by clicking the issue count badge "+" button
in the header of the related issue block. Then use the input that will appear
where you can type in the issue reference or paste in a link to an issue.

Valid references will be added to a temporary list that you can review.
When ready, click the green "Add related issues" button to submit.

![Adding a related issue](img/related_issues_add.png)

## Removing a related issue

In the related issues block, click the "x" icon on the right-side of every issue
token. Because of the bi-directional relationship, it will no longer appear in
either issue.

![Removing a related issue](img/related_issues_remove.png)

[ee]: https://about.gitlab.com/gitlab-ee/
[ee-1797]: https://gitlab.com/gitlab-org/gitlab-ee/merge_requests/1797
[permissions]: ../../permissions.md
