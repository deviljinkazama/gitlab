# Configuring GitLab for HA

Assuming you have already configured a database, Redis, and NFS, you can
configure the GitLab application server(s) now. Complete the steps below
for each GitLab application server in your environment.

> **Note:** There is some additional configuration near the bottom for
  secondary GitLab application servers. It's important to read and understand
  these additional steps before proceeding with GitLab installation.

1. If necessary, install the NFS client utility packages using the following
   commands:

    ```
    # Ubuntu/Debian
    apt-get install nfs-common

    # CentOS/Red Hat
    yum install nfs-utils nfs-utils-lib
    ```

1. Specify the necessary NFS shares. Mounts are specified in
   `/etc/fstab`. The exact contents of `/etc/fstab` will depend on how you chose
   to configure your NFS server. See [NFS documentation](nfs.md) for the various
   options. Here is an example snippet to add to `/etc/fstab`:

    ```
    10.1.0.1:/var/opt/gitlab/.ssh /var/opt/gitlab/.ssh nfs defaults,soft,rsize=1048576,wsize=1048576,noatime,nobootwait,lookupcache=positive 0 2
    10.1.0.1:/var/opt/gitlab/gitlab-rails/uploads /var/opt/gitlab/gitlab-rails/uploads nfs defaults,soft,rsize=1048576,wsize=1048576,noatime,nobootwait,lookupcache=positive 0 2
    10.1.0.1:/var/opt/gitlab/gitlab-rails/shared /var/opt/gitlab/gitlab-rails/shared nfs defaults,soft,rsize=1048576,wsize=1048576,noatime,nobootwait,lookupcache=positive 0 2
    10.1.0.1:/var/opt/gitlab/gitlab-ci/builds /var/opt/gitlab/gitlab-ci/builds nfs defaults,soft,rsize=1048576,wsize=1048576,noatime,nobootwait,lookupcache=positive 0 2
    10.1.1.1:/var/opt/gitlab/git-data /var/opt/gitlab/git-data nfs defaults,soft,rsize=1048576,wsize=1048576,noatime,nobootwait,lookupcache=positive 0 2
    ```

1. Create the shared directories. These may be different depending on your NFS
   mount locations.

    ```
    mkdir -p /var/opt/gitlab/.ssh /var/opt/gitlab/gitlab-rails/uploads /var/opt/gitlab/gitlab-rails/shared /var/opt/gitlab/gitlab-ci/builds /var/opt/gitlab/git-data
    ```

1. Download/install GitLab Omnibus using **steps 1 and 2** from
   [GitLab downloads](https://about.gitlab.com/downloads). Do not complete other
   steps on the download page.
1. Create/edit `/etc/gitlab/gitlab.rb` and use the following configuration.
   Be sure to change the `external_url` to match your eventual GitLab front-end
   URL. Depending your the NFS configuration, you may need to change some GitLab
   data locations. See [NFS documentation](nfs.md) for `/etc/gitlab/gitlab.rb`
   configuration values for various scenarios. The example below assumes you've
   added NFS mounts in the default data locations.
    
    ```ruby
    external_url 'https://gitlab.example.com'

    # Prevent GitLab from starting if NFS data mounts are not available
    high_availability['mountpoint'] = '/var/opt/gitlab/git-data'
    
    # Disable components that will not be on the GitLab application server
    postgresql['enable'] = false
    redis['enable'] = false
    
    # PostgreSQL connection details
    gitlab_rails['db_adapter'] = 'postgresql'
    gitlab_rails['db_encoding'] = 'unicode'
    gitlab_rails['db_host'] = '10.1.0.5' # IP/hostname of database server
    gitlab_rails['db_password'] = 'DB password'
    
    # Redis connection details
    gitlab_rails['redis_port'] = '6379'
    gitlab_rails['redis_host'] = '10.1.0.6' # IP/hostname of Redis server
    gitlab_rails['redis_password'] = 'Redis Password'
    ```

1. Run `sudo gitlab-ctl reconfigure` to compile the configuration.

## Primary GitLab application server

As a final step, run the setup rake task on the first GitLab application server.
It is not necessary to run this on additional application servers.

1. Initialize the database by running `sudo gitlab-rake gitlab:setup`.

> **WARNING:** Only run this setup task on **NEW** GitLab instances because it
  will wipe any existing data.

> **Note:** When you specify `https` in the `external_url`, as in the example
  above, GitLab assumes you have SSL certificates in `/etc/gitlab/ssl/`. If
  certificates are not present, Nginx will fail to start. See
  [Nginx documentation](http://docs.gitlab.com/omnibus/settings/nginx.html#enable-https)
  for more information.

## Additional configuration for secondary GitLab application servers

Secondary GitLab servers (servers configured **after** the first GitLab server)
need some additional configuration.

1. Configure shared secrets. These values can be obtained from the primary
   GitLab server in `/etc/gitlab/gitlab-secrets.json`. Copy this file to the
   secondary servers **prior to** running the first `reconfigure` in the steps
   above.

1. Run `touch /etc/gitlab/skip-auto-migrations` to prevent database migrations
   from running on upgrade. Only the primary GitLab application server should
   handle migrations.

## Troubleshooting

- `mount: wrong fs type, bad option, bad superblock on`

You have not installed the necessary NFS client utilities. See step 1 above.

- `mount: mount point /var/opt/gitlab/... does not exist`

This particular directory does not exist on the NFS server. Ensure
the share is exported and exists on the NFS server and try to remount.

---

Read more on high-availability configuration:

1. [Configure the database](database.md)
1. [Configure Redis](redis.md)
1. [Configure NFS](nfs.md)
1. [Configure the load balancers](load_balancer.md)
