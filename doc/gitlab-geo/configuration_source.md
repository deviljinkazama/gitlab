# GitLab Geo configuration

>**Note:**
This is the documentation for installations from source. For installations
using the Omnibus GitLab packages, follow the
[**Omnibus GitLab Geo nodes configuration**](configuration.md) guide.

1. [Install GitLab Enterprise Edition][install-ee-source] on the server that
   will serve as the secondary Geo node. Do not login or set up anything else
   in the secondary node for the moment.
1. [Setup the database replication](database_source.md)  (`primary (read-write) <-> secondary (read-only)` topology).
1. **Configure GitLab to set the primary and secondary nodes.**
1. [Follow the after setup steps](after_setup.md).

[install-ee-source]: https://docs.gitlab.com/ee/install/installation.html "GitLab Enterprise Edition installation from source"

This is the final step you need to follow in order to setup a Geo node.

You are encouraged to first read through all the steps before executing them
in your testing/production environment.

## Setting up GitLab

>**Notes:**
- Don't setup any custom authentication in the secondary nodes, this will be
  handled by the primary node.
- Do not add anything in the secondaries Geo nodes admin area
  (**Admin Area ➔ Geo Nodes**). This is handled solely by the primary node.

After having installed GitLab Enterprise Edition in the instance that will serve
as a Geo node and set up the [database replication](database_source.md), the
next steps can be summed up to:

1. Configure the primary node
1. Replicate some required configurations between the primary and the secondaries
1. Configure a second, tracking database for each secondary
1. Start GitLab in the secondary node's machine
1. Configure every secondary node in the primary's Admin screen

### Prerequisites

This is the last step of configuring a Geo node. Make sure you have followed the
first two steps of the [Setup instructions](README.md#setup-instructions):

1. You have already installed on the secondary server the same version of
   GitLab Enterprise Edition that is present on the primary server.
1. You have set up the database replication.
1. Your secondary node is allowed to communicate via HTTP/HTTPS and SSH with
   your primary node (make sure your firewall is not blocking that).
1. You have set up another PostgreSQL database that can store writes for the secondary.
   Note that this MUST be on another instance, since the primary replicated database
   is read-only.

Some of the following steps require to configure the primary and secondary
nodes almost at the same time. For your convenience make sure you have SSH
logins opened on all nodes as we will be moving back and forth.

### Step 1. Adding the primary GitLab node

1. SSH into the **primary** node and login as root:

    ```
    sudo -i
    ```

1. (Source install only): Create a new SSH key pair for the primary node. Choose the default location
   and leave the password blank by hitting 'Enter' three times:

    ```bash
    sudo -u git -H ssh-keygen -b 4096 -C 'Primary GitLab Geo node'
    ```

    Read more in [additional info for SSH key pairs](#additional-information-for-the-ssh-key-pairs).

1. Get the contents of `id_rsa.pub` for the git user:

    ```
    sudo -u git cat /home/git/.ssh/id_rsa.pub
    ```

1. Visit the primary node's **Admin Area ➔ Geo Nodes** (`/admin/geo_nodes`) in
   your browser.

1. Add the primary node by providing its full URL and the public SSH key
   you created previously. Make sure to check the box 'This is a primary node'
   when adding it.

    ![Add new primary Geo node](img/geo_nodes_add_new.png)

1. Click the **Add node** button.

### Step 2. Updating the `known_hosts` file of the secondary nodes

1. SSH into the **secondary** node and login as root:

    ```
    sudo -i
    ```

1. The secondary nodes need to know the SSH fingerprint of the primary node that
   will be used for the Git clone/fetch operations. In order to add it to the
   `known_hosts` file, run the following command and type `yes` when asked:

    ```
    sudo -u git -H ssh git@<primary-node-url>
    ```

    Replace `<primary-node-url>` with the FQDN of the primary node.

1. Verify that the fingerprint was added by checking `known_hosts`:

    ```
    cat /home/git/.ssh/known_hosts
    ```

### Step 3. Copying the database encryption key

GitLab stores a unique encryption key in disk that we use to safely store
sensitive data in the database. Any secondary node must have the
**exact same value** for `db_key_base` as defined in the primary one.

1. SSH into the **primary** node and login as root:

    ```
    sudo -i
    ```

1. Execute the command below to display the current encryption key and copy it:

     ```
     bundle exec rake geo:db:show_encryption_key
     ```

1. SSH into the **secondary** node and login as root:

    ```
    sudo -i
    ```

1. (This step is required only if you want to enable the new Disaster Recovery
   feature in Alpha shipped in GitLab 9.0) Create `database_geo.yml` with the
   information of your secondary PostgreSQL database.
   Note that this must be a totally different instance from the primary, since this
   is where the secondary will track its internal state:

    ```
    sudo cp /home/git/gitlab/config/database_geo.yml.postgresql /home/git/gitlab/config/database_geo.yml
    ```

1. (This step is required only if you want to enable the new Disaster Recovery
   feature in Alpha shipped in GitLab 9.0) Edit the content of `database_geo.yml`
   in `production:` to be like the following:

     ```yaml
     #
     # PRODUCTION
     #
     production:
       adapter: postgresql
       encoding: unicode
       database: gitlabhq_geo_production
       pool: 10
       username: gitlab_geo
       # password:
       host: /var/opt/gitlab/geo-postgresql
       port: 5431
     ```

1. (This step is required only if you want to enable the new Disaster Recovery
   feature in Alpha shipped in GitLab 9.0) Create the database
   `gitlabhq_geo_production` in that PostgreSQL instance.

1. (This step is required only if you want to enable the new Disaster Recovery
   feature in Alpha shipped in GitLab 9.0) Set up the Geo tracking database:

    ```
    bundle exec rake geo:db:migrate
    ```

1. Open the secrets file and paste the value of `db_key_base` you copied in the
   previous step:

     ```
     editor /home/git/gitlab/config/secrets.yml
     ```

1. Save and close the file.

### Step 4. Enabling the secondary GitLab node

1. SSH into the **secondary** node and login as root:

    ```
    sudo -i
    ```

1. Create a new SSH key pair for the secondary node. Choose the default location
   and leave the password blank by hitting 'Enter' three times:

    ```bash
    sudo -u git -H ssh-keygen -b 4096 -C 'Secondary GitLab Geo node'
    ```

    Read more in [additional info for SSH key pairs](#additional-information-for-the-ssh-key-pairs).

1. Get the contents of `id_rsa.pub` the was just created:

    ```
    sudo -u git cat /home/git/.ssh/id_rsa.pub
    ```

1. Visit the **primary** node's **Admin Area ➔ Geo Nodes** (`/admin/geo_nodes`)
   in your browser.
1. Add the secondary node by providing its full URL and the public SSH key
   you created previously. **Do NOT** check the box 'This is a primary node'.
1. Click the **Add node** button.

---

After the **Add Node** button is pressed, the primary node will start to notify
changes to the secondary. Make sure the secondary instance is running and
accessible.

The two most obvious issues that replication can have here are:

1. Database replication not working well
1. Instance to instance notification not working. In that case, it can be
   something of the following:
     - You are using a custom certificate or custom CA (see the
       [Troubleshooting](configuration.md#troubleshooting) section)
     - Instance is firewalled (check your firewall rules)

### Step 5. Replicating the repositories data

Getting a new secondary Geo node up and running, will also require the
repositories data to be synced.

With GitLab **9.0** the syncing process starts automatically from the
secondary node after the **Add Node** button is pressed.

Currently, this is what is synced:

* Git repositories
* Wikis
* LFS objects
* Issue, merge request, and comment attachments
* User, group, and project avatars

You can monitor the status of the syncing process on a secondary node
by visiting the primary node's **Admin Area ➔ Geo Nodes** (`/admin/geo_nodes`)
in your browser.

![GitLab Geo dashboard](img/geo-node-dashboard.png)

Disabling a secondary node stops the syncing process.

With GitLab **8.14** this process is started manually from the primary node.
You can start the syncing process by clicking the "Backfill all repositories"
button on `Admin > Geo Nodes` screen.

On previous versions, you can use `rsync` for that:

Make sure `rsync` is installed in both primary and secondary servers and root
SSH access with a password is enabled. Otherwise, you can set up an SSH key-based
connection between the servers.

1. SSH into the **secondary** node and login as root:

    ```
    sudo -i
    ```

1. Assuming `1.2.3.4` is the IP of the primary node, run the following command
   to start the sync:

    ```bash
    # Installations from source
    rsync -guavrP root@1.2.3.4:/home/git/repositories/ /home/git/repositories/
    chmod ug+rwX,o-rwx /home/git/repositories
    ```

If this step is not followed, the secondary node will eventually clone and
fetch every missing repository as they are updated with new commits on the
primary node, so syncing the repositories beforehand will buy you some time.

While active repositories will be eventually replicated, if you don't rsync,
the files, any archived/inactive repositories will not get in the secondary node
as Geo doesn't run any routine task to look for missing repositories.

### Step 6. Regenerating the authorized keys in the secondary node

The final step is to regenerate the keys for `~/.ssh/authorized_keys`
(HTTPS clone will still work without this extra step).

On the **secondary** node where the database is [already replicated](./database.md),
run:

```
# Installations from source
sudo -u git -H bundle exec rake gitlab:shell:setup RAILS_ENV=production
```

This will enable `git` operations to authorize against your existing users.
New users and SSH keys updated after this step, will be replicated automatically.

## Next steps

Your nodes should now be ready to use. You can login to the secondary node
with the same credentials as used in the primary. Visit the secondary node's
**Admin Area ➔ Geo Nodes** (`/admin/geo_nodes`) in your browser to check if it's
correctly identified as a secondary Geo node and if Geo is enabled.

If your installation isn't working properly, check the
[troubleshooting](configuration.md#troubleshooting) section.

Point your users to the [after setup steps](after_setup.md).

## Adding another secondary Geo node

To add another Geo node in an already Geo configured infrastructure, just follow
[the steps starting form step 2](#step-2-updating-the-known_hosts-file-of-the-secondary-nodes).
Just omit the first step that sets up the primary node.

## Additional information for the SSH key pairs

Read [Additional information for the SSH key pairs](configuration.md#additional-information-for-the-ssh-key-pairs).

## Troubleshooting

Read the [troubleshooting document](troubleshooting.md).
