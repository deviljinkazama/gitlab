# Milestones

Milestones allow you to organize issues and merge requests into a cohesive group,
optionally setting a due date. A common use is keeping track of an upcoming
software version. Milestones can be created per-project or per-group.

## Creating a project milestone

>**Note:**
You need [Master permissions](../../permissions.md) in order to create a milestone.

You can find the milestones page under your project's **Issues ➔ Milestones**.
To create a new milestone, simply click the **New milestone** button when in the
milestones page. A milestone can have a title, a description and start/due dates.
Once you fill in all the details, hit the **Create milestone** button.

>**Note:**
The start/due dates are required if you intend to use [Burndown charts](#burndown-charts).

![Creating a milestone](img/milestone_create.png)

## Creating a group milestone

>**Note:**
You need [Master permissions](../../permissions.md) in order to create a milestone.

You can create a milestone for several projects in the same group simultaneously.
On the group's **Issues ➔ Milestones** page, you will be able to see the status
of that milestone across all of the selected projects. To create a new milestone
for selected projects in the group, click the **New milestone** button. The
form is the same as when creating a milestone for a specific project with the
addition of the selection of the projects you want to inherit this milestone.

![Creating a group milestone](img/milestone_group_create.png)

## Special milestone filters

In addition to the milestones that exist in the project or group, there are some
special options available when filtering by milestone:

* **No Milestone** - only show issues or merge requests without a milestone.
* **Upcoming** - show issues or merge request that belong to the next open
  milestone with a due date, by project. (For example: if project A has
  milestone v1 due in three days, and project B has milestone v2 due in a week,
  then this will show issues or merge requests from milestone v1 in project A
  and milestone v2 in project B.)
* **Started** - show issues or merge requests from any milestone with a start
  date less than today. Note that this can return results from several
  milestones in the same project.

## Milestone progress statistics

Milestone statistics can be viewed in the milestone sidebar. The milestone percentage statistic
is calculated as; closed and merged merge requests plus all closed issues divided by
total merge requests and issues.

![Milestone statistics](img/progress.png)
<<<<<<< HEAD

## Burndown charts

>**Notes:**
- [Introduced][ee-1540] in GitLab Enterprise Edition 9.1 and is available for
  [Enterprise Edition Starter][ee] users.
- Closed or reopened issues prior to GitLab 9.1 won't have a `closed_at`
  value, so the burndown chart considers them as closed on the milestone
  `start_date`. In that case, a warning will be displayed.

A burndown chart is available for every project milestone that has a set start
date and a set due date and is located on the project's milestone page.

It indicates the project's progress throughout that milestone (for issues that
have that milestone assigned to it). In particular, it shows how many issues
were or are still open for a given day in the milestone period. Since GitLab
only tracks when an issue was last closed (and not its full history), the chart
assumes that issue was open on days prior to that date. Reopened issues are
considered as open on one day after they were closed.

Note that with this design, if you create a new issue in the middle of the milestone period 
(and assign the milestone to the issue), the burndown chart will appear as if the 
issue was already open at the beginning of the milestone. A workaround is to simply 
close the issue (so that a closed timestamp is stored in the system), and reopen 
it to ge the desired effect, with a rise in the chart appearing on the day after.
This is what appears in the example below.

The burndown chart can also be toggled to display the cumulative open issue
weight for a given day. When using this feature, make sure your weights have
been properly assigned, since an open issue with no weight adds zero to the
cumulative value.

![burndown chart](img/burndown_chart.png)

[ee-1540]: https://gitlab.com/gitlab-org/gitlab-ee/merge_requests/1540
[ee]: https://about.gitlab.com/gitlab-ee

=======
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
